/*
 * Garbage Collection common functions for scavenging, moving and sizing
 * objects.  These are for use with both GC (stop & copy GC) and GENCGC
 */

/*
 * This software is part of the SBCL system. See the README file for
 * more information.
 *
 * This software is derived from the CMU CL system, which was
 * written at Carnegie Mellon University and released into the
 * public domain. The software is in the public domain and is
 * provided with absolutely no warranty. See the COPYING and CREDITS
 * files for more information.
 */

/*
 * For a review of garbage collection techniques (e.g. generational
 * GC) and terminology (e.g. "scavenging") see Paul R. Wilson,
 * "Uniprocessor Garbage Collection Techniques". As of 20000618, this
 * had been accepted for _ACM Computing Surveys_ and was available
 * as a PostScript preprint through
 *   <http://www.cs.utexas.edu/users/oops/papers.html>
 * as
 *   <ftp://ftp.cs.utexas.edu/pub/garbage/bigsurv.ps>.
 */

#include <stdio.h>
#include <signal.h>
#include <string.h>
#include "sbcl.h"
#include "runtime.h"
#include "os.h"
#include "interr.h"
#include "globals.h"
#include "interrupt.h"
#include "validate.h"
#include "lispregs.h"
#include "arch.h"
#include "gc.h"
#include "genesis/primitive-objects.h"
#include "genesis/static-symbols.h"
#include "genesis/layout.h"
#include "genesis/hash-table.h"
#include "gc-internal.h"

#ifdef LISP_FEATURE_SPARC
#define LONG_FLOAT_SIZE 4
#else
#ifdef LISP_FEATURE_X86
#define LONG_FLOAT_SIZE 3
#endif
#endif

size_t dynamic_space_size = DEFAULT_DYNAMIC_SPACE_SIZE;
size_t thread_control_stack_size = DEFAULT_CONTROL_STACK_SIZE;

inline static boolean
forwarding_pointer_p(lispobj *pointer) {
    lispobj first_word=*pointer;
#ifdef LISP_FEATURE_GENCGC
    return (first_word == 0x01);
#else
    return (is_lisp_pointer(first_word)
            && new_space_p(first_word));
#endif
}

static inline lispobj *
forwarding_pointer_value(lispobj *pointer) {
#ifdef LISP_FEATURE_GENCGC
    return (lispobj *) ((pointer_sized_uint_t) pointer[1]);
#else
    return (lispobj *) ((pointer_sized_uint_t) pointer[0]);
#endif
}
static inline lispobj
set_forwarding_pointer(lispobj * pointer, lispobj newspace_copy) {
#ifdef LISP_FEATURE_GENCGC
    pointer[0]=0x01;
    pointer[1]=newspace_copy;
#else
    pointer[0]=newspace_copy;
#endif
    return newspace_copy;
}

long (*scavtab[256])(lispobj *where, lispobj object);
lispobj (*transother[256])(lispobj object);
long (*sizetab[256])(lispobj *where);
struct weak_pointer *weak_pointers;

unsigned long bytes_consed_between_gcs = 12*1024*1024;


/*
 * copying objects
 */
static
lispobj
gc_general_copy_object(lispobj object, long nwords, int page_type_flag)
{
    int tag;
    lispobj *new;

    gc_assert(is_lisp_pointer(object));
    gc_assert(from_space_p(object));
    gc_assert((nwords & 0x01) == 0);

    /* Get tag of object. */
    tag = lowtag_of(object);

    /* Allocate space. */
    new = gc_general_alloc(nwords*N_WORD_BYTES, page_type_flag, ALLOC_QUICK);

    /* Copy the object. */
    memcpy(new,native_pointer(object),nwords*N_WORD_BYTES);
    return make_lispobj(new,tag);
}

/* to copy a boxed object */
lispobj
copy_object(lispobj object, long nwords)
{
    return gc_general_copy_object(object, nwords, BOXED_PAGE_FLAG);
}

lispobj
copy_code_object(lispobj object, long nwords)
{
    return gc_general_copy_object(object, nwords, CODE_PAGE_FLAG);
}

static long scav_lose(lispobj *where, lispobj object); /* forward decl */

/* FIXME: Most calls end up going to some trouble to compute an
 * 'n_words' value for this function. The system might be a little
 * simpler if this function used an 'end' parameter instead. */
void
scavenge(lispobj *start, long n_words)
{
    lispobj *end = start + n_words;
    lispobj *object_ptr;
    long n_words_scavenged;

    for (object_ptr = start;
         object_ptr < end;
         object_ptr += n_words_scavenged) {

        lispobj object = *object_ptr;
#ifdef LISP_FEATURE_GENCGC
        if (forwarding_pointer_p(object_ptr))
            lose("unexpect forwarding pointer in scavenge: %p, start=%p, n=%l\n",
                 object_ptr, start, n_words);
#endif
        if (is_lisp_pointer(object)) {
            if (from_space_p(object)) {
                /* It currently points to old space. Check for a
                 * forwarding pointer. */
                lispobj *ptr = native_pointer(object);
                if (forwarding_pointer_p(ptr)) {
                    /* Yes, there's a forwarding pointer. */
                    *object_ptr = LOW_WORD(forwarding_pointer_value(ptr));
                    n_words_scavenged = 1;
                } else {
                    /* Scavenge that pointer. */
                    n_words_scavenged =
                        (scavtab[widetag_of(object)])(object_ptr, object);
                }
            } else {
                /* It points somewhere other than oldspace. Leave it
                 * alone. */
                n_words_scavenged = 1;
            }
        }
#if !defined(LISP_FEATURE_X86) && !defined(LISP_FEATURE_X86_64)
        /* This workaround is probably not needed for those ports
           which don't have a partitioned register set (and therefore
           scan the stack conservatively for roots). */
        else if (n_words == 1) {
            /* there are some situations where an other-immediate may
               end up in a descriptor register.  I'm not sure whether
               this is supposed to happen, but if it does then we
               don't want to (a) barf or (b) scavenge over the
               data-block, because there isn't one.  So, if we're
               checking a single word and it's anything other than a
               pointer, just hush it up */
            int widetag = widetag_of(object);
            n_words_scavenged = 1;

            if ((scavtab[widetag] == scav_lose) ||
                (((sizetab[widetag])(object_ptr)) > 1)) {
                fprintf(stderr,"warning: \
attempted to scavenge non-descriptor value %x at %p.\n\n\
If you can reproduce this warning, please send a bug report\n\
(see manual page for details).\n",
                        object, object_ptr);
            }
        }
#endif
        else if (fixnump(object)) {
            /* It's a fixnum: really easy.. */
            n_words_scavenged = 1;
        } else {
            /* It's some sort of header object or another. */
            n_words_scavenged =
                (scavtab[widetag_of(object)])(object_ptr, object);
        }
    }
    gc_assert_verbose(object_ptr == end, "Final object pointer %p, start %p, end %p\n",
                      object_ptr, start, end);
}

static lispobj trans_fun_header(lispobj object); /* forward decls */
static lispobj trans_boxed(lispobj object);

static long
scav_fun_pointer(lispobj *where, lispobj object)
{
    lispobj *first_pointer;
    lispobj copy;

    gc_assert(is_lisp_pointer(object));

    /* Object is a pointer into from_space - not a FP. */
    first_pointer = (lispobj *) native_pointer(object);

    /* must transport object -- object may point to either a function
     * header, a closure function header, or to a closure header. */

    switch (widetag_of(*first_pointer)) {
    case SIMPLE_FUN_HEADER_WIDETAG:
        copy = trans_fun_header(object);
        break;
    default:
        copy = trans_boxed(object);
        break;
    }

    if (copy != object) {
        /* Set forwarding pointer */
        set_forwarding_pointer(first_pointer,copy);
    }

    gc_assert(is_lisp_pointer(copy));
    gc_assert(!from_space_p(copy));

    *where = copy;

    return 1;
}


static struct code *
trans_code(struct code *code)
{
    struct code *new_code;
    lispobj first, l_code, l_new_code;
    long nheader_words, ncode_words, nwords;
    unsigned long displacement;
    lispobj fheaderl, *prev_pointer;

    /* if object has already been transported, just return pointer */
    first = code->header;
    if (forwarding_pointer_p((lispobj *)code)) {
#ifdef DEBUG_CODE_GC
        printf("Was already transported\n");
#endif
        return (struct code *) forwarding_pointer_value
            ((lispobj *)((pointer_sized_uint_t) code));
    }

    gc_assert(widetag_of(first) == CODE_HEADER_WIDETAG);

    /* prepare to transport the code vector */
    l_code = (lispobj) LOW_WORD(code) | OTHER_POINTER_LOWTAG;

    ncode_words = fixnum_value(code->code_size);
    nheader_words = HeaderValue(code->header);
    nwords = ncode_words + nheader_words;
    nwords = CEILING(nwords, 2);

    l_new_code = copy_code_object(l_code, nwords);
    new_code = (struct code *) native_pointer(l_new_code);

#if defined(DEBUG_CODE_GC)
    printf("Old code object at 0x%08x, new code object at 0x%08x.\n",
           (unsigned long) code, (unsigned long) new_code);
    printf("Code object is %d words long.\n", nwords);
#endif

#ifdef LISP_FEATURE_GENCGC
    if (new_code == code)
        return new_code;
#endif

    displacement = l_new_code - l_code;

    set_forwarding_pointer((lispobj *)code, l_new_code);

    /* set forwarding pointers for all the function headers in the */
    /* code object.  also fix all self pointers */

    fheaderl = code->entry_points;
    prev_pointer = &new_code->entry_points;

    while (fheaderl != NIL) {
        struct simple_fun *fheaderp, *nfheaderp;
        lispobj nfheaderl;

        fheaderp = (struct simple_fun *) native_pointer(fheaderl);
        gc_assert(widetag_of(fheaderp->header) == SIMPLE_FUN_HEADER_WIDETAG);

        /* Calculate the new function pointer and the new */
        /* function header. */
        nfheaderl = fheaderl + displacement;
        nfheaderp = (struct simple_fun *) native_pointer(nfheaderl);

#ifdef DEBUG_CODE_GC
        printf("fheaderp->header (at %x) <- %x\n",
               &(fheaderp->header) , nfheaderl);
#endif
        set_forwarding_pointer((lispobj *)fheaderp, nfheaderl);

        /* fix self pointer. */
        nfheaderp->self =
#if defined(LISP_FEATURE_X86) || defined(LISP_FEATURE_X86_64)
            FUN_RAW_ADDR_OFFSET +
#endif
            nfheaderl;

        *prev_pointer = nfheaderl;

        fheaderl = fheaderp->next;
        prev_pointer = &nfheaderp->next;
    }
#ifdef LISP_FEATURE_GENCGC
    /* Cheneygc doesn't need this os_flush_icache, it flushes the whole
       spaces once when all copying is done. */
    os_flush_icache((os_vm_address_t) (((long *)new_code) + nheader_words),
                    ncode_words * sizeof(long));

#endif

#if defined(LISP_FEATURE_X86) || defined(LISP_FEATURE_X86_64)
    gencgc_apply_code_fixups(code, new_code);
#endif

    return new_code;
}

