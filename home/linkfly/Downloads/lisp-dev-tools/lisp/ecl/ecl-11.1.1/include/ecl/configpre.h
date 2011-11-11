/*
    config.h.in -- Template configuration file.
*/
/*
    Copyright (c) 1990, Giuseppe Attardi.
    Copyright (c) 2001, Juan Jose Garcia Ripoll.

    ECoLisp is free software; you can redistribute it and/or
    modify it under the terms of the GNU Library General Public
    License as published by the Free Software Foundation; either
    version 2 of the License, or (at your option) any later version.

    See file '../Copyright' for full details.
*/

#if defined(_MSC_VER) || defined(__MINGW32__) || __WIN32__ || __WING64__
#define ECL_MS_WINDOWS_HOST
#endif

/*
 * If ECL_API has been predefined, that means we are building the core
 * library and, under windows, we must tell the compiler to export
 * extern functions from the shared library.
 * If ECL_API is not defined, we are simply building an application that
 * uses ECL and, under windows, we must tell the compiler that certain
 * will be imported from a DLL.
 */
#if defined(ECL_MS_WINDOWS_HOST) || defined(cygwin)
# define ECL_DLLEXPORT __declspec(dllexport)
# ifdef ECL_API
#  undef \
   ECL_API /* Avoid autoconf removing this */
#  define ECL_API __declspec(dllexport)
# else
#  define ECL_API __declspec(dllimport)
# endif
#else
# define ECL_DLLEXPORT
# ifdef ECL_API
#  undef \
   ECL_API /* Avoid autoconf removing this */
# endif
# define ECL_API
#endif

/* Decimal number made with the formula yymmvv */
#define ECL_VERSION_NUMBER 110101

/*
 * FEATURES LINKED IN
 */
/* Always use CLOS							*/
#define CLOS

/* Use GNU Multiple Precision library for bignums                       */
#ifndef DPP
#include "ecl/gmp.h"
#endif

/* Userland threads?							*/
#undef ECL_THREADS
#ifdef ECL_THREADS
# if defined(ECL_MS_WINDOWS_HOST)
#  define ECL_WINDOWS_THREADS
# endif
/* # udef ECL_SEMAPHORES */
#undef ECL_RWLOCK
#endif

/* __thread thread-local variables?                                     */
#ifndef openbsd
#undef WITH___THREAD
#endif

/* Use Boehm's garbage collector					*/
#undef GBC_BOEHM
#ifdef GBC_BOEHM
# ifdef ECL_THREADS
#   define GC_THREADS		/* For >= 7.2 */
# endif
# define ECL_DYNAMIC_VV
# include "ecl/gc/gc.h"
/* GC >= 7.2 defines these macros to intercept thread functions, but
 * in doing so it breaks mingw. */
# if defined(ECL_MS_WINDOWS_HOST) && defined(_beginthreadex)
#  undef _beginthread
#  undef _endthread
#  undef _beginthreadex
#  undef _endthreadex
# endif
#endif

/* Network streams							*/
#undef TCP
#if defined(TCP) && defined(ECL_MS_WINDOWS_HOST)
# define ECL_WSOCK
#endif

/* Foreign functions interface						*/
#undef ECL_FFI

/* Support for Unicode strings */
#undef ECL_UNICODE

/* Allow STREAM operations to work on arbitrary objects			*/
#undef ECL_CLOS_STREAMS

/* Stack grows downwards						*/
#undef ECL_DOWN_STACK

/* We have libffi and can use it                                        */
#undef HAVE_LIBFFI

/* We have non-portable implementation of FFI calls			*/
/* Only used as a last resort, when libffi is missin                    */
#ifndef HAVE_LIBFFI
#undef ECL_DYNAMIC_FFI
#endif

/* We use hierarchical package names, like in Allegro CL                */
#undef ECL_RELATIVE_PACKAGE_NAMES

/* Use mprotect for fast interrupt dispatch				*/
#undef ECL_USE_MPROTECT
#if defined(ECL_MS_WINDOWS_HOST)
# define ECL_USE_GUARD_PAGE
#endif

/* Integer types                        				*/
#include <stdint.h>
#undef ecl_uint8_t
#undef ecl_int8_t
#undef ecl_uint16_t
#undef ecl_int16_t
#undef ecl_uint32_t
#undef ecl_int32_t
#undef ecl_uint64_t
#undef ecl_int64_t
#undef ecl_long_long_t
#undef ecl_ulong_long_t

