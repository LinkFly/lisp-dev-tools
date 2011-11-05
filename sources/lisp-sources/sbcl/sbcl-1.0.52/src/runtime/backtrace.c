/*
 * simple backtrace facility
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

#include <stdio.h>
#include <signal.h>
#include "sbcl.h"
#include "runtime.h"
#include "globals.h"
#include "os.h"
#include "interrupt.h"
#include "lispregs.h"
#ifdef LISP_FEATURE_GENCGC
#include <wchar.h>
#include "arch.h"
#include "gencgc-alloc-region.h"
#include "genesis/compiled-debug-fun.h"
#include "genesis/compiled-debug-info.h"
#include "genesis/package.h"
#endif
#include "genesis/static-symbols.h"
#include "genesis/primitive-objects.h"
#include "thread.h"

#ifdef LISP_FEATURE_OS_PROVIDES_DLADDR
# ifndef __USE_GNU
/* __USE_GNU needed if we want dladdr() and Dl_Info from glibc. */
# define __USE_GNU
# endif
# include "dlfcn.h"
#endif

#if !(defined(LISP_FEATURE_X86) || defined(LISP_FEATURE_X86_64))

/* KLUDGE: Sigh ... I know what the call frame looks like and it had
 * better not change. */

struct call_frame {
#ifndef LISP_FEATURE_ALPHA
        struct call_frame *old_cont;
#else
        u32 old_cont;
#endif
        lispobj saved_lra;
        lispobj code;
        lispobj other_state[5];
};

struct call_info {
#ifndef LISP_FEATURE_ALPHA
    struct call_frame *frame;
#else
    u32 frame;
#endif
    int interrupted;
#ifndef LISP_FEATURE_ALPHA
    struct code *code;
#else
    u32 code;
#endif
    lispobj lra;
    int pc; /* Note: this is the trace file offset, not the actual pc. */
};

#define HEADER_LENGTH(header) ((header)>>8)

static int previous_info(struct call_info *info);

static struct code *
code_pointer(lispobj object)
{
    lispobj *headerp, header;
    int type, len;

    headerp = (lispobj *) native_pointer(object);
    header = *headerp;
    type = widetag_of(header);

    switch (type) {
        case CODE_HEADER_WIDETAG:
            break;
        case RETURN_PC_HEADER_WIDETAG:
        case SIMPLE_FUN_HEADER_WIDETAG:
            len = HEADER_LENGTH(header);
            if (len == 0)
                headerp = NULL;
            else
                headerp -= len;
            break;
        default:
            headerp = NULL;
    }

    return (struct code *) headerp;
}

static boolean
cs_valid_pointer_p(struct call_frame *pointer)
{
    struct thread *thread=arch_os_get_current_thread();
    return (((char *) thread->control_stack_start <= (char *) pointer) &&
            ((char *) pointer < (char *) access_control_stack_pointer(thread)));
}

static void
call_info_from_lisp_state(struct call_info *info)
{
    info->frame = (struct call_frame *)access_control_frame_pointer(arch_os_get_current_thread());
    info->interrupted = 0;
    info->code = NULL;
    info->lra = 0;
    info->pc = 0;

    previous_info(info);
}

static void
call_info_from_context(struct call_info *info, os_context_t *context)
{
    unsigned long pc;

    info->interrupted = 1;
    if (lowtag_of(*os_context_register_addr(context, reg_CODE))
        == FUN_POINTER_LOWTAG) {
        /* We tried to call a function, but crapped out before $CODE could
         * be fixed up. Probably an undefined function. */
        info->frame =
            (struct call_frame *)(unsigned long)
                (*os_context_register_addr(context, reg_OCFP));
        info->lra = (lispobj)(*os_context_register_addr(context, reg_LRA));
        info->code = code_pointer(info->lra);
        pc = (unsigned long)native_pointer(info->lra);
    }
    else {
        info->frame =
            (struct call_frame *)(unsigned long)
                (*os_context_register_addr(context, reg_CFP));
        info->code =
            code_pointer(*os_context_register_addr(context, reg_CODE));
        info->lra = NIL;
        pc = *os_context_pc_addr(context);
    }
    if (info->code != NULL)
        info->pc = pc - (unsigned long) info->code -
#ifndef LISP_FEATURE_ALPHA
            (HEADER_LENGTH(info->code->header) * sizeof(lispobj));
#else
            (HEADER_LENGTH(((struct code *)info->code)->header) * sizeof(lispobj));
#endif
    else
        info->pc = 0;
}