static long
scav_code_header(lispobj *where, lispobj object)
{
    struct code *code;
    long n_header_words, n_code_words, n_words;
    lispobj entry_point;        /* tagged pointer to entry point */
    struct simple_fun *function_ptr; /* untagged pointer to entry point */

    code = (struct code *) where;
    n_code_words = fixnum_value(code->code_size);
    n_header_words = HeaderValue(object);
    n_words = n_code_words + n_header_words;
    n_words = CEILING(n_words, 2);

    /* Scavenge the boxed section of the code data block. */
    scavenge(where + 1, n_header_words - 1);

    /* Scavenge the boxed section of each function object in the
     * code data block. */
    for (entry_point = code->entry_points;
         entry_point != NIL;
         entry_point = function_ptr->next) {

        gc_assert_verbose(is_lisp_pointer(entry_point),
                          "Entry point %lx\n is not a lisp pointer.",
                          (long)entry_point);

        function_ptr = (struct simple_fun *) native_pointer(entry_point);
        gc_assert(widetag_of(function_ptr->header)==SIMPLE_FUN_HEADER_WIDETAG);

        scavenge(&function_ptr->name, 1);
        scavenge(&function_ptr->arglist, 1);
        scavenge(&function_ptr->type, 1);
        scavenge(&function_ptr->info, 1);
    }

    return n_words;
}

static lispobj
trans_code_header(lispobj object)
{
    struct code *ncode;

    ncode = trans_code((struct code *) native_pointer(object));
    return (lispobj) LOW_WORD(ncode) | OTHER_POINTER_LOWTAG;
}


static long
size_code_header(lispobj *where)
{
    struct code *code;
    long nheader_words, ncode_words, nwords;

    code = (struct code *) where;

    ncode_words = fixnum_value(code->code_size);
    nheader_words = HeaderValue(code->header);
    nwords = ncode_words + nheader_words;
    nwords = CEILING(nwords, 2);

    return nwords;
}

#if !defined(LISP_FEATURE_X86) && ! defined(LISP_FEATURE_X86_64)
static long
scav_return_pc_header(lispobj *where, lispobj object)
{
    lose("attempted to scavenge a return PC header where=0x%08x object=0x%08x\n",
         (unsigned long) where,
         (unsigned long) object);
    return 0; /* bogus return value to satisfy static type checking */
}
#endif /* LISP_FEATURE_X86 */

static lispobj
trans_return_pc_header(lispobj object)
{
    struct simple_fun *return_pc;
    unsigned long offset;
    struct code *code, *ncode;

    return_pc = (struct simple_fun *) native_pointer(object);
    /* FIXME: was times 4, should it really be N_WORD_BYTES? */
    offset = HeaderValue(return_pc->header) * N_WORD_BYTES;

    /* Transport the whole code object */
    code = (struct code *) ((unsigned long) return_pc - offset);
    ncode = trans_code(code);

    return ((lispobj) LOW_WORD(ncode) + offset) | OTHER_POINTER_LOWTAG;
}

/* On the 386, closures hold a pointer to the raw address instead of the
 * function object, so we can use CALL [$FDEFN+const] to invoke
 * the function without loading it into a register. Given that code
 * objects don't move, we don't need to update anything, but we do
 * have to figure out that the function is still live. */

#if defined(LISP_FEATURE_X86) || defined(LISP_FEATURE_X86_64)
static long
scav_closure_header(lispobj *where, lispobj object)
{
    struct closure *closure;
    lispobj fun;

    closure = (struct closure *)where;
    fun = closure->fun - FUN_RAW_ADDR_OFFSET;
    scavenge(&fun, 1);
#ifdef LISP_FEATURE_GENCGC
    /* The function may have moved so update the raw address. But
     * don't write unnecessarily. */
    if (closure->fun != fun + FUN_RAW_ADDR_OFFSET)
        closure->fun = fun + FUN_RAW_ADDR_OFFSET;
#endif
    return 2;
}
#endif

#if !(defined(LISP_FEATURE_X86) || defined(LISP_FEATURE_X86_64))
static long
scav_fun_header(lispobj *where, lispobj object)
{
    lose("attempted to scavenge a function header where=0x%08x object=0x%08x\n",
         (unsigned long) where,
         (unsigned long) object);
    return 0; /* bogus return value to satisfy static type checking */
}
#endif /* LISP_FEATURE_X86 */

static lispobj
trans_fun_header(lispobj object)
{
    struct simple_fun *fheader;
    unsigned long offset;
    struct code *code, *ncode;

    fheader = (struct simple_fun *) native_pointer(object);
    /* FIXME: was times 4, should it really be N_WORD_BYTES? */
    offset = HeaderValue(fheader->header) * N_WORD_BYTES;

    /* Transport the whole code object */
    code = (struct code *) ((unsigned long) fheader - offset);
    ncode = trans_code(code);

    return ((lispobj) LOW_WORD(ncode) + offset) | FUN_POINTER_LOWTAG;
}


/*
 * instances
 */

static long
scav_instance_pointer(lispobj *where, lispobj object)
{
    lispobj copy, *first_pointer;

    /* Object is a pointer into from space - not a FP. */
    copy = trans_boxed(object);

#ifdef LISP_FEATURE_GENCGC
    gc_assert(copy != object);
#endif

    first_pointer = (lispobj *) native_pointer(object);
    set_forwarding_pointer(first_pointer,copy);
    *where = copy;

    return 1;
}


/*
 * lists and conses
 */

static lispobj trans_list(lispobj object);

static long
scav_list_pointer(lispobj *where, lispobj object)
{
    lispobj first, *first_pointer;

    gc_assert(is_lisp_pointer(object));

    /* Object is a pointer into from space - not FP. */
    first_pointer = (lispobj *) native_pointer(object);

    first = trans_list(object);
    gc_assert(first != object);

    /* Set forwarding pointer */
    set_forwarding_pointer(first_pointer, first);

    gc_assert(is_lisp_pointer(first));
    gc_assert(!from_space_p(first));

    *where = first;
    return 1;
}


static lispobj
trans_list(lispobj object)
{
    lispobj new_list_pointer;
    struct cons *cons, *new_cons;
    lispobj cdr;

    cons = (struct cons *) native_pointer(object);

    /* Copy 'object'. */
    new_cons = (struct cons *)
        gc_general_alloc(sizeof(struct cons), BOXED_PAGE_FLAG, ALLOC_QUICK);
    new_cons->car = cons->car;
    new_cons->cdr = cons->cdr; /* updated later */
    new_list_pointer = make_lispobj(new_cons,lowtag_of(object));

    /* Grab the cdr: set_forwarding_pointer will clobber it in GENCGC  */
    cdr = cons->cdr;

    set_forwarding_pointer((lispobj *)cons, new_list_pointer);

    /* Try to linearize the list in the cdr direction to help reduce
     * paging. */
    while (1) {
        lispobj  new_cdr;
        struct cons *cdr_cons, *new_cdr_cons;

        if(lowtag_of(cdr) != LIST_POINTER_LOWTAG ||
           !from_space_p(cdr) ||
           forwarding_pointer_p((lispobj *)native_pointer(cdr)))
            break;

        cdr_cons = (struct cons *) native_pointer(cdr);

        /* Copy 'cdr'. */
        new_cdr_cons = (struct cons*)
            gc_general_alloc(sizeof(struct cons), BOXED_PAGE_FLAG, ALLOC_QUICK);
        new_cdr_cons->car = cdr_cons->car;
        new_cdr_cons->cdr = cdr_cons->cdr;
        new_cdr = make_lispobj(new_cdr_cons, lowtag_of(cdr));

        /* Grab the cdr before it is clobbered. */
        cdr = cdr_cons->cdr;
        set_forwarding_pointer((lispobj *)cdr_cons, new_cdr);

        /* Update the cdr of the last cons copied into new space to
         * keep the newspace scavenge from having to do it. */
        new_cons->cdr = new_cdr;

        new_cons = new_cdr_cons;
    }

    return new_list_pointer;
}


/*
 * scavenging and transporting other pointers
 */

static long
scav_other_pointer(lispobj *where, lispobj object)
{
    lispobj first, *first_pointer;

    gc_assert(is_lisp_pointer(object));

    /* Object is a pointer into from space - not FP. */
    first_pointer = (lispobj *) native_pointer(object);
    first = (transother[widetag_of(*first_pointer)])(object);

    if (first != object) {
        set_forwarding_pointer(first_pointer, first);
#ifdef LISP_FEATURE_GENCGC
        *where = first;
#endif
    }
#ifndef LISP_FEATURE_GENCGC
    *where = first;
#endif
    gc_assert(is_lisp_pointer(first));
    gc_assert(!from_space_p(first));

    return 1;
}

/*
 * immediate, boxed, and unboxed objects
 */

static long
size_pointer(lispobj *where)
{
    return 1;
}

static long
scav_immediate(lispobj *where, lispobj object)
{
    return 1;
}

static lispobj
trans_immediate(lispobj object)
{
    lose("trying to transport an immediate\n");
    return NIL; /* bogus return value to satisfy static type checking */
}

static long
size_immediate(lispobj *where)
{
    return 1;
}


static long
scav_boxed(lispobj *where, lispobj object)
{
    return 1;
}

static long
scav_instance(lispobj *where, lispobj object)
{
    lispobj nuntagged;
    long ntotal = HeaderValue(object);
    lispobj layout = ((struct instance *)where)->slots[0];

    if (!layout)
        return 1;
    if (forwarding_pointer_p(native_pointer(layout)))
        layout = (lispobj) forwarding_pointer_value(native_pointer(layout));

    nuntagged = ((struct layout *)native_pointer(layout))->n_untagged_slots;
    scavenge(where + 1, ntotal - fixnum_value(nuntagged));

    return ntotal + 1;
}

static lispobj
trans_boxed(lispobj object)
{
    lispobj header;
    unsigned long length;

    gc_assert(is_lisp_pointer(object));

    header = *((lispobj *) native_pointer(object));
    length = HeaderValue(header) + 1;
    length = CEILING(length, 2);

    return copy_object(object, length);
}


static long
size_boxed(lispobj *where)
{
    lispobj header;
    unsigned long length;

    header = *where;
    length = HeaderValue(header) + 1;
    length = CEILING(length, 2);

    return length;
}

/* Note: on the sparc we don't have to do anything special for fdefns, */
/* 'cause the raw-addr has a function lowtag. */
#if !defined(LISP_FEATURE_SPARC)
static long
scav_fdefn(lispobj *where, lispobj object)
{
    struct fdefn *fdefn;

    fdefn = (struct fdefn *)where;

    /* FSHOW((stderr, "scav_fdefn, function = %p, raw_addr = %p\n",
       fdefn->fun, fdefn->raw_addr)); */

    if ((char *)(fdefn->fun + FUN_RAW_ADDR_OFFSET) == fdefn->raw_addr) {
        scavenge(where + 1, sizeof(struct fdefn)/sizeof(lispobj) - 1);

        /* Don't write unnecessarily. */
        if (fdefn->raw_addr != (char *)(fdefn->fun + FUN_RAW_ADDR_OFFSET))
            fdefn->raw_addr = (char *)(fdefn->fun + FUN_RAW_ADDR_OFFSET);
        /* gc.c has more casts here, which may be relevant or alternatively
           may be compiler warning defeaters.  try
        fdefn->raw_addr = ((char *) LOW_WORD(fdefn->fun)) + FUN_RAW_ADDR_OFFSET;
        */
        return sizeof(struct fdefn) / sizeof(lispobj);
    } else {
        return 1;
    }
}
#endif

static long
scav_unboxed(lispobj *where, lispobj object)
{
    unsigned long length;

    length = HeaderValue(object) + 1;
    length = CEILING(length, 2);

    return length;
}

static lispobj
trans_unboxed(lispobj object)
{
    lispobj header;
    unsigned long length;


    gc_assert(is_lisp_pointer(object));

    header = *((lispobj *) native_pointer(object));
    length = HeaderValue(header) + 1;
    length = CEILING(length, 2);

    return copy_unboxed_object(object, length);
}