/*
 * C TYPES AND SYSTEM LIMITS
 */
/*
 * The integer type
 *
 * cl_fixnum must be an integer type, large enough to hold a pointer.
 * Ideally, according to the ISOC99 standard, we should use intptr_t,
 * but the required headers are not present in all systems. Hence we
 * use autoconf to guess the following values.
 */
#define ECL_INT_BITS		32
#define ECL_LONG_BITS		64
#define FIXNUM_BITS		64
#define MOST_POSITIVE_FIXNUM	((cl_fixnum)2305843009213693951)
#define MOST_NEGATIVE_FIXNUM	((cl_fixnum)-2305843009213693952)
#define MOST_POSITIVE_FIXNUM_VAL 2305843009213693951
#define MOST_NEGATIVE_FIXNUM_VAL -2305843009213693952

typedef long int cl_fixnum;
typedef unsigned long int cl_index;
typedef unsigned long int cl_hashkey;

/*
 * The character type
 */
#ifdef ECL_UNICODE
#define	CHAR_CODE_LIMIT	1114112	/*  unicode character code limit  */
#else
#define	CHAR_CODE_LIMIT	256	/*  unicode character code limit  */
#endif

/*
 * Array limits
 */
#define	ARANKLIM	64		/*  array rank limit  		*/
#ifdef GBC_BOEHM
#define	ADIMLIM		2305843009213693951	/*  array dimension limit	*/
#define	ATOTLIM		2305843009213693951	/*  array total limit		*/
#else
#define	ADIMLIM		16*1024*1024	/*  array dimension limit	*/
#define	ATOTLIM		16*1024*1024	/*  array total limit		*/
#endif

/*
 * Function limits.
 *
 * In general, any of these limits must fit in a "signed int".
 */
/*	Maximum number of function arguments (arbitrary)		*/
#define CALL_ARGUMENTS_LIMIT 65536

/*	Maximum number of required arguments				*/
#define LAMBDA_PARAMETERS_LIMIT CALL_ARGUMENTS_LIMIT

/*	Numb. of args. which will be passed using the C stack		*/
/*	See cmplam.lsp if you change this value				*/
#define C_ARGUMENTS_LIMIT 64

/*	Maximum number of output arguments (>= C_ARGUMENTS_LIMIT)	*/
#define ECL_MULTIPLE_VALUES_LIMIT 64

/* A setjmp that does not save signals					*/
#define ecl_setjmp	_setjmp
#define ecl_longjmp	_longjmp

/*
 * Structure/Instance limits. The index to a slot must fit in the
 * "int" type. We also require ECL_SLOTS_LIMIT <= CALL_ARGUMENTS_LIMIT
 * because constructors typically require as many arguments as slots,
 * or more.
 */
#define ECL_SLOTS_LIMIT	32768

/* compiler understands long double                                     */
#undef ECL_LONG_FLOAT
/* compiler understands complex                                         */
#undef HAVE_DOUBLE_COMPLEX
#undef HAVE_FLOAT_COMPLEX

/* We can use small, two-words conses, without type information		*/
#undef ECL_SMALL_CONS

/*
 * C macros for inlining, denoting probable code paths and other stuff
 * that makes better code. Most of it is GCC specific.
 */
#if defined(__cplusplus) || (defined(__GNUC__) && !defined(__STRICT_ANSI__))
#define ECL_INLINE inline
#else
#define ECL_INLINE
#endif

#if !defined(__GNUC__)
# define ecl_likely(form) (form)
# define ecl_unlikely(form) (form)
# define ecl_attr_noreturn
#else
# if (__GNUC__ < 3)
#  define ecl_likely(form) (form)
#  define ecl_unlikely(form) (form)
# else
#  define ecl_likely(form) __builtin_expect(form,1)
#  define ecl_unlikely(form) __builtin_expect(form,0)
# endif
# if (__GNUC__ < 4)
#  define ecl_attr_noreturn
# else
#  define ecl_attr_noreturn __attribute__((noreturn))
# endif
#endif

#if defined(__SSE2__) || (defined(_M_IX86_FP) && _M_IX86_FP >= 2)
#undef ECL_SSE2
#endif

/* -CUT-: Everything below this mark will not be installed		*/
/* -------------------------------------------------------------------- *
 *	BUILD OPTIONS WHICH NEED NOT BE EXPORTED			*
 * -------------------------------------------------------------------- */
/*
 * FEATURES LINKED IN:
 */