static int
previous_info(struct call_info *info)
{
    struct call_frame *this_frame;
    struct thread *thread=arch_os_get_current_thread();
    int free_ici;

    if (!cs_valid_pointer_p(info->frame)) {
        printf("Bogus callee value (0x%08lx).\n", (unsigned long)info->frame);
        return 0;
    }

    this_frame = info->frame;
    info->lra = this_frame->saved_lra;
    info->frame = this_frame->old_cont;
    info->interrupted = 0;

    if (info->frame == NULL || info->frame == this_frame)
        return 0;

    if (info->lra == NIL) {
        /* We were interrupted. Find the correct signal context. */
        free_ici = fixnum_value(SymbolValue(FREE_INTERRUPT_CONTEXT_INDEX,thread));
        while (free_ici-- > 0) {
            os_context_t *context =
                thread->interrupt_contexts[free_ici];
            if ((struct call_frame *)(unsigned long)
                    (*os_context_register_addr(context, reg_CFP))
                == info->frame) {
                call_info_from_context(info, context);
                break;
            }
        }
    }
    else {
        info->code = code_pointer(info->lra);
        if (info->code != NULL)
            info->pc = (unsigned long)native_pointer(info->lra) -
                (unsigned long)info->code -
#ifndef LISP_FEATURE_ALPHA
                (HEADER_LENGTH(info->code->header) * sizeof(lispobj));
#else
                (HEADER_LENGTH(((struct code *)info->code)->header) * sizeof(lispobj));
#endif
        else
            info->pc = 0;
    }

    return 1;
}

void
lisp_backtrace(int nframes)
{
    struct call_info info;

    call_info_from_lisp_state(&info);

    do {
        printf("<Frame 0x%08lx%s, ", (unsigned long) info.frame,
                info.interrupted ? " [interrupted]" : "");

        if (info.code != (struct code *) 0) {
            lispobj function;

            printf("CODE: 0x%08lX, ", (unsigned long) info.code | OTHER_POINTER_LOWTAG);

#ifndef LISP_FEATURE_ALPHA
            function = info.code->entry_points;
#else
            function = ((struct code *)info.code)->entry_points;
#endif
            while (function != NIL) {
                struct simple_fun *header;
                lispobj name;

                header = (struct simple_fun *) native_pointer(function);
                name = header->name;

                if (lowtag_of(name) == OTHER_POINTER_LOWTAG) {
                    lispobj *object;

                    object = (lispobj *) native_pointer(name);

                    if (widetag_of(*object) == SYMBOL_HEADER_WIDETAG) {
                        struct symbol *symbol;

                        symbol = (struct symbol *) object;
                        object = (lispobj *) native_pointer(symbol->name);
                    }
                    if (widetag_of(*object) == SIMPLE_BASE_STRING_WIDETAG) {
                        struct vector *string;

                        string = (struct vector *) object;
                        printf("%s, ", (char *) string->data);
                    } else
                        /* FIXME: broken from (VECTOR NIL) */
                        printf("(Not simple string??\?), ");
                } else
                    printf("(Not other pointer??\?), ");


                function = header->next;
            }
        }
        else
            printf("CODE: ???, ");

        if (info.lra != NIL)
            printf("LRA: 0x%08lx, ", (unsigned long)info.lra);
        else
            printf("<no LRA>, ");

        if (info.pc)
            printf("PC: 0x%x>\n", info.pc);
        else
            printf("PC: ??\?>\n");

    } while (--nframes > 0 && previous_info(&info));
}

#else

static int
altstack_pointer_p (void *p) {
#ifndef LISP_FEATURE_WIN32
    void* stack_start = ((void *)arch_os_get_current_thread()) + dynamic_values_bytes;
    void* stack_end = stack_start + 32*SIGSTKSZ;

    return (p > stack_start && p <= stack_end);
#else
    /* Win32 doesn't do altstack */
    return 0;
#endif
}

static int
stack_pointer_p (void *p)
{
  /* we are using sizeof(long) here, because that is the right value on both
   * x86 and x86-64.  (But note that false positives would not cause much harm
   * given the heuristical nature of x86_call_context.) */
  unsigned long stack_alignment = sizeof(long);

  return (altstack_pointer_p(p)
          || (p < (void *) arch_os_get_current_thread()->control_stack_end
              && (p > (void *) &p || altstack_pointer_p(&p))
              && (((unsigned long) p) & (stack_alignment-1)) == 0));
}