static long
size_unboxed(lispobj *where)
{
    lispobj header;
    unsigned long length;

    header = *where;
    length = HeaderValue(header) + 1;
    length = CEILING(length, 2);

    return length;
}


/* vector-like objects */
static long
scav_base_string(lispobj *where, lispobj object)
{
    struct vector *vector;
    long length, nwords;

    /* NOTE: Strings contain one more byte of data than the length */
    /* slot indicates. */

    vector = (struct vector *) where;
    length = fixnum_value(vector->length) + 1;
    nwords = CEILING(NWORDS(length, 8) + 2, 2);

    return nwords;
}
static lispobj
trans_base_string(lispobj object)
{
    struct vector *vector;
    long length, nwords;

    gc_assert(is_lisp_pointer(object));

    /* NOTE: A string contains one more byte of data (a terminating
     * '\0' to help when interfacing with C functions) than indicated
     * by the length slot. */

    vector = (struct vector *) native_pointer(object);
    length = fixnum_value(vector->length) + 1;
    nwords = CEILING(NWORDS(length, 8) + 2, 2);

    return copy_large_unboxed_object(object, nwords);
}

static long
size_base_string(lispobj *where)
{
    struct vector *vector;
    long length, nwords;

    /* NOTE: A string contains one more byte of data (a terminating
     * '\0' to help when interfacing with C functions) than indicated
     * by the length slot. */

    vector = (struct vector *) where;
    length = fixnum_value(vector->length) + 1;
    nwords = CEILING(NWORDS(length, 8) + 2, 2);

    return nwords;
}

static long
scav_character_string(lispobj *where, lispobj object)
{
    struct vector *vector;
    int length, nwords;

    /* NOTE: Strings contain one more byte of data than the length */
    /* slot indicates. */

    vector = (struct vector *) where;
    length = fixnum_value(vector->length) + 1;
    nwords = CEILING(NWORDS(length, 32) + 2, 2);

    return nwords;
}
static lispobj
trans_character_string(lispobj object)
{
    struct vector *vector;
    int length, nwords;

    gc_assert(is_lisp_pointer(object));

    /* NOTE: A string contains one more byte of data (a terminating
     * '\0' to help when interfacing with C functions) than indicated
     * by the length slot. */

    vector = (struct vector *) native_pointer(object);
    length = fixnum_value(vector->length) + 1;
    nwords = CEILING(NWORDS(length, 32) + 2, 2);

    return copy_large_unboxed_object(object, nwords);
}

static long
size_character_string(lispobj *where)
{
    struct vector *vector;
    int length, nwords;

    /* NOTE: A string contains one more byte of data (a terminating
     * '\0' to help when interfacing with C functions) than indicated
     * by the length slot. */

    vector = (struct vector *) where;
    length = fixnum_value(vector->length) + 1;
    nwords = CEILING(NWORDS(length, 32) + 2, 2);

    return nwords;
}

static lispobj
trans_vector(lispobj object)
{
    struct vector *vector;
    long length, nwords;

    gc_assert(is_lisp_pointer(object));

    vector = (struct vector *) native_pointer(object);

    length = fixnum_value(vector->length);
    nwords = CEILING(length + 2, 2);

    return copy_large_object(object, nwords);
}

static long
size_vector(lispobj *where)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(length + 2, 2);

    return nwords;
}

static long
scav_vector_nil(lispobj *where, lispobj object)
{
    return 2;
}

static lispobj
trans_vector_nil(lispobj object)
{
    gc_assert(is_lisp_pointer(object));
    return copy_unboxed_object(object, 2);
}

static long
size_vector_nil(lispobj *where)
{
    /* Just the header word and the length word */
    return 2;
}

static long
scav_vector_bit(lispobj *where, lispobj object)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 1) + 2, 2);

    return nwords;
}

static lispobj
trans_vector_bit(lispobj object)
{
    struct vector *vector;
    long length, nwords;

    gc_assert(is_lisp_pointer(object));

    vector = (struct vector *) native_pointer(object);
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 1) + 2, 2);

    return copy_large_unboxed_object(object, nwords);
}

static long
size_vector_bit(lispobj *where)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 1) + 2, 2);

    return nwords;
}

static long
scav_vector_unsigned_byte_2(lispobj *where, lispobj object)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 2) + 2, 2);

    return nwords;
}

static lispobj
trans_vector_unsigned_byte_2(lispobj object)
{
    struct vector *vector;
    long length, nwords;

    gc_assert(is_lisp_pointer(object));

    vector = (struct vector *) native_pointer(object);
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 2) + 2, 2);

    return copy_large_unboxed_object(object, nwords);
}

static long
size_vector_unsigned_byte_2(lispobj *where)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 2) + 2, 2);

    return nwords;
}

static long
scav_vector_unsigned_byte_4(lispobj *where, lispobj object)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 4) + 2, 2);

    return nwords;
}

static lispobj
trans_vector_unsigned_byte_4(lispobj object)
{
    struct vector *vector;
    long length, nwords;

    gc_assert(is_lisp_pointer(object));

    vector = (struct vector *) native_pointer(object);
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 4) + 2, 2);

    return copy_large_unboxed_object(object, nwords);
}
static long
size_vector_unsigned_byte_4(lispobj *where)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 4) + 2, 2);

    return nwords;
}


static long
scav_vector_unsigned_byte_8(lispobj *where, lispobj object)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 8) + 2, 2);

    return nwords;
}

/*********************/



static lispobj
trans_vector_unsigned_byte_8(lispobj object)
{
    struct vector *vector;
    long length, nwords;

    gc_assert(is_lisp_pointer(object));

    vector = (struct vector *) native_pointer(object);
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 8) + 2, 2);

    return copy_large_unboxed_object(object, nwords);
}

static long
size_vector_unsigned_byte_8(lispobj *where)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 8) + 2, 2);

    return nwords;
}


static long
scav_vector_unsigned_byte_16(lispobj *where, lispobj object)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 16) + 2, 2);

    return nwords;
}

static lispobj
trans_vector_unsigned_byte_16(lispobj object)
{
    struct vector *vector;
    long length, nwords;

    gc_assert(is_lisp_pointer(object));

    vector = (struct vector *) native_pointer(object);
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 16) + 2, 2);

    return copy_large_unboxed_object(object, nwords);
}

static long
size_vector_unsigned_byte_16(lispobj *where)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 16) + 2, 2);

    return nwords;
}

static long
scav_vector_unsigned_byte_32(lispobj *where, lispobj object)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 32) + 2, 2);

    return nwords;
}

static lispobj
trans_vector_unsigned_byte_32(lispobj object)
{
    struct vector *vector;
    long length, nwords;

    gc_assert(is_lisp_pointer(object));

    vector = (struct vector *) native_pointer(object);
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 32) + 2, 2);

    return copy_large_unboxed_object(object, nwords);
}

static long
size_vector_unsigned_byte_32(lispobj *where)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 32) + 2, 2);

    return nwords;
}

#if N_WORD_BITS == 64
static long
scav_vector_unsigned_byte_64(lispobj *where, lispobj object)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 64) + 2, 2);

    return nwords;
}

static lispobj
trans_vector_unsigned_byte_64(lispobj object)
{
    struct vector *vector;
    long length, nwords;

    gc_assert(is_lisp_pointer(object));

    vector = (struct vector *) native_pointer(object);
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 64) + 2, 2);

    return copy_large_unboxed_object(object, nwords);
}

static long
size_vector_unsigned_byte_64(lispobj *where)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 64) + 2, 2);

    return nwords;
}
#endif

static long
scav_vector_single_float(lispobj *where, lispobj object)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 32) + 2, 2);

    return nwords;
}

static lispobj
trans_vector_single_float(lispobj object)
{
    struct vector *vector;
    long length, nwords;

    gc_assert(is_lisp_pointer(object));

    vector = (struct vector *) native_pointer(object);
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 32) + 2, 2);

    return copy_large_unboxed_object(object, nwords);
}

static long
size_vector_single_float(lispobj *where)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 32) + 2, 2);

    return nwords;
}

static long
scav_vector_double_float(lispobj *where, lispobj object)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 64) + 2, 2);

    return nwords;
}

static lispobj
trans_vector_double_float(lispobj object)
{
    struct vector *vector;
    long length, nwords;

    gc_assert(is_lisp_pointer(object));

    vector = (struct vector *) native_pointer(object);
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 64) + 2, 2);

    return copy_large_unboxed_object(object, nwords);
}

static long
size_vector_double_float(lispobj *where)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 64) + 2, 2);

    return nwords;
}

#ifdef SIMPLE_ARRAY_LONG_FLOAT_WIDETAG
static long
scav_vector_long_float(lispobj *where, lispobj object)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(length *
                     LONG_FLOAT_SIZE
                     + 2, 2);
    return nwords;
}

static lispobj
trans_vector_long_float(lispobj object)
{
    struct vector *vector;
    long length, nwords;

    gc_assert(is_lisp_pointer(object));

    vector = (struct vector *) native_pointer(object);
    length = fixnum_value(vector->length);
    nwords = CEILING(length * LONG_FLOAT_SIZE + 2, 2);

    return copy_large_unboxed_object(object, nwords);
}

static long
size_vector_long_float(lispobj *where)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(length * LONG_FLOAT_SIZE + 2, 2);

    return nwords;
}
#endif


#ifdef SIMPLE_ARRAY_COMPLEX_SINGLE_FLOAT_WIDETAG
static long
scav_vector_complex_single_float(lispobj *where, lispobj object)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 64) + 2, 2);

    return nwords;
}

static lispobj
trans_vector_complex_single_float(lispobj object)
{
    struct vector *vector;
    long length, nwords;

    gc_assert(is_lisp_pointer(object));

    vector = (struct vector *) native_pointer(object);
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 64) + 2, 2);

    return copy_large_unboxed_object(object, nwords);
}

static long
size_vector_complex_single_float(lispobj *where)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 64) + 2, 2);

    return nwords;
}
#endif

#ifdef SIMPLE_ARRAY_COMPLEX_DOUBLE_FLOAT_WIDETAG
static long
scav_vector_complex_double_float(lispobj *where, lispobj object)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 128) + 2, 2);

    return nwords;
}

static lispobj
trans_vector_complex_double_float(lispobj object)
{
    struct vector *vector;
    long length, nwords;

    gc_assert(is_lisp_pointer(object));

    vector = (struct vector *) native_pointer(object);
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 128) + 2, 2);

    return copy_large_unboxed_object(object, nwords);
}

static long
size_vector_complex_double_float(lispobj *where)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(NWORDS(length, 128) + 2, 2);

    return nwords;
}
#endif


#ifdef SIMPLE_ARRAY_COMPLEX_LONG_FLOAT_WIDETAG
static long
scav_vector_complex_long_float(lispobj *where, lispobj object)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(length * (2* LONG_FLOAT_SIZE) + 2, 2);

    return nwords;
}

static lispobj
trans_vector_complex_long_float(lispobj object)
{
    struct vector *vector;
    long length, nwords;

    gc_assert(is_lisp_pointer(object));

    vector = (struct vector *) native_pointer(object);
    length = fixnum_value(vector->length);
    nwords = CEILING(length * (2*LONG_FLOAT_SIZE) + 2, 2);

    return copy_large_unboxed_object(object, nwords);
}

static long
size_vector_complex_long_float(lispobj *where)
{
    struct vector *vector;
    long length, nwords;

    vector = (struct vector *) where;
    length = fixnum_value(vector->length);
    nwords = CEILING(length * (2*LONG_FLOAT_SIZE) + 2, 2);

    return nwords;
}
#endif

#define WEAK_POINTER_NWORDS \
        CEILING((sizeof(struct weak_pointer) / sizeof(lispobj)), 2)