/* CLX									*/
#undef CLX
/* Locatives								*/
#undef LOCATIVE
/* Use old MIT LOOP macro system					*/
#undef ECL_OLD_LOOP

/* Define this if you want a runtime version only without compiler	*/
#undef RUNTIME
/* Profile tool								*/
#undef PROFILE
/* Program Development Environment					*/
#undef PDE

/* Allow loading dynamically linked code				*/
#undef ENABLE_DLOPEN

/* Undefine this if you do not want ECL to check for circular lists	*/
#define ECL_SAFE

/* Use CMU Common-Lisp's FORMAT routine					*/
#undef ECL_CMU_FORMAT

/* Bytecodes and arguments are 8 and 16 bits large, respectively	*/
#undef ECL_SMALL_BYTECODES

/* Assembler implementation of APPLY and friends			*/
#undef ECL_ASM_APPLY

/* Activate Boehm-Weiser incremental garbage collector			*/
#undef GBC_BOEHM_GENGC

/* Activate Boehm-Weiser precise garbage collector			*/
#undef GBC_BOEHM_PRECISE

/*
 * SYSTEM FEATURES:
 */

/* Argument list can be access as an array				*/
#undef ECL_USE_VARARG_AS_POINTER
/* Most significant byte first						*/
#undef WORDS_BIGENDIAN
/* Has <sys/resource.h>							*/
#undef HAVE_SYS_RESOURCE_H
#undef HAVE_ULIMIT_H
/* High precision timer							*/
#undef HAVE_NANOSLEEP
/* Float version if isnan()						*/
#undef HAVE_ISNANF
/* float.h for epsilons, maximum real numbers, etc			*/
#undef HAVE_FLOAT_H
/* select()								*/
#undef HAVE_SELECT
#undef HAVE_SYS_SELECT_H
#undef HAVE_SYS_IOCTL_H
/* putenv() or setenv()							*/
#undef HAVE_SETENV
#undef HAVE_PUTENV
/* times() and sys/times.h						*/
#undef HAVE_TIMES
/* gettimeofday() and sys/time.h					*/
#undef HAVE_GETTIMEOFDAY
/* getrusage() and sys/resource.h					*/
#undef HAVE_GETRUSAGE
/* user home directory, user name, etc...				*/
#undef HAVE_PW_H
/* symbolic links and checking their existence				*/
#undef HAVE_LSTAT
/* safe creation of temporary files					*/
#undef HAVE_MKSTEMP
/* timer for userland threads						*/
#undef HAVE_ALARM
/* filesytem								*/
#undef HAVE_DIRENT_H
/* dynamic linking of libraries						*/
#undef HAVE_DLFCN_H
#undef HAVE_LINK_H
#undef HAVE_MACH_O_DYLD_H
/* POSIX signals							*/
#undef HAVE_SIGPROCMASK
/* isatty() checks whether a file is connected to a			*/
#undef HAVE_ISATTY
/* can manipulate floating point environment				*/
#undef HAVE_FENV_H
/* can activate individual traps in floating point environment		*/
/* this flag has to be deactivated for the Itanium architecture, where  */
/* the GNU libc functions are broken                                    */
#if !defined(__ia64__) && !defined(PPC)
#undef HAVE_FEENABLEEXCEPT
#endif
/* do we want to deactivate all support for floating point exceptions   */
#undef ECL_AVOID_FPE_H
/* do we want to have signed zeros					*/
#undef ECL_SIGNED_ZERO
/* do we want NaNs and Infs						*/
#undef ECL_IEEE_FP
/* has support for large files						*/
#undef HAVE_FSEEKO
/* the tzset() function gets the current time zone			*/
#undef HAVE_TZSET
/* several floating point functions (ISO C99)				*/
#if 0
#undef HAVE_EXPF
#undef HAVE_LOGF
#undef HAVE_SQRTF
#undef HAVE_COSF
#undef HAVE_SINF
#undef HAVE_TANF
#undef HAVE_SINHF
#undef HAVE_COSHF
#undef HAVE_TANHF
#endif
#undef HAVE_FLOORF
#undef HAVE_CEILF
#undef HAVE_FABSF
#undef HAVE_FREXPF
#undef HAVE_LDEXPF
#undef HAVE_LOG1P
#undef HAVE_LOG1PF
#undef HAVE_LOG1PL
#undef HAVE_COPYSIGNF
#undef HAVE_COPYSIGN
#undef HAVE_COPYSIGNL
/* whether we have sched_yield() that gives priority to other threads	*/
#undef HAVE_SCHED_YIELD
/* whether we semaphore.h                                               */
#undef HAVE_SEMAPHORE_H
/* whether we have a working sem_init()                                 */
#undef HAVE_SEM_INIT
/* whether we have read/write locks                                     */
#undef HAVE_POSIX_RWLOCK
/* uname() for system identification					*/
#undef HAVE_UNAME
#undef HAVE_UNISTD_H
#undef HAVE_SYS_WAIT_H
/* size of long long            					*/
#undef ECL_LONG_LONG_BITS
/* existence of char **environ         					*/
#undef HAVE_ENVIRON
/* existence of pointer -> function name functions                      */
#undef HAVE_DLADDR
#undef HAVE_BACKTRACE
#undef HAVE_BACKTRACE_SYMBOLS
#undef HAVE___BUILTIN_RETURN_ADDRESS