static int
ra_pointer_p (void *ra)
{
  /* the check against 4096 is still a mystery to everyone interviewed about
   * it, but recent changes to sb-sprof seem to suggest that such values
   * do occur sometimes. */
  return ((unsigned long) ra) > 4096 && !stack_pointer_p (ra);
}

static int
x86_call_context (void *fp, void **ra, void **ocfp)
{
  void *c_ocfp;
  void *c_ra;
  int c_valid_p;

  if (!stack_pointer_p(fp))
    return 0;

  c_ocfp    = *((void **) fp);
  c_ra      = *((void **) fp + 1);

  c_valid_p = (c_ocfp > fp
               && stack_pointer_p(c_ocfp)
               && ra_pointer_p(c_ra));

  if (c_valid_p)
    *ra = c_ra, *ocfp = c_ocfp;
  else
    return 0;

  return 1;
}

struct compiled_debug_fun *
debug_function_from_pc (struct code* code, void *pc)
{
  unsigned long code_header_len = sizeof(lispobj) * HeaderValue(code->header);
  unsigned long offset
    = (unsigned long) pc - (unsigned long) code - code_header_len;
  struct compiled_debug_fun *df;
  struct compiled_debug_info *di;
  struct vector *v;
  int i, len;

  if (lowtag_of(code->debug_info) != INSTANCE_POINTER_LOWTAG)
    return 0;

  di = (struct compiled_debug_info *) native_pointer(code->debug_info);
  v = (struct vector *) native_pointer(di->fun_map);
  len = fixnum_value(v->length);
  df = (struct compiled_debug_fun *) native_pointer(v->data[0]);

  if (len == 1)
    return df;

  for (i = 1;; i += 2) {
    unsigned next_pc;

    if (i == len)
      return ((struct compiled_debug_fun *) native_pointer(v->data[i - 1]));

    if (offset >= (unsigned long)fixnum_value(df->elsewhere_pc)) {
      struct compiled_debug_fun *p
        = ((struct compiled_debug_fun *) native_pointer(v->data[i + 1]));
      next_pc = fixnum_value(p->elsewhere_pc);
    } else
      next_pc = fixnum_value(v->data[i]);

    if (offset < next_pc)
      return ((struct compiled_debug_fun *) native_pointer(v->data[i - 1]));
  }

  return NULL;
}

static void
sbcl_putwc(wchar_t c, FILE *file)
{
#ifdef LISP_FEATURE_OS_PROVIDES_PUTWC
    putwc(c, file);
#else
    if (c < 256) {
        fputc(c, file);
    } else {
        fputc('?', file);
    }
#endif
}

static void
print_string (lispobj *object)
{
  int tag = widetag_of(*object);
  struct vector *vector = (struct vector *) object;

#define doit(TYPE)                              \
  do {                                          \
    int i;                                      \
    int n = fixnum_value(vector->length);       \
    TYPE *data = (TYPE *) vector->data;         \
    for (i = 0; i < n; i++) {                   \
      wchar_t c = (wchar_t) data[i];            \
      if (c == '\\' || c == '"')                \
        putchar('\\');                          \
      sbcl_putwc(c, stdout);                    \
    }                                           \
  } while (0)

  switch (tag) {
  case SIMPLE_BASE_STRING_WIDETAG:
    doit(unsigned char);
    break;
#ifdef SIMPLE_CHARACTER_STRING_WIDETAG
  case SIMPLE_CHARACTER_STRING_WIDETAG:
    doit(unsigned int);
    break;
#endif
  default:
    printf("<??? type %d>", tag);
  }
#undef doit
}

static void
print_entry_name (lispobj name)
{
  if (lowtag_of (name) == LIST_POINTER_LOWTAG) {
    putchar('(');
    while (name != NIL) {
      struct cons *cons = (struct cons *) native_pointer(name);
      print_entry_name(cons->car);
      name = cons->cdr;
      if (name != NIL)
        putchar(' ');
    }
    putchar(')');
  } else if (lowtag_of(name) == OTHER_POINTER_LOWTAG) {
    lispobj *object = (lispobj *) native_pointer(name);
    if (widetag_of(*object) == SYMBOL_HEADER_WIDETAG) {
      struct symbol *symbol = (struct symbol *) object;
      if (symbol->package != NIL) {
        struct package *pkg
          = (struct package *) native_pointer(symbol->package);
        lispobj pkg_name = pkg->_name;
        print_string(native_pointer(pkg_name));
        fputs("::", stdout);
      }
      print_string(native_pointer(symbol->name));
    } else if (widetag_of(*object) == SIMPLE_BASE_STRING_WIDETAG) {
         putchar('"');
         print_string(object);
         putchar('"');
#ifdef SIMPLE_CHARACTER_STRING_WIDETAG
      } else if (widetag_of(*object) == SIMPLE_CHARACTER_STRING_WIDETAG) {
         putchar('"');
         print_string(object);
         putchar('"');
#endif
    } else {
      printf("<??? type %d>", (int) widetag_of(*object));
    }
  } else {
    printf("<??? lowtag %d>", (int) lowtag_of(name));
  }
}