static lispobj
trans_weak_pointer(lispobj object)
{
    lispobj copy;
#ifndef LISP_FEATURE_GENCGC
    struct weak_pointer *wp;
#endif
    gc_assert(is_lisp_pointer(object));

#if defined(DEBUG_WEAK)
    printf("Transporting weak pointer from 0x%08x\n", object);
#endif

    /* Need to remember where all the weak pointers are that have */
    /* been transported so they can be fixed up in a post-GC pass. */

    copy = copy_object(object, WEAK_POINTER_NWORDS);
#ifndef LISP_FEATURE_GENCGC
    wp = (struct weak_pointer *) native_pointer(copy);

    gc_assert(widetag_of(wp->header)==WEAK_POINTER_WIDETAG);
    /* Push the weak pointer onto the list of weak pointers. */
    wp->next = (struct weak_pointer *)LOW_WORD(weak_pointers);
    weak_pointers = wp;
#endif
    return copy;
}

static long
size_weak_pointer(lispobj *where)
{
    return WEAK_POINTER_NWORDS;
}


void scan_weak_pointers(void)
{
    struct weak_pointer *wp, *next_wp;
    for (wp = weak_pointers, next_wp = NULL; wp != NULL; wp = next_wp) {
        lispobj value = wp->value;
        lispobj *first_pointer;
        gc_assert(widetag_of(wp->header)==WEAK_POINTER_WIDETAG);

        next_wp = wp->next;
        wp->next = NULL;
        if (next_wp == wp) /* gencgc uses a ref to self for end of list */
            next_wp = NULL;

        if (!(is_lisp_pointer(value) && from_space_p(value)))
            continue;

        /* Now, we need to check whether the object has been forwarded. If
         * it has been, the weak pointer is still good and needs to be
         * updated. Otherwise, the weak pointer needs to be nil'ed
         * out. */

        first_pointer = (lispobj *)native_pointer(value);

        if (forwarding_pointer_p(first_pointer)) {
            wp->value=
                (lispobj)LOW_WORD(forwarding_pointer_value(first_pointer));
        } else {
            /* Break it. */
            wp->value = NIL;
            wp->broken = T;
        }
    }
}


/* Hash tables */

#if N_WORD_BITS == 32
#define EQ_HASH_MASK 0x1fffffff
#elif N_WORD_BITS == 64
#define EQ_HASH_MASK 0x1fffffffffffffff
#endif

/* Compute the EQ-hash of KEY. This must match POINTER-HASH in
 * target-hash-table.lisp.  */
#define EQ_HASH(key) ((key) & EQ_HASH_MASK)

/* List of weak hash tables chained through their NEXT-WEAK-HASH-TABLE
 * slot. Set to NULL at the end of a collection.
 *
 * This is not optimal because, when a table is tenured, it won't be
 * processed automatically; only the yougest generation is GC'd by
 * default. On the other hand, all applications will need an
 * occasional full GC anyway, so it's not that bad either.  */
struct hash_table *weak_hash_tables = NULL;

/* Return true if OBJ has already survived the current GC. */
static inline int
survived_gc_yet (lispobj obj)
{
    return (!is_lisp_pointer(obj) || !from_space_p(obj) ||
            forwarding_pointer_p(native_pointer(obj)));
}

static inline int
weak_hash_entry_alivep (lispobj weakness, lispobj key, lispobj value)
{
    switch (weakness) {
    case KEY:
        return survived_gc_yet(key);
    case VALUE:
        return survived_gc_yet(value);
    case KEY_OR_VALUE:
        return (survived_gc_yet(key) || survived_gc_yet(value));
    case KEY_AND_VALUE:
        return (survived_gc_yet(key) && survived_gc_yet(value));
    default:
        gc_assert(0);
        /* Shut compiler up. */
        return 0;
    }
}

/* Return the beginning of data in ARRAY (skipping the header and the
 * length) or NULL if it isn't an array of the specified widetag after
 * all. */
static inline lispobj *
get_array_data (lispobj array, int widetag, unsigned long *length)
{
    if (is_lisp_pointer(array) &&
        (widetag_of(*(lispobj *)native_pointer(array)) == widetag)) {
        if (length != NULL)
            *length = fixnum_value(((lispobj *)native_pointer(array))[1]);
        return ((lispobj *)native_pointer(array)) + 2;
    } else {
        return NULL;
    }
}

/* Only need to worry about scavenging the _real_ entries in the
 * table. Phantom entries such as the hash table itself at index 0 and
 * the empty marker at index 1 were scavenged by scav_vector that
 * either called this function directly or arranged for it to be
 * called later by pushing the hash table onto weak_hash_tables. */
static void
scav_hash_table_entries (struct hash_table *hash_table)
{
    lispobj *kv_vector;
    unsigned long kv_length;
    lispobj *index_vector;
    unsigned long length;
    lispobj *next_vector;
    unsigned long next_vector_length;
    lispobj *hash_vector;
    unsigned long hash_vector_length;
    lispobj empty_symbol;
    lispobj weakness = hash_table->weakness;
    unsigned long i;

    kv_vector = get_array_data(hash_table->table,
                               SIMPLE_VECTOR_WIDETAG, &kv_length);
    if (kv_vector == NULL)
        lose("invalid kv_vector %x\n", hash_table->table);

    index_vector = get_array_data(hash_table->index_vector,
                                  SIMPLE_ARRAY_WORD_WIDETAG, &length);
    if (index_vector == NULL)
        lose("invalid index_vector %x\n", hash_table->index_vector);

    next_vector = get_array_data(hash_table->next_vector,
                                 SIMPLE_ARRAY_WORD_WIDETAG,
                                 &next_vector_length);
    if (next_vector == NULL)
        lose("invalid next_vector %x\n", hash_table->next_vector);

    hash_vector = get_array_data(hash_table->hash_vector,
                                 SIMPLE_ARRAY_WORD_WIDETAG,
                                 &hash_vector_length);
    if (hash_vector != NULL)
        gc_assert(hash_vector_length == next_vector_length);

     /* These lengths could be different as the index_vector can be a
      * different length from the others, a larger index_vector could
      * help reduce collisions. */
     gc_assert(next_vector_length*2 == kv_length);

    empty_symbol = kv_vector[1];
    /* fprintf(stderr,"* empty_symbol = %x\n", empty_symbol);*/
    if (widetag_of(*(lispobj *)native_pointer(empty_symbol)) !=
        SYMBOL_HEADER_WIDETAG) {
        lose("not a symbol where empty-hash-table-slot symbol expected: %x\n",
             *(lispobj *)native_pointer(empty_symbol));
    }

    /* Work through the KV vector. */
    for (i = 1; i < next_vector_length; i++) {
        lispobj old_key = kv_vector[2*i];
        lispobj value = kv_vector[2*i+1];
        if ((weakness == NIL) ||
            weak_hash_entry_alivep(weakness, old_key, value)) {

            /* Scavenge the key and value. */
            scavenge(&kv_vector[2*i],2);

            /* If an EQ-based key has moved, mark the hash-table for
             * rehashing. */
            if (!hash_vector || hash_vector[i] == MAGIC_HASH_VECTOR_VALUE) {
                lispobj new_key = kv_vector[2*i];

                if (old_key != new_key && new_key != empty_symbol) {
                    hash_table->needs_rehash_p = T;
                }
            }
        }
    }
}

long
scav_vector (lispobj *where, lispobj object)
{
    unsigned long kv_length;
    lispobj *kv_vector;
    struct hash_table *hash_table;

    /* SB-VM:VECTOR-VALID-HASHING-SUBTYPE is set for EQ-based and weak
     * hash tables in the Lisp HASH-TABLE code to indicate need for
     * special GC support. */
    if (HeaderValue(object) == subtype_VectorNormal)
        return 1;

    kv_length = fixnum_value(where[1]);
    kv_vector = where + 2;  /* Skip the header and length. */
    /*FSHOW((stderr,"/kv_length = %d\n", kv_length));*/

    /* Scavenge element 0, which may be a hash-table structure. */
    scavenge(where+2, 1);
    if (!is_lisp_pointer(where[2])) {
        /* This'll happen when REHASH clears the header of old-kv-vector
         * and fills it with zero, but some other thread simulatenously
         * sets the header in %%PUTHASH.
         */
        fprintf(stderr,
                "Warning: no pointer at %lx in hash table: this indicates "
                "non-fatal corruption caused by concurrent access to a "
                "hash-table from multiple threads. Any accesses to "
                "hash-tables shared between threads should be protected "
                "by locks.\n", (unsigned long)&where[2]);
        // We've scavenged three words.
        return 3;
    }
    hash_table = (struct hash_table *)native_pointer(where[2]);
    /*FSHOW((stderr,"/hash_table = %x\n", hash_table));*/
    if (widetag_of(hash_table->header) != INSTANCE_HEADER_WIDETAG) {
        lose("hash table not instance (%x at %x)\n",
             hash_table->header,
             hash_table);
    }

    /* Scavenge element 1, which should be some internal symbol that
     * the hash table code reserves for marking empty slots. */
    scavenge(where+3, 1);
    if (!is_lisp_pointer(where[3])) {
        lose("not empty-hash-table-slot symbol pointer: %x\n", where[3]);
    }

    /* Scavenge hash table, which will fix the positions of the other
     * needed objects. */
    scavenge((lispobj *)hash_table,
             sizeof(struct hash_table) / sizeof(lispobj));

    /* Cross-check the kv_vector. */
    if (where != (lispobj *)native_pointer(hash_table->table)) {
        lose("hash_table table!=this table %x\n", hash_table->table);
    }

    if (hash_table->weakness == NIL) {
        scav_hash_table_entries(hash_table);
    } else {
        /* Delay scavenging of this table by pushing it onto
         * weak_hash_tables (if it's not there already) for the weak
         * object phase. */
        if (hash_table->next_weak_hash_table == NIL) {
            hash_table->next_weak_hash_table = (lispobj)weak_hash_tables;
            weak_hash_tables = hash_table;
        }
    }

    return (CEILING(kv_length + 2, 2));
}

void
scav_weak_hash_tables (void)
{
    struct hash_table *table;

    /* Scavenge entries whose triggers are known to survive. */
    for (table = weak_hash_tables; table != NULL;
         table = (struct hash_table *)table->next_weak_hash_table) {
        scav_hash_table_entries(table);
    }
}

/* Walk through the chain whose first element is *FIRST and remove
 * dead weak entries. */
static inline void
scan_weak_hash_table_chain (struct hash_table *hash_table, lispobj *prev,
                            lispobj *kv_vector, lispobj *index_vector,
                            lispobj *next_vector, lispobj *hash_vector,
                            lispobj empty_symbol, lispobj weakness)
{
    unsigned index = *prev;
    while (index) {
        unsigned next = next_vector[index];
        lispobj key = kv_vector[2 * index];
        lispobj value = kv_vector[2 * index + 1];
        gc_assert(key != empty_symbol);
        gc_assert(value != empty_symbol);
        if (!weak_hash_entry_alivep(weakness, key, value)) {
            unsigned count = fixnum_value(hash_table->number_entries);
            gc_assert(count > 0);
            *prev = next;
            hash_table->number_entries = make_fixnum(count - 1);
            next_vector[index] = fixnum_value(hash_table->next_free_kv);
            hash_table->next_free_kv = make_fixnum(index);
            kv_vector[2 * index] = empty_symbol;
            kv_vector[2 * index + 1] = empty_symbol;
            if (hash_vector)
                hash_vector[index] = MAGIC_HASH_VECTOR_VALUE;
        } else {
            prev = &next_vector[index];
        }
        index = next;
    }
}