/*
 * we do not manage to get proper signal handling of floating point
 * arithmetics in the Alpha chips.
 */
#if defined(__alpha__)
# ifdef HAVE_FENV_H
#  undef HAVE_FENV_H
# endif
# ifdef HAVE_FEENABLEEXCEPT
#  undef HAVE_FEENABLEEXCEPT
# endif
#endif

/* what characters are used to mark beginning of new line		*/
#undef ECL_NEWLINE_IS_CRLF
#undef ECL_NEWLINE_IS_LFCR

/*
 * PARAMETERS:
 */

/*
 * Memory limits for the old garbage collector.
 */
#define	LISP_PAGESIZE	2048	/* Page size in bytes			*/
#define MAXPAGE	65536		/* Maximum Memory Size			*/

/* We allocate a number of strings in a pool which is used to speed up reading */
#define ECL_MAX_STRING_POOL_SIZE	10
#define ECL_BUFFER_STRING_SIZE		4192

/*
 * Macros that depend on these system features.
 */
#if defined(sparc) || defined(i386) || defined(mips)
#  define	stack_align(n)	(((n) + 0x7) & ~0x7)
#else
#  define	stack_align(n)	(((n) + 03) & ~03)
#endif

#undef FILE_CNT
#if 1 == 1
#  define FILE_CNT(fp)	((fp)->_IO_read_end - (fp)->_IO_read_ptr)
#endif
#if 1 == 2
#  define FILE_CNT(fp)	((fp)->_r)
#endif
#if 1 == 3
#  define FILE_CNT(fp)	((fp)->_cnt)
#endif

#if defined(cygwin) || defined(ECL_MS_WINDOWS_HOST)
#  define IS_DIR_SEPARATOR(x) ((x=='/')||(x=='\\'))
#  define DIR_SEPARATOR		'/'
#  define PATH_SEPARATOR	';'
#else
#  define IS_DIR_SEPARATOR(x) (x=='/')
#  define DIR_SEPARATOR	'/'
#  define PATH_SEPARATOR	':'
#endif

#define ECL_ARCHITECTURE "X86_64"

#ifdef ECL_AVOID_FPE_H
# define ecl_detect_fpe()
#else
# include "arch/fpe_x86.c"
#endif

#ifdef ECL_INCLUDE_MATH_H
# include <math.h>
# ifdef _MSC_VER
#  undef complex
#  define signbit(x) (copysign(1.0,(x)))
# endif
# ifndef isfinite
#  ifdef __sun__
#   ifndef ECL_LONG_FLOAT
#    include <ieeefp.h>
#    define isfinite(x) finite(x)
#   else
#    error "Function isfinite() is missing"
#   endif
#  else
#   define isfinite(x) finite(x)
#  endif
# endif
# ifndef signbit
#  ifndef ECL_SIGNED_ZERO
#   define signbit(x) ((x) < 0)
#  else
#   ifdef HAVE_COPYSIGN
#    define signbit(x) (copysign(1.0,(x)) < 0)
#   else 
     /* Fall back to no signed zero */
#    undef \
     ECL_SIGNED_ZERO
#    define signbit(x) ((x) < 0)
#   endif
#  endif
# endif
/*
 * GCC fails to compile the following code
 * if (f == 0.0) { if (signbit(f)) ... }
 */
# if defined(__sun__) && defined(__GNUC__)
#  undef \
   signbit /* Avoid autoconf removing this */
#  define signbit(x) (copysign(1.0,(x)) < 0)
# endif
#endif

#if defined(HAVE_LIBFFI) && defined(ECL_INCLUDE_FFI_H)
#include ""
#endif