static void
print_entry_points (struct code *code)
{
  lispobj function = code->entry_points;

  while (function != NIL) {
    struct simple_fun *header = (struct simple_fun *) native_pointer(function);
    print_entry_name(header->name);

    function = header->next;
    if (function != NIL)
      printf (", ");
  }
}

void
describe_thread_state(void)
{
    sigset_t mask;
    struct thread *thread = arch_os_get_current_thread();
    struct interrupt_data *data = thread->interrupt_data;
#ifndef LISP_FEATURE_WIN32
    get_current_sigmask(&mask);
    printf("Signal mask:\n");
    printf(" SIGALRM = %d\n", sigismember(&mask, SIGALRM));
    printf(" SIGINT = %d\n", sigismember(&mask, SIGINT));
    printf(" SIGPROF = %d\n", sigismember(&mask, SIGPROF));
#ifdef SIG_STOP_FOR_GC
    printf(" SIG_STOP_FOR_GC = %d\n", sigismember(&mask, SIG_STOP_FOR_GC));
#endif
#endif
    printf("Specials:\n");
    printf(" *GC-INHIBIT* = %s\n", (SymbolValue(GC_INHIBIT, thread) == T) ? "T" : "NIL");
    printf(" *GC-PENDING* = %s\n",
           (SymbolValue(GC_PENDING, thread) == T) ?
           "T" : ((SymbolValue(GC_PENDING, thread) == NIL) ?
                  "NIL" : ":IN-PROGRESS"));
    printf(" *INTERRUPTS-ENABLED* = %s\n", (SymbolValue(INTERRUPTS_ENABLED, thread) == T) ? "T" : "NIL");
#ifdef STOP_FOR_GC_PENDING
    printf(" *STOP-FOR-GC-PENDING* = %s\n", (SymbolValue(STOP_FOR_GC_PENDING, thread) == T) ? "T" : "NIL");
#endif
    printf("Pending handler = %p\n", data->pending_handler);
}

/* This function has been split from lisp_backtrace() to enable Lisp
 * backtraces from gdb with call backtrace_from_fp(...). Useful for
 * example when debugging threading deadlocks.
 */
void
backtrace_from_fp(void *fp, int nframes)
{
  int i;

  for (i = 0; i < nframes; ++i) {
    lispobj *p;
    void *ra;
    void *next_fp;

    if (!x86_call_context(fp, &ra, &next_fp))
      break;

    printf("%4d: ", i);

    p = (lispobj *) component_ptr_from_pc((lispobj *) ra);
    if (p) {
      struct code *cp = (struct code *) p;
      struct compiled_debug_fun *df = debug_function_from_pc(cp, ra);
      if (df)
        print_entry_name(df->name);
      else
        print_entry_points(cp);
    } else {
#ifdef LISP_FEATURE_OS_PROVIDES_DLADDR
        Dl_info info;
        if (dladdr(ra, &info)) {
            printf("Foreign function %s, fp = 0x%lx, ra = 0x%lx",
                   info.dli_sname,
                   (unsigned long) next_fp,
                   (unsigned long) ra);
        } else
#endif
        printf("Foreign fp = 0x%lx, ra = 0x%lx",
               (unsigned long) next_fp,
               (unsigned long) ra);
    }

    putchar('\n');
    fp = next_fp;
  }
}

void
lisp_backtrace(int nframes)
{
  void *fp;

#if defined(LISP_FEATURE_X86)
  asm("movl %%ebp,%0" : "=g" (fp));
#elif defined (LISP_FEATURE_X86_64)
  asm("movq %%rbp,%0" : "=g" (fp));
#else
#error "How did we get here?"
#endif

  backtrace_from_fp(fp, nframes);
}

#endif