static void
scan_weak_hash_table (struct hash_table *hash_table)
{
    lispobj *kv_vector;
    lispobj *index_vector;
    unsigned long length = 0; /* prevent warning */
    lispobj *next_vector;
    unsigned long next_vector_length = 0; /* prevent warning */
    lispobj *hash_vector;
    lispobj empty_symbol;
    lispobj weakness = hash_table->weakness;
    unsigned long i;

    kv_vector = get_array_data(hash_table->table,
                               SIMPLE_VECTOR_WIDETAG, NULL);
    index_vector = get_array_data(hash_table->index_vector,
                                  SIMPLE_ARRAY_WORD_WIDETAG, &length);
    next_vector = get_array_data(hash_table->next_vector,
                                 SIMPLE_ARRAY_WORD_WIDETAG,
                                 &next_vector_length);
    hash_vector = get_array_data(hash_table->hash_vector,
                                 SIMPLE_ARRAY_WORD_WIDETAG, NULL);
    empty_symbol = kv_vector[1];

    for (i = 0; i < length; i++) {
        scan_weak_hash_table_chain(hash_table, &index_vector[i],
                                   kv_vector, index_vector, next_vector,
                                   hash_vector, empty_symbol, weakness);
    }
}

/* Remove dead entries from weak hash tables. */
void
scan_weak_hash_tables (void)
{
    struct hash_table *table, *next;

    for (table = weak_hash_tables; table != NULL; table = next) {
        next = (struct hash_table *)table->next_weak_hash_table;
        table->next_weak_hash_table = NIL;
        scan_weak_hash_table(table);
    }

    weak_hash_tables = NULL;
}


/*
 * initialization
 */

static long
scav_lose(lispobj *where, lispobj object)
{
    lose("no scavenge function for object 0x%08x (widetag 0x%x)\n",
         (unsigned long)object,
         widetag_of(object));

    return 0; /* bogus return value to satisfy static type checking */
}

static lispobj
trans_lose(lispobj object)
{
    lose("no transport function for object 0x%08x (widetag 0x%x)\n",
         (unsigned long)object,
         widetag_of(*(lispobj*)native_pointer(object)));
    return NIL; /* bogus return value to satisfy static type checking */
}

static long
size_lose(lispobj *where)
{
    lose("no size function for object at 0x%08x (widetag 0x%x)\n",
         (unsigned long)where,
         widetag_of(LOW_WORD(where)));
    return 1; /* bogus return value to satisfy static type checking */
}


/*
 * initialization
 */

