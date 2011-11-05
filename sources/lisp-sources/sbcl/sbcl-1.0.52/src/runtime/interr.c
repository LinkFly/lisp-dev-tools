/*
 * stuff to handle internal errors
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
#include <stdarg.h>
#include <stdlib.h>

#include "sbcl.h"
#include "arch.h"
#include "signal.h"

#include "runtime.h"
#include "interr.h"
#include "print.h"
#include "lispregs.h"
#include "genesis/static-symbols.h"
#include "genesis/vector.h"
#include "thread.h"
#include "monitor.h"

/* the way that we shut down the system on a fatal error */

static void
default_lossage_handler(void)
{
    exit(1);
}
static void (*lossage_handler)(void) = default_lossage_handler;

void enable_lossage_handler(void)
{
    lossage_handler = monitor_or_something;
}
void disable_lossage_handler(void)
{
    lossage_handler = default_lossage_handler;
}

static
void print_message(char *fmt, va_list ap)
{
    fprintf(stderr, " in SBCL pid %d",getpid());
#if defined(LISP_FEATURE_SB_THREAD)
    fprintf(stderr, "(tid %lu)", (unsigned long) thread_self());
#endif
    if (fmt) {
        fprintf(stderr, ":\n");
        vfprintf(stderr, fmt, ap);
    }
    fprintf(stderr, "\n");
}

static inline void
call_lossage_handler() never_returns;

static inline void
call_lossage_handler()
{
    lossage_handler();
    fprintf(stderr, "Argh! lossage_handler() returned, total confusion..\n");
    exit(1);
}

void
lose(char *fmt, ...)
{
    va_list ap;
    /* Block signals to prevent other threads, timers and such from
     * interfering. If only all threads could be stopped somehow. */
    block_blockable_signals(0, 0);
    fprintf(stderr, "fatal error encountered");
    va_start(ap, fmt);
    print_message(fmt, ap);
    va_end(ap);
    fprintf(stderr, "\n");
    fflush(stderr);
    call_lossage_handler();
}

boolean lose_on_corruption_p = 0;

void
corruption_warning_and_maybe_lose(char *fmt, ...)
{
    va_list ap;
#ifndef LISP_FEATURE_WIN32
    sigset_t oldset;
    block_blockable_signals(0, &oldset);
#endif
    fprintf(stderr, "CORRUPTION WARNING");
    va_start(ap, fmt);
    print_message(fmt, ap);
    va_end(ap);
    fprintf(stderr, "The integrity of this image is possibly compromised.\n");
    if (lose_on_corruption_p)
        fprintf(stderr, "Exiting.\n");
    else
        fprintf(stderr, "Continuing with fingers crossed.\n");
    fflush(stderr);
    if (lose_on_corruption_p)
        call_lossage_handler();
#ifndef LISP_FEATURE_WIN32
    else
        thread_sigmask(SIG_SETMASK,&oldset,0);
#endif
}

char *internal_error_descriptions[] = {INTERNAL_ERROR_NAMES};
/* internal error handler for when the Lisp error system doesn't exist
 *
 * FIXME: Shouldn't error output go to stderr instead of stdout? (Alas,
 * this'd require changes in a number of things like brief_print(..),
 * or I'd have changed it immediately.) */
void
describe_internal_error(os_context_t *context)
{
    unsigned char *ptr = arch_internal_error_arguments(context);
    int len, scoffset, sc, offset, ch;

    len = *ptr++;
    printf("internal error #%d (%s)\n", *ptr,
           internal_error_descriptions[*ptr]);
    ptr++;
    len--;
    while (len > 0) {
        scoffset = *ptr++;
        len--;
        if (scoffset == 253) {
            scoffset = *ptr++;
            len--;
        }
        else if (scoffset == 254) {
            scoffset = ptr[0] + ptr[1]*256;
            ptr += 2;
            len -= 2;
        }
        else if (scoffset == 255) {
            scoffset = ptr[0] + (ptr[1]<<8) + (ptr[2]<<16) + (ptr[3]<<24);
            ptr += 4;
            len -= 4;
        }
        sc = scoffset & 0x1f;
        offset = scoffset >> 5;

        printf("    SC: %d, Offset: %d", sc, offset);
        switch (sc) {
        case sc_AnyReg:
        case sc_DescriptorReg:
            putchar('\t');
            brief_print(*os_context_register_addr(context, offset));
            break;

        case sc_CharacterReg:
            ch = *os_context_register_addr(context, offset);
#ifdef LISP_FEATURE_X86
            if (offset&1)
                ch = ch>>8;
            ch = ch & 0xff;
#endif
            switch (ch) {
            case '\n': printf("\t'\\n'\n"); break;
            case '\b': printf("\t'\\b'\n"); break;
            case '\t': printf("\t'\\t'\n"); break;
            case '\r': printf("\t'\\r'\n"); break;
            default:
                if (ch < 32 || ch > 127)
                    printf("\\%03o", ch);
                else
                    printf("\t'%c'\n", ch);
                break;
            }
            break;
        case sc_SapReg:
#ifdef sc_WordPointerReg
        case sc_WordPointerReg:
#endif
            printf("\t0x%08lx\n", (unsigned long) *os_context_register_addr(context, offset));
            break;
        case sc_SignedReg:
            printf("\t%ld\n", (long) *os_context_register_addr(context, offset));
            break;
        case sc_UnsignedReg:
            printf("\t%lu\n", (unsigned long) *os_context_register_addr(context, offset));
            break;
#ifdef sc_SingleFloatReg
        case sc_SingleFloatReg:
            printf("\t%g\n", *(float *)&context->sc_fpregs[offset]);
            break;
#endif
#ifdef sc_DoubleFloatReg
        case sc_DoubleFloatReg:
            printf("\t%g\n", *(double *)&context->sc_fpregs[offset]);
            break;
#endif
        default:
            printf("\t???\n");
            break;
        }
    }
}

/* utility routines used by miscellaneous pieces of code */

lispobj debug_print(lispobj string)
{
    /* This is a kludge.  It's not actually safe - in general - to use
       %primitive print on the alpha, because it skips half of the
       number stack setup that should usually be done on a function
       call, so the called routine (i.e. this one) ends up being able
       to overwrite local variables in the caller.  Rather than fix
       this everywhere that %primitive print is used (it's only a
       debugging aid anyway) we just guarantee our safety by putting
       an unused buffer on the stack before doing anything else
       here */
    char untouched[32];
    fprintf(stderr, "%s\n",
            (char *)(((struct vector *)native_pointer(string))->data));
    /* shut GCC up about not using this, because that's the point.. */
    (void)untouched;
    return NIL;
}