void
gc_init_tables(void)
{
    unsigned long i;

    /* Set default value in all slots of scavenge table.  FIXME
     * replace this gnarly sizeof with something based on
     * N_WIDETAG_BITS */
    for (i = 0; i < ((sizeof scavtab)/(sizeof scavtab[0])); i++) {
        scavtab[i] = scav_lose;
    }

    /* For each type which can be selected by the lowtag alone, set
     * multiple entries in our widetag scavenge table (one for each
     * possible value of the high bits).
     */

    for (i = 0; i < (1<<(N_WIDETAG_BITS-N_LOWTAG_BITS)); i++) {
        scavtab[EVEN_FIXNUM_LOWTAG|(i<<N_LOWTAG_BITS)] = scav_immediate;
        scavtab[FUN_POINTER_LOWTAG|(i<<N_LOWTAG_BITS)] = scav_fun_pointer;
        /* skipping OTHER_IMMEDIATE_0_LOWTAG */
        scavtab[LIST_POINTER_LOWTAG|(i<<N_LOWTAG_BITS)] = scav_list_pointer;
        scavtab[ODD_FIXNUM_LOWTAG|(i<<N_LOWTAG_BITS)] = scav_immediate;
        scavtab[INSTANCE_POINTER_LOWTAG|(i<<N_LOWTAG_BITS)] =
            scav_instance_pointer;
        /* skipping OTHER_IMMEDIATE_1_LOWTAG */
        scavtab[OTHER_POINTER_LOWTAG|(i<<N_LOWTAG_BITS)] = scav_other_pointer;
    }

    /* Other-pointer types (those selected by all eight bits of the
     * tag) get one entry each in the scavenge table. */
    scavtab[BIGNUM_WIDETAG] = scav_unboxed;
    scavtab[RATIO_WIDETAG] = scav_boxed;
#if N_WORD_BITS == 64
    scavtab[SINGLE_FLOAT_WIDETAG] = scav_immediate;
#else
    scavtab[SINGLE_FLOAT_WIDETAG] = scav_unboxed;
#endif
    scavtab[DOUBLE_FLOAT_WIDETAG] = scav_unboxed;
#ifdef LONG_FLOAT_WIDETAG
    scavtab[LONG_FLOAT_WIDETAG] = scav_unboxed;
#endif
    scavtab[COMPLEX_WIDETAG] = scav_boxed;
#ifdef COMPLEX_SINGLE_FLOAT_WIDETAG
    scavtab[COMPLEX_SINGLE_FLOAT_WIDETAG] = scav_unboxed;
#endif
#ifdef COMPLEX_DOUBLE_FLOAT_WIDETAG
    scavtab[COMPLEX_DOUBLE_FLOAT_WIDETAG] = scav_unboxed;
#endif
#ifdef COMPLEX_LONG_FLOAT_WIDETAG
    scavtab[COMPLEX_LONG_FLOAT_WIDETAG] = scav_unboxed;
#endif
    scavtab[SIMPLE_ARRAY_WIDETAG] = scav_boxed;
    scavtab[SIMPLE_BASE_STRING_WIDETAG] = scav_base_string;
#ifdef SIMPLE_CHARACTER_STRING_WIDETAG
    scavtab[SIMPLE_CHARACTER_STRING_WIDETAG] = scav_character_string;
#endif
    scavtab[SIMPLE_BIT_VECTOR_WIDETAG] = scav_vector_bit;
    scavtab[SIMPLE_ARRAY_NIL_WIDETAG] = scav_vector_nil;
    scavtab[SIMPLE_ARRAY_UNSIGNED_BYTE_2_WIDETAG] =
        scav_vector_unsigned_byte_2;
    scavtab[SIMPLE_ARRAY_UNSIGNED_BYTE_4_WIDETAG] =
        scav_vector_unsigned_byte_4;
    scavtab[SIMPLE_ARRAY_UNSIGNED_BYTE_7_WIDETAG] =
        scav_vector_unsigned_byte_8;
    scavtab[SIMPLE_ARRAY_UNSIGNED_BYTE_8_WIDETAG] =
        scav_vector_unsigned_byte_8;
    scavtab[SIMPLE_ARRAY_UNSIGNED_BYTE_15_WIDETAG] =
        scav_vector_unsigned_byte_16;
    scavtab[SIMPLE_ARRAY_UNSIGNED_BYTE_16_WIDETAG] =
        scav_vector_unsigned_byte_16;
#ifdef SIMPLE_ARRAY_UNSIGNED_BYTE_29_WIDETAG
    scavtab[SIMPLE_ARRAY_UNSIGNED_BYTE_29_WIDETAG] =
        scav_vector_unsigned_byte_32;
#endif
    scavtab[SIMPLE_ARRAY_UNSIGNED_BYTE_31_WIDETAG] =
        scav_vector_unsigned_byte_32;
    scavtab[SIMPLE_ARRAY_UNSIGNED_BYTE_32_WIDETAG] =
        scav_vector_unsigned_byte_32;
#ifdef SIMPLE_ARRAY_UNSIGNED_BYTE_60_WIDETAG
    scavtab[SIMPLE_ARRAY_UNSIGNED_BYTE_60_WIDETAG] =
        scav_vector_unsigned_byte_64;
#endif
#ifdef SIMPLE_ARRAY_UNSIGNED_BYTE_63_WIDETAG
    scavtab[SIMPLE_ARRAY_UNSIGNED_BYTE_63_WIDETAG] =
        scav_vector_unsigned_byte_64;
#endif
#ifdef SIMPLE_ARRAY_UNSIGNED_BYTE_64_WIDETAG
    scavtab[SIMPLE_ARRAY_UNSIGNED_BYTE_64_WIDETAG] =
        scav_vector_unsigned_byte_64;
#endif
#ifdef SIMPLE_ARRAY_SIGNED_BYTE_8_WIDETAG
    scavtab[SIMPLE_ARRAY_SIGNED_BYTE_8_WIDETAG] = scav_vector_unsigned_byte_8;
#endif
#ifdef SIMPLE_ARRAY_SIGNED_BYTE_16_WIDETAG
    scavtab[SIMPLE_ARRAY_SIGNED_BYTE_16_WIDETAG] =
        scav_vector_unsigned_byte_16;
#endif
#ifdef SIMPLE_ARRAY_SIGNED_BYTE_30_WIDETAG
    scavtab[SIMPLE_ARRAY_SIGNED_BYTE_30_WIDETAG] =
        scav_vector_unsigned_byte_32;
#endif
#ifdef SIMPLE_ARRAY_SIGNED_BYTE_32_WIDETAG
    scavtab[SIMPLE_ARRAY_SIGNED_BYTE_32_WIDETAG] =
        scav_vector_unsigned_byte_32;
#endif
#ifdef SIMPLE_ARRAY_SIGNED_BYTE_61_WIDETAG
    scavtab[SIMPLE_ARRAY_SIGNED_BYTE_61_WIDETAG] =
        scav_vector_unsigned_byte_64;
#endif
#ifdef SIMPLE_ARRAY_SIGNED_BYTE_64_WIDETAG
    scavtab[SIMPLE_ARRAY_SIGNED_BYTE_64_WIDETAG] =
        scav_vector_unsigned_byte_64;
#endif
    scavtab[SIMPLE_ARRAY_SINGLE_FLOAT_WIDETAG] = scav_vector_single_float;
    scavtab[SIMPLE_ARRAY_DOUBLE_FLOAT_WIDETAG] = scav_vector_double_float;
#ifdef SIMPLE_ARRAY_LONG_FLOAT_WIDETAG
    scavtab[SIMPLE_ARRAY_LONG_FLOAT_WIDETAG] = scav_vector_long_float;
#endif
#ifdef SIMPLE_ARRAY_COMPLEX_SINGLE_FLOAT_WIDETAG
    scavtab[SIMPLE_ARRAY_COMPLEX_SINGLE_FLOAT_WIDETAG] =
        scav_vector_complex_single_float;
#endif
#ifdef SIMPLE_ARRAY_COMPLEX_DOUBLE_FLOAT_WIDETAG
    scavtab[SIMPLE_ARRAY_COMPLEX_DOUBLE_FLOAT_WIDETAG] =
        scav_vector_complex_double_float;
#endif
#ifdef SIMPLE_ARRAY_COMPLEX_LONG_FLOAT_WIDETAG
    scavtab[SIMPLE_ARRAY_COMPLEX_LONG_FLOAT_WIDETAG] =
        scav_vector_complex_long_float;
#endif
    scavtab[COMPLEX_BASE_STRING_WIDETAG] = scav_boxed;
#ifdef COMPLEX_CHARACTER_STRING_WIDETAG
    scavtab[COMPLEX_CHARACTER_STRING_WIDETAG] = scav_boxed;
#endif
    scavtab[COMPLEX_VECTOR_NIL_WIDETAG] = scav_boxed;
    scavtab[COMPLEX_BIT_VECTOR_WIDETAG] = scav_boxed;
    scavtab[COMPLEX_VECTOR_WIDETAG] = scav_boxed;
    scavtab[COMPLEX_ARRAY_WIDETAG] = scav_boxed;
    scavtab[CODE_HEADER_WIDETAG] = scav_code_header;
#if !defined(LISP_FEATURE_X86) && !defined(LISP_FEATURE_X86_64)
    scavtab[SIMPLE_FUN_HEADER_WIDETAG] = scav_fun_header;
    scavtab[RETURN_PC_HEADER_WIDETAG] = scav_return_pc_header;
#endif
    scavtab[FUNCALLABLE_INSTANCE_HEADER_WIDETAG] = scav_boxed;
#if defined(LISP_FEATURE_X86) || defined(LISP_FEATURE_X86_64)
    scavtab[CLOSURE_HEADER_WIDETAG] = scav_closure_header;
#else
    scavtab[CLOSURE_HEADER_WIDETAG] = scav_boxed;
#endif
    scavtab[VALUE_CELL_HEADER_WIDETAG] = scav_boxed;
    scavtab[SYMBOL_HEADER_WIDETAG] = scav_boxed;
    scavtab[CHARACTER_WIDETAG] = scav_immediate;
    scavtab[SAP_WIDETAG] = scav_unboxed;
    scavtab[UNBOUND_MARKER_WIDETAG] = scav_immediate;
    scavtab[NO_TLS_VALUE_MARKER_WIDETAG] = scav_immediate;
    scavtab[INSTANCE_HEADER_WIDETAG] = scav_instance;
#if defined(LISP_FEATURE_SPARC)
    scavtab[FDEFN_WIDETAG] = scav_boxed;
#else
    scavtab[FDEFN_WIDETAG] = scav_fdefn;
#endif
    scavtab[SIMPLE_VECTOR_WIDETAG] = scav_vector;

    /* transport other table, initialized same way as scavtab */
    for (i = 0; i < ((sizeof transother)/(sizeof transother[0])); i++)
        transother[i] = trans_lose;
    transother[BIGNUM_WIDETAG] = trans_unboxed;
    transother[RATIO_WIDETAG] = trans_boxed;

#if N_WORD_BITS == 64
    transother[SINGLE_FLOAT_WIDETAG] = trans_immediate;
#else
    transother[SINGLE_FLOAT_WIDETAG] = trans_unboxed;
#endif
    transother[DOUBLE_FLOAT_WIDETAG] = trans_unboxed;
#ifdef LONG_FLOAT_WIDETAG
    transother[LONG_FLOAT_WIDETAG] = trans_unboxed;
#endif
    transother[COMPLEX_WIDETAG] = trans_boxed;
#ifdef COMPLEX_SINGLE_FLOAT_WIDETAG
    transother[COMPLEX_SINGLE_FLOAT_WIDETAG] = trans_unboxed;
#endif
#ifdef COMPLEX_DOUBLE_FLOAT_WIDETAG
    transother[COMPLEX_DOUBLE_FLOAT_WIDETAG] = trans_unboxed;
#endif
#ifdef COMPLEX_LONG_FLOAT_WIDETAG
    transother[COMPLEX_LONG_FLOAT_WIDETAG] = trans_unboxed;
#endif
    transother[SIMPLE_ARRAY_WIDETAG] = trans_boxed; /* but not GENCGC */
    transother[SIMPLE_BASE_STRING_WIDETAG] = trans_base_string;
#ifdef SIMPLE_CHARACTER_STRING_WIDETAG
    transother[SIMPLE_CHARACTER_STRING_WIDETAG] = trans_character_string;
#endif
    transother[SIMPLE_BIT_VECTOR_WIDETAG] = trans_vector_bit;
    transother[SIMPLE_VECTOR_WIDETAG] = trans_vector;
    transother[SIMPLE_ARRAY_NIL_WIDETAG] = trans_vector_nil;
    transother[SIMPLE_ARRAY_UNSIGNED_BYTE_2_WIDETAG] =
        trans_vector_unsigned_byte_2;
    transother[SIMPLE_ARRAY_UNSIGNED_BYTE_4_WIDETAG] =
        trans_vector_unsigned_byte_4;
    transother[SIMPLE_ARRAY_UNSIGNED_BYTE_7_WIDETAG] =
        trans_vector_unsigned_byte_8;
    transother[SIMPLE_ARRAY_UNSIGNED_BYTE_8_WIDETAG] =
        trans_vector_unsigned_byte_8;
    transother[SIMPLE_ARRAY_UNSIGNED_BYTE_15_WIDETAG] =
        trans_vector_unsigned_byte_16;
    transother[SIMPLE_ARRAY_UNSIGNED_BYTE_16_WIDETAG] =
        trans_vector_unsigned_byte_16;
#ifdef SIMPLE_ARRAY_UNSIGNED_BYTE_29_WIDETAG
    transother[SIMPLE_ARRAY_UNSIGNED_BYTE_29_WIDETAG] =
        trans_vector_unsigned_byte_32;
#endif
    transother[SIMPLE_ARRAY_UNSIGNED_BYTE_31_WIDETAG] =
        trans_vector_unsigned_byte_32;
    transother[SIMPLE_ARRAY_UNSIGNED_BYTE_32_WIDETAG] =
        trans_vector_unsigned_byte_32;
#ifdef SIMPLE_ARRAY_UNSIGNED_BYTE_60_WIDETAG
    transother[SIMPLE_ARRAY_UNSIGNED_BYTE_60_WIDETAG] =
        trans_vector_unsigned_byte_64;
#endif
#ifdef SIMPLE_ARRAY_UNSIGNED_BYTE_63_WIDETAG
    transother[SIMPLE_ARRAY_UNSIGNED_BYTE_63_WIDETAG] =
        trans_vector_unsigned_byte_64;
#endif
#ifdef SIMPLE_ARRAY_UNSIGNED_BYTE_64_WIDETAG
    transother[SIMPLE_ARRAY_UNSIGNED_BYTE_64_WIDETAG] =
        trans_vector_unsigned_byte_64;
#endif
#ifdef SIMPLE_ARRAY_SIGNED_BYTE_8_WIDETAG
    transother[SIMPLE_ARRAY_SIGNED_BYTE_8_WIDETAG] =
        trans_vector_unsigned_byte_8;
#endif
#ifdef SIMPLE_ARRAY_SIGNED_BYTE_16_WIDETAG
    transother[SIMPLE_ARRAY_SIGNED_BYTE_16_WIDETAG] =
        trans_vector_unsigned_byte_16;
#endif
#ifdef SIMPLE_ARRAY_SIGNED_BYTE_30_WIDETAG
    transother[SIMPLE_ARRAY_SIGNED_BYTE_30_WIDETAG] =
        trans_vector_unsigned_byte_32;
#endif
#ifdef SIMPLE_ARRAY_SIGNED_BYTE_32_WIDETAG
    transother[SIMPLE_ARRAY_SIGNED_BYTE_32_WIDETAG] =
        trans_vector_unsigned_byte_32;
#endif
#ifdef SIMPLE_ARRAY_SIGNED_BYTE_61_WIDETAG
    transother[SIMPLE_ARRAY_SIGNED_BYTE_61_WIDETAG] =
        trans_vector_unsigned_byte_64;
#endif
#ifdef SIMPLE_ARRAY_SIGNED_BYTE_64_WIDETAG
    transother[SIMPLE_ARRAY_SIGNED_BYTE_64_WIDETAG] =
        trans_vector_unsigned_byte_64;
#endif
    transother[SIMPLE_ARRAY_SINGLE_FLOAT_WIDETAG] =
        trans_vector_single_float;
    transother[SIMPLE_ARRAY_DOUBLE_FLOAT_WIDETAG] =
        trans_vector_double_float;
#ifdef SIMPLE_ARRAY_LONG_FLOAT_WIDETAG
    transother[SIMPLE_ARRAY_LONG_FLOAT_WIDETAG] =
        trans_vector_long_float;
#endif
#ifdef SIMPLE_ARRAY_COMPLEX_SINGLE_FLOAT_WIDETAG
    transother[SIMPLE_ARRAY_COMPLEX_SINGLE_FLOAT_WIDETAG] =
        trans_vector_complex_single_float;
#endif
#ifdef SIMPLE_ARRAY_COMPLEX_DOUBLE_FLOAT_WIDETAG
    transother[SIMPLE_ARRAY_COMPLEX_DOUBLE_FLOAT_WIDETAG] =
        trans_vector_complex_double_float;
#endif
#ifdef SIMPLE_ARRAY_COMPLEX_LONG_FLOAT_WIDETAG
    transother[SIMPLE_ARRAY_COMPLEX_LONG_FLOAT_WIDETAG] =
        trans_vector_complex_long_float;
#endif
    transother[COMPLEX_BASE_STRING_WIDETAG] = trans_boxed;
#ifdef COMPLEX_CHARACTER_STRING_WIDETAG
    transother[COMPLEX_CHARACTER_STRING_WIDETAG] = trans_boxed;
#endif
    transother[COMPLEX_BIT_VECTOR_WIDETAG] = trans_boxed;
    transother[COMPLEX_VECTOR_NIL_WIDETAG] = trans_boxed;
    transother[COMPLEX_VECTOR_WIDETAG] = trans_boxed;
    transother[COMPLEX_ARRAY_WIDETAG] = trans_boxed;
    transother[CODE_HEADER_WIDETAG] = trans_code_header;
    transother[SIMPLE_FUN_HEADER_WIDETAG] = trans_fun_header;
    transother[RETURN_PC_HEADER_WIDETAG] = trans_return_pc_header;
    transother[CLOSURE_HEADER_WIDETAG] = trans_boxed;
    transother[FUNCALLABLE_INSTANCE_HEADER_WIDETAG] = trans_boxed;
    transother[VALUE_CELL_HEADER_WIDETAG] = trans_boxed;
    transother[SYMBOL_HEADER_WIDETAG] = trans_boxed;
    transother[CHARACTER_WIDETAG] = trans_immediate;
    transother[SAP_WIDETAG] = trans_unboxed;
    transother[UNBOUND_MARKER_WIDETAG] = trans_immediate;
    transother[NO_TLS_VALUE_MARKER_WIDETAG] = trans_immediate;
    transother[WEAK_POINTER_WIDETAG] = trans_weak_pointer;
    transother[INSTANCE_HEADER_WIDETAG] = trans_boxed;
    transother[FDEFN_WIDETAG] = trans_boxed;

    /* size table, initialized the same way as scavtab */
    for (i = 0; i < ((sizeof sizetab)/(sizeof sizetab[0])); i++)
        sizetab[i] = size_lose;
    for (i = 0; i < (1<<(N_WIDETAG_BITS-N_LOWTAG_BITS)); i++) {
        sizetab[EVEN_FIXNUM_LOWTAG|(i<<N_LOWTAG_BITS)] = size_immediate;
        sizetab[FUN_POINTER_LOWTAG|(i<<N_LOWTAG_BITS)] = size_pointer;
        /* skipping OTHER_IMMEDIATE_0_LOWTAG */
        sizetab[LIST_POINTER_LOWTAG|(i<<N_LOWTAG_BITS)] = size_pointer;
        sizetab[ODD_FIXNUM_LOWTAG|(i<<N_LOWTAG_BITS)] = size_immediate;
        sizetab[INSTANCE_POINTER_LOWTAG|(i<<N_LOWTAG_BITS)] = size_pointer;
        /* skipping OTHER_IMMEDIATE_1_LOWTAG */
        sizetab[OTHER_POINTER_LOWTAG|(i<<N_LOWTAG_BITS)] = size_pointer;
    }
    sizetab[BIGNUM_WIDETAG] = size_unboxed;
    sizetab[RATIO_WIDETAG] = size_boxed;
#if N_WORD_BITS == 64
    sizetab[SINGLE_FLOAT_WIDETAG] = size_immediate;
#else
    sizetab[SINGLE_FLOAT_WIDETAG] = size_unboxed;
#endif
    sizetab[DOUBLE_FLOAT_WIDETAG] = size_unboxed;
#ifdef LONG_FLOAT_WIDETAG
    sizetab[LONG_FLOAT_WIDETAG] = size_unboxed;
#endif
    sizetab[COMPLEX_WIDETAG] = size_boxed;
#ifdef COMPLEX_SINGLE_FLOAT_WIDETAG
    sizetab[COMPLEX_SINGLE_FLOAT_WIDETAG] = size_unboxed;
#endif
#ifdef COMPLEX_DOUBLE_FLOAT_WIDETAG
    sizetab[COMPLEX_DOUBLE_FLOAT_WIDETAG] = size_unboxed;
#endif
#ifdef COMPLEX_LONG_FLOAT_WIDETAG
    sizetab[COMPLEX_LONG_FLOAT_WIDETAG] = size_unboxed;
#endif
    sizetab[SIMPLE_ARRAY_WIDETAG] = size_boxed;
    sizetab[SIMPLE_BASE_STRING_WIDETAG] = size_base_string;
#ifdef SIMPLE_CHARACTER_STRING_WIDETAG
    sizetab[SIMPLE_CHARACTER_STRING_WIDETAG] = size_character_string;
#endif
    sizetab[SIMPLE_BIT_VECTOR_WIDETAG] = size_vector_bit;
    sizetab[SIMPLE_VECTOR_WIDETAG] = size_vector;
    sizetab[SIMPLE_ARRAY_NIL_WIDETAG] = size_vector_nil;
    sizetab[SIMPLE_ARRAY_UNSIGNED_BYTE_2_WIDETAG] =
        size_vector_unsigned_byte_2;
    sizetab[SIMPLE_ARRAY_UNSIGNED_BYTE_4_WIDETAG] =
        size_vector_unsigned_byte_4;
    sizetab[SIMPLE_ARRAY_UNSIGNED_BYTE_7_WIDETAG] =
        size_vector_unsigned_byte_8;
    sizetab[SIMPLE_ARRAY_UNSIGNED_BYTE_8_WIDETAG] =
        size_vector_unsigned_byte_8;
    sizetab[SIMPLE_ARRAY_UNSIGNED_BYTE_15_WIDETAG] =
        size_vector_unsigned_byte_16;
    sizetab[SIMPLE_ARRAY_UNSIGNED_BYTE_16_WIDETAG] =
        size_vector_unsigned_byte_16;
#ifdef SIMPLE_ARRAY_UNSIGNED_BYTE_29_WIDETAG
    sizetab[SIMPLE_ARRAY_UNSIGNED_BYTE_29_WIDETAG] =
        size_vector_unsigned_byte_32;
#endif
    sizetab[SIMPLE_ARRAY_UNSIGNED_BYTE_31_WIDETAG] =
        size_vector_unsigned_byte_32;
    sizetab[SIMPLE_ARRAY_UNSIGNED_BYTE_32_WIDETAG] =
        size_vector_unsigned_byte_32;
#ifdef SIMPLE_ARRAY_UNSIGNED_BYTE_60_WIDETAG
    sizetab[SIMPLE_ARRAY_UNSIGNED_BYTE_60_WIDETAG] =
        size_vector_unsigned_byte_64;
#endif
#ifdef SIMPLE_ARRAY_UNSIGNED_BYTE_63_WIDETAG
    sizetab[SIMPLE_ARRAY_UNSIGNED_BYTE_63_WIDETAG] =
        size_vector_unsigned_byte_64;
#endif
#ifdef SIMPLE_ARRAY_UNSIGNED_BYTE_64_WIDETAG
    sizetab[SIMPLE_ARRAY_UNSIGNED_BYTE_64_WIDETAG] =
        size_vector_unsigned_byte_64;
#endif
#ifdef SIMPLE_ARRAY_SIGNED_BYTE_8_WIDETAG
    sizetab[SIMPLE_ARRAY_SIGNED_BYTE_8_WIDETAG] = size_vector_unsigned_byte_8;
#endif
#ifdef SIMPLE_ARRAY_SIGNED_BYTE_16_WIDETAG
    sizetab[SIMPLE_ARRAY_SIGNED_BYTE_16_WIDETAG] =
        size_vector_unsigned_byte_16;
#endif
#ifdef SIMPLE_ARRAY_SIGNED_BYTE_30_WIDETAG
    sizetab[SIMPLE_ARRAY_SIGNED_BYTE_30_WIDETAG] =
        size_vector_unsigned_byte_32;
#endif
#ifdef SIMPLE_ARRAY_SIGNED_BYTE_32_WIDETAG
    sizetab[SIMPLE_ARRAY_SIGNED_BYTE_32_WIDETAG] =
        size_vector_unsigned_byte_32;
#endif
#ifdef SIMPLE_ARRAY_SIGNED_BYTE_61_WIDETAG
    sizetab[SIMPLE_ARRAY_SIGNED_BYTE_61_WIDETAG] =
        size_vector_unsigned_byte_64;
#endif
#ifdef SIMPLE_ARRAY_SIGNED_BYTE_64_WIDETAG
    sizetab[SIMPLE_ARRAY_SIGNED_BYTE_64_WIDETAG] =
        size_vector_unsigned_byte_64;
#endif
    sizetab[SIMPLE_ARRAY_SINGLE_FLOAT_WIDETAG] = size_vector_single_float;
    sizetab[SIMPLE_ARRAY_DOUBLE_FLOAT_WIDETAG] = size_vector_double_float;
#ifdef SIMPLE_ARRAY_LONG_FLOAT_WIDETAG
    sizetab[SIMPLE_ARRAY_LONG_FLOAT_WIDETAG] = size_vector_long_float;
#endif
#ifdef SIMPLE_ARRAY_COMPLEX_SINGLE_FLOAT_WIDETAG
    sizetab[SIMPLE_ARRAY_COMPLEX_SINGLE_FLOAT_WIDETAG] =
        size_vector_complex_single_float;
#endif
#ifdef SIMPLE_ARRAY_COMPLEX_DOUBLE_FLOAT_WIDETAG
    sizetab[SIMPLE_ARRAY_COMPLEX_DOUBLE_FLOAT_WIDETAG] =
        size_vector_complex_double_float;
#endif
#ifdef SIMPLE_ARRAY_COMPLEX_LONG_FLOAT_WIDETAG
    sizetab[SIMPLE_ARRAY_COMPLEX_LONG_FLOAT_WIDETAG] =
        size_vector_complex_long_float;
#endif
    sizetab[COMPLEX_BASE_STRING_WIDETAG] = size_boxed;
#ifdef COMPLEX_CHARACTER_STRING_WIDETAG
    sizetab[COMPLEX_CHARACTER_STRING_WIDETAG] = size_boxed;
#endif
    sizetab[COMPLEX_VECTOR_NIL_WIDETAG] = size_boxed;
    sizetab[COMPLEX_BIT_VECTOR_WIDETAG] = size_boxed;
    sizetab[COMPLEX_VECTOR_WIDETAG] = size_boxed;
    sizetab[COMPLEX_ARRAY_WIDETAG] = size_boxed;
    sizetab[CODE_HEADER_WIDETAG] = size_code_header;
#if 0
    /* We shouldn't see these, so just lose if it happens. */
    sizetab[SIMPLE_FUN_HEADER_WIDETAG] = size_function_header;
    sizetab[RETURN_PC_HEADER_WIDETAG] = size_return_pc_header;
#endif
    sizetab[CLOSURE_HEADER_WIDETAG] = size_boxed;
    sizetab[FUNCALLABLE_INSTANCE_HEADER_WIDETAG] = size_boxed;
    sizetab[VALUE_CELL_HEADER_WIDETAG] = size_boxed;
    sizetab[SYMBOL_HEADER_WIDETAG] = size_boxed;
    sizetab[CHARACTER_WIDETAG] = size_immediate;
    sizetab[SAP_WIDETAG] = size_unboxed;
    sizetab[UNBOUND_MARKER_WIDETAG] = size_immediate;
    sizetab[NO_TLS_VALUE_MARKER_WIDETAG] = size_immediate;
    sizetab[WEAK_POINTER_WIDETAG] = size_weak_pointer;
    sizetab[INSTANCE_HEADER_WIDETAG] = size_boxed;
    sizetab[FDEFN_WIDETAG] = size_boxed;
}


/* Find the code object for the given pc, or return NULL on
   failure. */
lispobj *
component_ptr_from_pc(lispobj *pc)
{
    lispobj *object = NULL;

    if ( (object = search_read_only_space(pc)) )
        ;
    else if ( (object = search_static_space(pc)) )
        ;
    else
        object = search_dynamic_space(pc);

    if (object) /* if we found something */
        if (widetag_of(*object) == CODE_HEADER_WIDETAG)
            return(object);

    return (NULL);
}

/* Scan an area looking for an object which encloses the given pointer.
 * Return the object start on success or NULL on failure. */
lispobj *
gc_search_space(lispobj *start, size_t words, lispobj *pointer)
{
    while (words > 0) {
        size_t count = 1;
        lispobj thing = *start;

        /* If thing is an immediate then this is a cons. */
        if (is_lisp_pointer(thing) || is_lisp_immediate(thing))
            count = 2;
        else
            count = (sizetab[widetag_of(thing)])(start);

        /* Check whether the pointer is within this object. */
        if ((pointer >= start) && (pointer < (start+count))) {
            /* found it! */
            /*FSHOW((stderr,"/found %x in %x %x\n", pointer, start, thing));*/
            return(start);
        }

        /* Round up the count. */
        count = CEILING(count,2);

        start += count;
        words -= count;
    }
    return (NULL);
}

boolean
maybe_gc(os_context_t *context)
{
    lispobj gc_happened;
    struct thread *thread = arch_os_get_current_thread();

    fake_foreign_function_call(context);
    /* SUB-GC may return without GCing if *GC-INHIBIT* is set, in
     * which case we will be running with no gc trigger barrier
     * thing for a while.  But it shouldn't be long until the end
     * of WITHOUT-GCING.
     *
     * FIXME: It would be good to protect the end of dynamic space for
     * CheneyGC and signal a storage condition from there.
     */

    /* Restore the signal mask from the interrupted context before
     * calling into Lisp if interrupts are enabled. Why not always?
     *
     * Suppose there is a WITHOUT-INTERRUPTS block far, far out. If an
     * interrupt hits while in SUB-GC, it is deferred and the
     * os_context_sigmask of that interrupt is set to block further
     * deferrable interrupts (until the first one is
     * handled). Unfortunately, that context refers to this place and
     * when we return from here the signals will not be blocked.
     *
     * A kludgy alternative is to propagate the sigmask change to the
     * outer context.
     */
#ifndef LISP_FEATURE_WIN32
    check_gc_signals_unblocked_or_lose(os_context_sigmask_addr(context));
    unblock_gc_signals(0, 0);
#endif
    FSHOW((stderr, "/maybe_gc: calling SUB_GC\n"));
    /* FIXME: Nothing must go wrong during GC else we end up running
     * the debugger, error handlers, and user code in general in a
     * potentially unsafe place. Running out of the control stack or
     * the heap in SUB-GC are ways to lose. Of course, deferrables
     * cannot be unblocked because there may be a pending handler, or
     * we may even be in a WITHOUT-INTERRUPTS. */
    gc_happened = funcall0(StaticSymbolFunction(SUB_GC));
    FSHOW((stderr, "/maybe_gc: gc_happened=%s\n",
           (gc_happened == NIL) ? "NIL" : "T"));
    if ((gc_happened != NIL) &&
        /* See if interrupts are enabled or it's possible to enable
         * them. POST-GC has a similar check, but we don't want to
         * unlock deferrables in that case and get a pending interrupt
         * here. */
        ((SymbolValue(INTERRUPTS_ENABLED,thread) != NIL) ||
         (SymbolValue(ALLOW_WITH_INTERRUPTS,thread) != NIL))) {
#ifndef LISP_FEATURE_WIN32
        sigset_t *context_sigmask = os_context_sigmask_addr(context);
        if (!deferrables_blocked_p(context_sigmask)) {
            thread_sigmask(SIG_SETMASK, context_sigmask, 0);
            check_gc_signals_unblocked_or_lose(0);
#endif
            FSHOW((stderr, "/maybe_gc: calling POST_GC\n"));
            funcall0(StaticSymbolFunction(POST_GC));
#ifndef LISP_FEATURE_WIN32
        } else {
            FSHOW((stderr, "/maybe_gc: punting on POST_GC due to blockage\n"));
        }
#endif
    }
    undo_fake_foreign_function_call(context);
    FSHOW((stderr, "/maybe_gc: returning\n"));
    return (gc_happened != NIL);
}

#define BYTES_ZERO_BEFORE_END (1<<12)

/* There used to be a similar function called SCRUB-CONTROL-STACK in
 * Lisp and another called zero_stack() in cheneygc.c, but since it's
 * shorter to express in, and more often called from C, I keep only
 * the C one after fixing it. -- MG 2009-03-25 */

/* Zero the unused portion of the control stack so that old objects
 * are not kept alive because of uninitialized stack variables.
 *
 * "To summarize the problem, since not all allocated stack frame
 * slots are guaranteed to be written by the time you call an another
 * function or GC, there may be garbage pointers retained in your dead
 * stack locations. The stack scrubbing only affects the part of the
 * stack from the SP to the end of the allocated stack." - ram, on
 * cmucl-imp, Tue, 25 Sep 2001
 *
 * So, as an (admittedly lame) workaround, from time to time we call
 * scrub-control-stack to zero out all the unused portion. This is
 * supposed to happen when the stack is mostly empty, so that we have
 * a chance of clearing more of it: callers are currently (2002.07.18)
 * REPL, SUB-GC and sig_stop_for_gc_handler. */

/* Take care not to tread on the guard page and the hard guard page as
 * it would be unkind to sig_stop_for_gc_handler. Touching the return
 * guard page is not dangerous. For this to work the guard page must
 * be zeroed when protected. */

/* FIXME: I think there is no guarantee that once
 * BYTES_ZERO_BEFORE_END bytes are zero the rest are also zero. This
 * may be what the "lame" adjective in the above comment is for. In
 * this case, exact gc may lose badly. */
void
scrub_control_stack(void)
{
    struct thread *th = arch_os_get_current_thread();
    os_vm_address_t guard_page_address = CONTROL_STACK_GUARD_PAGE(th);
    os_vm_address_t hard_guard_page_address = CONTROL_STACK_HARD_GUARD_PAGE(th);
    lispobj *sp;
#ifdef LISP_FEATURE_C_STACK_IS_CONTROL_STACK
    sp = (lispobj *)&sp - 1;
#else
    sp = access_control_stack_pointer(th);
#endif
 scrub:
    if ((((os_vm_address_t)sp < (hard_guard_page_address + os_vm_page_size)) &&
         ((os_vm_address_t)sp >= hard_guard_page_address)) ||
        (((os_vm_address_t)sp < (guard_page_address + os_vm_page_size)) &&
         ((os_vm_address_t)sp >= guard_page_address) &&
         (th->control_stack_guard_page_protected != NIL)))
        return;
#ifdef LISP_FEATURE_STACK_GROWS_DOWNWARD_NOT_UPWARD
    do {
        *sp = 0;
    } while (((unsigned long)sp--) & (BYTES_ZERO_BEFORE_END - 1));
    if ((os_vm_address_t)sp < (hard_guard_page_address + os_vm_page_size))
        return;
    do {
        if (*sp)
            goto scrub;
    } while (((unsigned long)sp--) & (BYTES_ZERO_BEFORE_END - 1));
#else
    do {
        *sp = 0;
    } while (((unsigned long)++sp) & (BYTES_ZERO_BEFORE_END - 1));
    if ((os_vm_address_t)sp >= hard_guard_page_address)
        return;
    do {
        if (*sp)
            goto scrub;
    } while (((unsigned long)++sp) & (BYTES_ZERO_BEFORE_END - 1));
#endif
}

#if !defined(LISP_FEATURE_X86) && !defined(LISP_FEATURE_X86_64)

/* Scavenging Interrupt Contexts */

static int boxed_registers[] = BOXED_REGISTERS;

/* The GC has a notion of an "interior pointer" register, an unboxed
 * register that typically contains a pointer to inside an object
 * referenced by another pointer.  The most obvious of these is the
 * program counter, although many compiler backends define a "Lisp
 * Interior Pointer" register known to the runtime as reg_LIP, and
 * various CPU architectures have other registers that also partake of
 * the interior-pointer nature.  As the code for pairing an interior
 * pointer value up with its "base" register, and fixing it up after
 * scavenging is complete is horribly repetitive, a few macros paper
 * over the monotony.  --AB, 2010-Jul-14 */

/* These macros are only ever used over a lexical environment which
 * defines a pointer to an os_context_t called context, thus we don't
 * bother to pass that context in as a parameter. */

/* Define how to access a given interior pointer. */
#define ACCESS_INTERIOR_POINTER_pc \
    *os_context_pc_addr(context)
#define ACCESS_INTERIOR_POINTER_lip \
    *os_context_register_addr(context, reg_LIP)
#define ACCESS_INTERIOR_POINTER_lr \
    *os_context_lr_addr(context)
#define ACCESS_INTERIOR_POINTER_npc \
    *os_context_npc_addr(context)
#define ACCESS_INTERIOR_POINTER_ctr \
    *os_context_ctr_addr(context)

#define INTERIOR_POINTER_VARS(name) \
    unsigned long name##_offset;    \
    int name##_register_pair

#define PAIR_INTERIOR_POINTER(name)                             \
    pair_interior_pointer(context,                              \
                          ACCESS_INTERIOR_POINTER_##name,       \
                          &name##_offset,                       \
                          &name##_register_pair)

/* One complexity here is that if a paired register is not found for
 * an interior pointer, then that pointer does not get updated.
 * Originally, there was some commentary about using an index of -1
 * when calling os_context_register_addr() on SPARC referring to the
 * program counter, but the real reason is to allow an interior
 * pointer register to point to the runtime, read-only space, or
 * static space without problems. */
#define FIXUP_INTERIOR_POINTER(name)                                    \
    do {                                                                \
        if (name##_register_pair >= 0) {                                \
            ACCESS_INTERIOR_POINTER_##name =                            \
                (*os_context_register_addr(context,                     \
                                           name##_register_pair)        \
                 & ~LOWTAG_MASK)                                        \
                + name##_offset;                                        \
        }                                                               \
    } while (0)


static void
pair_interior_pointer(os_context_t *context, unsigned long pointer,
                      unsigned long *saved_offset, int *register_pair)
{
    int i;

    /*
     * I (RLT) think this is trying to find the boxed register that is
     * closest to the LIP address, without going past it.  Usually, it's
     * reg_CODE or reg_LRA.  But sometimes, nothing can be found.
     */
    /* 0x7FFFFFFF on 32-bit platforms;
       0x7FFFFFFFFFFFFFFF on 64-bit platforms */
    *saved_offset = (((unsigned long)1) << (N_WORD_BITS - 1)) - 1;
    *register_pair = -1;
    for (i = 0; i < (sizeof(boxed_registers) / sizeof(int)); i++) {
        unsigned long reg;
        long offset;
        int index;

        index = boxed_registers[i];
        reg = *os_context_register_addr(context, index);

        /* An interior pointer is never relative to a non-pointer
         * register (an oversight in the original implementation).
         * The simplest argument for why this is true is to consider
         * the fixnum that happens by coincide to be the word-index in
         * memory of the header for some object plus two.  This is
         * happenstance would cause the register containing the fixnum
         * to be selected as the register_pair if the interior pointer
         * is to anywhere after the first two words of the object.
         * The fixnum won't be changed during GC, but the object might
         * move, thus destroying the interior pointer.  --AB,
         * 2010-Jul-14 */

        if (is_lisp_pointer(reg) &&
            ((reg & ~LOWTAG_MASK) <= pointer)) {
            offset = pointer - (reg & ~LOWTAG_MASK);
            if (offset < *saved_offset) {
                *saved_offset = offset;
                *register_pair = index;
            }
        }
    }
}

static void
scavenge_interrupt_context(os_context_t * context)
{
    int i;

    /* FIXME: The various #ifdef noise here is precisely that: noise.
     * Is it possible to fold it into the macrology so that we have
     * one set of #ifdefs and then INTERIOR_POINTER_VARS /et alia/
     * compile out for the registers that don't exist on a given
     * platform? */

    INTERIOR_POINTER_VARS(pc);
#ifdef reg_LIP
    INTERIOR_POINTER_VARS(lip);
#endif
#ifdef ARCH_HAS_LINK_REGISTER
    INTERIOR_POINTER_VARS(lr);
#endif
#ifdef ARCH_HAS_NPC_REGISTER
    INTERIOR_POINTER_VARS(npc);
#endif
#ifdef LISP_FEATURE_PPC
    INTERIOR_POINTER_VARS(ctr);
#endif

    PAIR_INTERIOR_POINTER(pc);
#ifdef reg_LIP
    PAIR_INTERIOR_POINTER(lip);
#endif
#ifdef ARCH_HAS_LINK_REGISTER
    PAIR_INTERIOR_POINTER(lr);
#endif
#ifdef ARCH_HAS_NPC_REGISTER
    PAIR_INTERIOR_POINTER(npc);
#endif
#ifdef LISP_FEATURE_PPC
    PAIR_INTERIOR_POINTER(ctr);
#endif

    /* Scavenge all boxed registers in the context. */
    for (i = 0; i < (sizeof(boxed_registers) / sizeof(int)); i++) {
        int index;
        lispobj foo;

        index = boxed_registers[i];
        foo = *os_context_register_addr(context, index);
        scavenge(&foo, 1);
        *os_context_register_addr(context, index) = foo;

        /* this is unlikely to work as intended on bigendian
         * 64 bit platforms */

        scavenge((lispobj *) os_context_register_addr(context, index), 1);
    }

    /* Now that the scavenging is done, repair the various interior
     * pointers. */
    FIXUP_INTERIOR_POINTER(pc);
#ifdef reg_LIP
    FIXUP_INTERIOR_POINTER(lip);
#endif
#ifdef ARCH_HAS_LINK_REGISTER
    FIXUP_INTERIOR_POINTER(lr);
#endif
#ifdef ARCH_HAS_NPC_REGISTER
    FIXUP_INTERIOR_POINTER(npc);
#endif
#ifdef LISP_FEATURE_PPC
    FIXUP_INTERIOR_POINTER(ctr);
#endif
}

void
scavenge_interrupt_contexts(struct thread *th)
{
    int i, index;
    os_context_t *context;

    index = fixnum_value(SymbolValue(FREE_INTERRUPT_CONTEXT_INDEX,th));

#if defined(DEBUG_PRINT_CONTEXT_INDEX)
    printf("Number of active contexts: %d\n", index);
#endif

    for (i = 0; i < index; i++) {
        context = th->interrupt_contexts[i];
        scavenge_interrupt_context(context);
    }
}
#endif /* x86oid targets */
