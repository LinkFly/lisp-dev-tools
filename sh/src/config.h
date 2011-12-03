/* src/config.h.  Generated from config.in by configure.  */
/* src/config.in.  Generated from configure.in by autoheader.  */

/* GNU Emacs site configuration template file.

Copyright (C) 1988, 1993-1994, 1999-2002, 2004-2011
  Free Software Foundation, Inc.

This file is part of GNU Emacs.

GNU Emacs is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

GNU Emacs is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.  */


/* No code in Emacs #includes config.h twice, but some bits of code
   intended to work with other packages as well (like gmalloc.c)
   think they can include it as many times as they like.  */
#ifndef EMACS_CONFIG_H
#define EMACS_CONFIG_H


/* Define if building universal (internal helper macro) */
/* #undef AC_APPLE_UNIVERSAL_BUILD */

/* Define to the number of bits in type 'ptrdiff_t'. */
/* #undef BITSIZEOF_PTRDIFF_T */

/* Define to the number of bits in type 'sig_atomic_t'. */
/* #undef BITSIZEOF_SIG_ATOMIC_T */

/* Define to the number of bits in type 'size_t'. */
/* #undef BITSIZEOF_SIZE_T */

/* Define to the number of bits in type 'wchar_t'. */
/* #undef BITSIZEOF_WCHAR_T */

/* Define to the number of bits in type 'wint_t'. */
/* #undef BITSIZEOF_WINT_T */

/* Define if Emacs cannot be dumped on your system. */
/* #undef CANNOT_DUMP */

/* Define to one of `_getb67', `GETB67', `getb67' for Cray-2 and Cray-YMP
   systems. This function is required for `alloca.c' support on those systems.
   */
/* #undef CRAY_STACKSEG_END */

/* Define to 1 if using `alloca.c'. */
/* #undef C_ALLOCA */

/* Define to 1 for DGUX with <sys/dg_sys_info.h>. */
/* #undef DGUX */

/* Define to 1 if you are using the GNU C Library. */
#define DOUG_LEA_MALLOC 1

/* Define to the canonical Emacs configuration name. */
#define EMACS_CONFIGURATION "x86_64-unknown-linux-gnu"

/* Define to the options passed to configure. */
#define EMACS_CONFIG_OPTIONS " '--prefix' '/home/linkfly/tmp/tmp-emacs' 'CFLAGS=-I/home/linkfly/Downloads/ncurses-bin/include' 'LDFLAGS=-L/home/linkfly/Downloads/ncurses-bin/lib'"

/* Enable expensive run-time checking of data types? */
/* #undef ENABLE_CHECKING */

/* Define this to check for errors in cons list. */
/* #undef GC_CHECK_CONS_LIST */

/* Define this temporarily to hunt a bug. If defined, the size of strings is
   redundantly recorded in sdata structures so that it can be compared to the
   sizes recorded in Lisp strings. */
/* #undef GC_CHECK_STRING_BYTES */

/* Define this to check the string free list. */
/* #undef GC_CHECK_STRING_FREE_LIST */

/* Define this to check for short string overrun. */
/* #undef GC_CHECK_STRING_OVERRUN */

/* Define to 1 if the `getpgrp' function requires zero arguments. */
#define GETPGRP_VOID 1

/* Define to 1 if gettimeofday accepts only one argument. */
/* #undef GETTIMEOFDAY_ONE_ARGUMENT */

/* Define to make the limit macros in <stdint.h> visible. */
#define GL_TRIGGER_STDC_LIMIT_MACROS 1

/* Define to 1 if you want to use the GNU memory allocator. */
#define GNU_MALLOC 1

/* Define to 1 if the file /usr/lpp/X11/bin/smt.exp exists. */
/* #undef HAVE_AIX_SMT_EXP */

/* Define to 1 if you have the `alarm' function. */
#define HAVE_ALARM 1

/* Define to 1 if you have 'alloca' after including <alloca.h>, a header that
   may be supplied by this distribution. */
#define HAVE_ALLOCA 1

/* Define to 1 if you have <alloca.h> and it should be used (not on Ultrix).
   */
#define HAVE_ALLOCA_H 1

/* Define to 1 if ALSA is available. */
#define HAVE_ALSA 1

/* Define to 1 if GCC-style __attribute__ ((__aligned__ (expr))) works. */
#define HAVE_ATTRIBUTE_ALIGNED 1

/* Define to 1 if strtold conforms to C99. */
#define HAVE_C99_STRTOLD 1

/* Define to 1 if you have the `cbrt' function. */
#define HAVE_CBRT 1

/* Define to 1 if you have the `cfmakeraw' function. */
#define HAVE_CFMAKERAW 1

/* Define to 1 if you have the `cfsetspeed' function. */
#define HAVE_CFSETSPEED 1

/* Define to 1 if you have the `closedir' function. */
#define HAVE_CLOSEDIR 1

/* Define to 1 if you have the <coff.h> header file. */
/* #undef HAVE_COFF_H */

/* Define to 1 if you have the <com_err.h> header file. */
/* #undef HAVE_COM_ERR_H */

/* Define to 1 if you have the `copysign' function. */
#define HAVE_COPYSIGN 1

/* Define to 1 if using D-Bus. */
/* #undef HAVE_DBUS */

/* Define to 1 if you have the `dbus_watch_get_unix_fd' function. */
/* #undef HAVE_DBUS_WATCH_GET_UNIX_FD */

/* Define to 1 if you have the declaration of `getenv', and to 0 if you don't.
   */
#define HAVE_DECL_GETENV 1

/* Define to 1 if you have the declaration of `localtime_r', and to 0 if you
   don't. */
#define HAVE_DECL_LOCALTIME_R 0

/* Define to 1 if you have the declaration of `strmode', and to 0 if you
   don't. */
#define HAVE_DECL_STRMODE 0

/* Define to 1 if you have the declaration of `strtoimax', and to 0 if you
   don't. */
#define HAVE_DECL_STRTOIMAX 1

/* Define to 1 if you have the declaration of `strtoll', and to 0 if you
   don't. */
/* #undef HAVE_DECL_STRTOLL */

/* Define to 1 if you have the declaration of `strtoull', and to 0 if you
   don't. */
/* #undef HAVE_DECL_STRTOULL */

/* Define to 1 if you have the declaration of `strtoumax', and to 0 if you
   don't. */
#define HAVE_DECL_STRTOUMAX 1

/* Define to 1 if you have the declaration of `sys_siglist', and to 0 if you
   don't. */
#define HAVE_DECL_SYS_SIGLIST 0

/* Define to 1 if you have the declaration of `tzname', and to 0 if you don't.
   */
/* #undef HAVE_DECL_TZNAME */

/* Define to 1 if you have the declaration of `__sys_siglist', and to 0 if you
   don't. */
#define HAVE_DECL___SYS_SIGLIST 0

/* Define to 1 if you have the <des.h> header file. */
/* #undef HAVE_DES_H */

/* Define to 1 if dynamic ptys are supported. */
#define HAVE_DEV_PTMX 1

/* Define to 1 if you have the `difftime' function. */
#define HAVE_DIFFTIME 1

/* Define to 1 if you have the <dirent.h> header file. */
#define HAVE_DIRENT_H 1

/* Define to 1 if you have the 'dup2' function. */
#define HAVE_DUP2 1

/* Define to 1 if you have the `euidaccess' function. */
#define HAVE_EUIDACCESS 1

/* Define to 1 if you have the <fcntl.h> header file. */
#define HAVE_FCNTL_H 1

/* Define to 1 if you have the `fmod' function. */
#define HAVE_FMOD 1

/* Define to 1 if you have the `fork' function. */
#define HAVE_FORK 1

/* Define to 1 if you have the `fpathconf' function. */
#define HAVE_FPATHCONF 1

/* Define to 1 if you have the `freeifaddrs' function. */
#define HAVE_FREEIFADDRS 1

/* Define to 1 if using the freetype and fontconfig libraries. */
#define HAVE_FREETYPE 1

/* Define to 1 if you have the `frexp' function. */
#define HAVE_FREXP 1

/* Define to 1 if fseeko (and presumably ftello) exists and is declared. */
#define HAVE_FSEEKO 1

/* Define to 1 if you have the `fsync' function. */
#define HAVE_FSYNC 1

/* Define to 1 if you have the `ftime' function. */
#define HAVE_FTIME 1

/* Define to 1 if you have the `gai_strerror' function. */
#define HAVE_GAI_STRERROR 1

/* Define to 1 if using GConf. */
/* #undef HAVE_GCONF */

/* Define to 1 if you have the `getaddrinfo' function. */
#define HAVE_GETADDRINFO 1

/* Define to 1 if you have the `getcwd' function. */
#define HAVE_GETCWD 1

/* Define to 1 if you have the `getdelim' function. */
#define HAVE_GETDELIM 1

/* Define to 1 if you have the `getdomainname' function. */
#define HAVE_GETDOMAINNAME 1

/* Define to 1 if you have the `gethostname' function. */
#define HAVE_GETHOSTNAME 1

/* Define to 1 if you have the `getifaddrs' function. */
#define HAVE_GETIFADDRS 1

/* Define to 1 if you have the `getline' function. */
#define HAVE_GETLINE 1

/* Define to 1 if you have the <getopt.h> header file. */
#define HAVE_GETOPT_H 1

/* Define to 1 if you have the `getopt_long_only' function. */
#define HAVE_GETOPT_LONG_ONLY 1

/* Define to 1 if you have the `getpagesize' function. */
#define HAVE_GETPAGESIZE 1

/* Define to 1 if you have the `getpeername' function. */
#define HAVE_GETPEERNAME 1

/* Define to 1 if you have the `getpt' function. */
#define HAVE_GETPT 1

/* Define to 1 if you have the `getrlimit' function. */
#define HAVE_GETRLIMIT 1

/* Define to 1 if you have the `getrusage' function. */
#define HAVE_GETRUSAGE 1

/* Define to 1 if you have the `getsockname' function. */
#define HAVE_GETSOCKNAME 1

/* Define to 1 if you have the `getsockopt' function. */
#define HAVE_GETSOCKOPT 1

/* Define to 1 if you have the `gettimeofday' function. */
#define HAVE_GETTIMEOFDAY 1

/* Define to 1 if you have the `getwd' function. */
#define HAVE_GETWD 1

/* Define to 1 if you have the `get_current_dir_name' function. */
#define HAVE_GET_CURRENT_DIR_NAME 1

/* Define to 1 if you have a gif (or ungif) library. */
#define HAVE_GIF 1

/* Define if using GnuTLS. */
#define HAVE_GNUTLS 1

/* Define if using GnuTLS certificate verification callbacks. */
/* #undef HAVE_GNUTLS_CALLBACK_CERTIFICATE_VERIFY */

/* Define to 1 if you have the `gnutls_certificate_set_verify_function'
   function. */
/* #undef HAVE_GNUTLS_CERTIFICATE_SET_VERIFY_FUNCTION */

/* Define to 1 if you have the gpm library (-lgpm). */
/* #undef HAVE_GPM */

/* Define to 1 if you have the `grantpt' function. */
#define HAVE_GRANTPT 1

/* Define to 1 if using GSettings. */
#define HAVE_GSETTINGS 1

/* Define to 1 if using GTK 3 or later. */
/* #undef HAVE_GTK3 */

/* Define to 1 if you have the `gtk_adjustment_get_page_size' function. */
#define HAVE_GTK_ADJUSTMENT_GET_PAGE_SIZE 1

/* Define to 1 if you have the `gtk_dialog_get_action_area' function. */
#define HAVE_GTK_DIALOG_GET_ACTION_AREA 1

/* Define to 1 if you have the `gtk_file_selection_new' function. */
#define HAVE_GTK_FILE_SELECTION_NEW 1

/* Define to 1 if you have the `gtk_main' function. */
#define HAVE_GTK_MAIN 1

/* Define to 1 if you have the `gtk_orientable_set_orientation' function. */
#define HAVE_GTK_ORIENTABLE_SET_ORIENTATION 1

/* Define to 1 if you have the `gtk_widget_get_mapped' function. */
#define HAVE_GTK_WIDGET_GET_MAPPED 1

/* Define to 1 if you have the `gtk_widget_get_sensitive' function. */
#define HAVE_GTK_WIDGET_GET_SENSITIVE 1

/* Define to 1 if you have the `gtk_widget_get_window' function. */
#define HAVE_GTK_WIDGET_GET_WINDOW 1

/* Define to 1 if you have the `gtk_widget_set_has_window' function. */
#define HAVE_GTK_WIDGET_SET_HAS_WINDOW 1

/* Define to 1 if you have the `g_type_init' function. */
#define HAVE_G_TYPE_INIT 1

/* Define to 1 if netdb.h declares h_errno. */
#define HAVE_H_ERRNO 1

/* Define to 1 if you have the <ifaddrs.h> header file. */
#define HAVE_IFADDRS_H 1

/* Define to 1 if using imagemagick. */
/* #undef HAVE_IMAGEMAGICK */

/* Define to 1 if you have inet sockets. */
#define HAVE_INET_SOCKETS 1

/* Define to 1 if you have the <inttypes.h> header file. */
#define HAVE_INTTYPES_H 1

/* Define to 1 if you have the jpeg library (-ljpeg). */
#define HAVE_JPEG 1

/* Define to 1 if you have the <kerberosIV/des.h> header file. */
/* #undef HAVE_KERBEROSIV_DES_H */

/* Define to 1 if you have the <kerberosIV/krb.h> header file. */
/* #undef HAVE_KERBEROSIV_KRB_H */

/* Define to 1 if you have the <kerberos/des.h> header file. */
/* #undef HAVE_KERBEROS_DES_H */

/* Define to 1 if you have the <kerberos/krb.h> header file. */
/* #undef HAVE_KERBEROS_KRB_H */

/* Define to 1 if `e_text' is a member of `krb5_error'. */
/* #undef HAVE_KRB5_ERROR_E_TEXT */

/* Define to 1 if `text' is a member of `krb5_error'. */
/* #undef HAVE_KRB5_ERROR_TEXT */

/* Define to 1 if you have the <krb5.h> header file. */
/* #undef HAVE_KRB5_H */

/* Define to 1 if you have the <krb.h> header file. */
/* #undef HAVE_KRB_H */

/* Define if you have <langinfo.h> and nl_langinfo(CODESET). */
#define HAVE_LANGINFO_CODESET 1

/* Define to 1 if you have the `com_err' library (-lcom_err). */
/* #undef HAVE_LIBCOM_ERR */

/* Define to 1 if you have the `crypto' library (-lcrypto). */
/* #undef HAVE_LIBCRYPTO */

/* Define to 1 if you have the `des' library (-ldes). */
/* #undef HAVE_LIBDES */

/* Define to 1 if you have the `des425' library (-ldes425). */
/* #undef HAVE_LIBDES425 */

/* Define to 1 if you have the `dgc' library (-ldgc). */
/* #undef HAVE_LIBDGC */

/* Define to 1 if you have the `dnet' library (-ldnet). */
/* #undef HAVE_LIBDNET */

/* Define to 1 if you have the hesiod library (-lhesiod). */
/* #undef HAVE_LIBHESIOD */

/* Define to 1 if you have the `k5crypto' library (-lk5crypto). */
/* #undef HAVE_LIBK5CRYPTO */

/* Define to 1 if you have the `krb' library (-lkrb). */
/* #undef HAVE_LIBKRB */

/* Define to 1 if you have the `krb4' library (-lkrb4). */
/* #undef HAVE_LIBKRB4 */

/* Define to 1 if you have the `krb5' library (-lkrb5). */
/* #undef HAVE_LIBKRB5 */

/* Define to 1 if you have the `kstat' library (-lkstat). */
/* #undef HAVE_LIBKSTAT */

/* Define to 1 if you have the `lockfile' library (-llockfile). */
/* #undef HAVE_LIBLOCKFILE */

/* Define to 1 if you have the `m' library (-lm). */
#define HAVE_LIBM 1

/* Define to 1 if you have the `mail' library (-lmail). */
/* #undef HAVE_LIBMAIL */

/* Define to 1 if you have the `ncurses' library (-lncurses). */
#define HAVE_LIBNCURSES 1

/* Define to 1 if using libotf. */
/* #undef HAVE_LIBOTF */

/* Define to 1 if you have the `perfstat' library (-lperfstat). */
/* #undef HAVE_LIBPERFSTAT */

/* Define to 1 if you have the <libpng/png.h> header file. */
#define HAVE_LIBPNG_PNG_H 1

/* Define to 1 if you have the `pthreads' library (-lpthreads). */
/* #undef HAVE_LIBPTHREADS */

/* Define to 1 if you have the resolv library (-lresolv). */
/* #undef HAVE_LIBRESOLV */

/* Define to 1 if using SELinux. */
/* #undef HAVE_LIBSELINUX */

/* Define to 1 if you have the `Xext' library (-lXext). */
/* #undef HAVE_LIBXEXT */

/* Define to 1 if you have the libxml library (-lxml2). */
/* #undef HAVE_LIBXML2 */

/* Define to 1 if you have the `Xmu' library (-lXmu). */
/* #undef HAVE_LIBXMU */

/* Define to 1 if you have the <linux/version.h> header file. */
#define HAVE_LINUX_VERSION_H 1

/* Define to 1 if you have the <locale.h> header file. */
#define HAVE_LOCALE_H 1

/* Define to 1 if you have the `localtime_r' function. */
#define HAVE_LOCALTIME_R 1

/* Define to 1 if you have the `logb' function. */
#define HAVE_LOGB 1

/* Define to 1 if you support file names longer than 14 characters. */
#define HAVE_LONG_FILE_NAMES 1

/* Define to 1 if the system has the type `long long int'. */
#define HAVE_LONG_LONG_INT 1

/* Define to 1 if you have the `lrand48' function. */
#define HAVE_LRAND48 1

/* Define to 1 if you have the `lstat' function. */
#define HAVE_LSTAT 1

/* Define to 1 if using libm17n-flt. */
/* #undef HAVE_M17N_FLT */

/* Define to 1 if you have the <machine/soundcard.h> header file. */
/* #undef HAVE_MACHINE_SOUNDCARD_H */

/* Define to 1 if you have the <mach/mach.h> header file. */
/* #undef HAVE_MACH_MACH_H */

/* Define to 1 if you have the `MagickExportImagePixels' function. */
/* #undef HAVE_MAGICKEXPORTIMAGEPIXELS */

/* Define to 1 if you have the <maillock.h> header file. */
/* #undef HAVE_MAILLOCK_H */

/* Define to 1 if you have the <malloc/malloc.h> header file. */
/* #undef HAVE_MALLOC_MALLOC_H */

/* Define to 1 if you have the `mblen' function. */
#define HAVE_MBLEN 1

/* Define to 1 if you have the `mbrlen' function. */
#define HAVE_MBRLEN 1

/* Define to 1 if you have the `mbsinit' function. */
#define HAVE_MBSINIT 1

/* Define to 1 if <wchar.h> declares mbstate_t. */
#define HAVE_MBSTATE_T 1

/* Define to 1 if you have the <memory.h> header file. */
#define HAVE_MEMORY_H 1

/* Define to 1 if you have the `mempcpy' function. */
#define HAVE_MEMPCPY 1

/* Define to 1 if you have mouse menus. (This is automatic if you use X, but
   the option to specify it remains.) It is also defined with other window
   systems that support xmenu.c. */
#define HAVE_MENUS 1

/* Define to 1 if you have the `mkdir' function. */
#define HAVE_MKDIR 1

/* Define to 1 if you have the `mkstemp' function. */
#define HAVE_MKSTEMP 1

/* Define to 1 if you have a working `mmap' system call. */
#define HAVE_MMAP 1

/* Define if you have mouse support. */
#define HAVE_MOUSE 1

/* Define to 1 if you have the `mremap' function. */
#define HAVE_MREMAP 1

/* Define to 1 if you have the <net/if_dl.h> header file. */
/* #undef HAVE_NET_IF_DL_H */

/* Define to 1 if you have the <net/if.h> header file. */
#define HAVE_NET_IF_H 1

/* Define to 1 if you have the <nlist.h> header file. */
/* #undef HAVE_NLIST_H */

/* Define to 1 if you are using the NeXTstep API, either GNUstep or Cocoa on
   Mac OS X. */
/* #undef HAVE_NS */

/* Define to 1 if libotf has OTF_get_variation_glyphs. */
/* #undef HAVE_OTF_GET_VARIATION_GLYPHS */

/* Define to 1 if personality LINUX32 can be set. */
#define HAVE_PERSONALITY_LINUX32 1

/* Define to 1 if you have the png library (-lpng). */
#define HAVE_PNG 1

/* Define to 1 if you have the <png.h> header file. */
#define HAVE_PNG_H 1

/* Define to 1 if you have the `posix_memalign' function. */
#define HAVE_POSIX_MEMALIGN 1

/* Define to 1 if you have the `pstat_getdynamic' function. */
/* #undef HAVE_PSTAT_GETDYNAMIC */

/* Define to 1 if you have pthread (-lpthread). */
#define HAVE_PTHREAD 1

/* Define to 1 if you have the <pthread.h> header file. */
#define HAVE_PTHREAD_H 1

/* Define to 1 if the pthread_sigmask function can be used (despite bugs). */
#define HAVE_PTHREAD_SIGMASK 1

/* Define to 1 if you have the <pty.h> header file. */
#define HAVE_PTY_H 1

/* Define to 1 if you have the <pwd.h> header file. */
#define HAVE_PWD_H 1

/* Define to 1 if you have the `random' function. */
#define HAVE_RANDOM 1

/* Define to 1 if you have the `readlink' function. */
#define HAVE_READLINK 1

/* Define to 1 if you have the `readlinkat' function. */
#define HAVE_READLINKAT 1

/* Define to 1 if you have the `recvfrom' function. */
#define HAVE_RECVFROM 1

/* Define to 1 if you have the `rename' function. */
#define HAVE_RENAME 1

/* Define to 1 if res_init is available. */
#define HAVE_RES_INIT 1

/* Define to 1 if you have the `rint' function. */
#define HAVE_RINT 1

/* Define to 1 if you have the `rmdir' function. */
#define HAVE_RMDIR 1

/* Define to 1 if using librsvg. */
/* #undef HAVE_RSVG */

/* Define to 1 if you have the `select' function. */
#define HAVE_SELECT 1

/* Define to 1 if you have the `sendto' function. */
#define HAVE_SENDTO 1

/* Define to 1 if you have the `setitimer' function. */
#define HAVE_SETITIMER 1

/* Define to 1 if you have the `setlocale' function. */
#define HAVE_SETLOCALE 1

/* Define to 1 if you have the `setpgid' function. */
#define HAVE_SETPGID 1

/* Define to 1 if you have the `setrlimit' function. */
#define HAVE_SETRLIMIT 1

/* Define to 1 if you have the `setsid' function. */
#define HAVE_SETSID 1

/* Define to 1 if you have the `setsockopt' function. */
#define HAVE_SETSOCKOPT 1

/* Define to 1 if you have the `shutdown' function. */
#define HAVE_SHUTDOWN 1

/* Define to 1 if 'sig_atomic_t' is a signed integer type. */
/* #undef HAVE_SIGNED_SIG_ATOMIC_T */

/* Define to 1 if 'wchar_t' is a signed integer type. */
/* #undef HAVE_SIGNED_WCHAR_T */

/* Define to 1 if 'wint_t' is a signed integer type. */
/* #undef HAVE_SIGNED_WINT_T */

/* Define to 1 if the system has the type `sigset_t'. */
#define HAVE_SIGSET_T 1

/* Define to 1 if you have the `snprintf' function. */
#define HAVE_SNPRINTF 1

/* Define to 1 if you have sound support. */
#define HAVE_SOUND 1

/* Define to 1 if you have the <soundcard.h> header file. */
/* #undef HAVE_SOUNDCARD_H */

/* Define to 1 if `speed_t' is declared by <termios.h>. */
#define HAVE_SPEED_T 1

/* Define to 1 if you have the <stdint.h> header file. */
#define HAVE_STDINT_H 1

/* Define to 1 if you have the <stdio_ext.h> header file. */
#define HAVE_STDIO_EXT_H 1

/* Define to 1 if you have the <stdlib.h> header file. */
#define HAVE_STDLIB_H 1

/* Define to 1 if you have the `strerror' function. */
#define HAVE_STRERROR 1

/* Define to 1 if you have the <strings.h> header file. */
#define HAVE_STRINGS_H 1

/* Define to 1 if you have the <string.h> header file. */
#define HAVE_STRING_H 1

/* Define to 1 if you have the `strsignal' function. */
#define HAVE_STRSIGNAL 1

/* Define to 1 if you have the `strtoimax' function. */
#define HAVE_STRTOIMAX 1

/* Define to 1 if you have the `strtoll' function. */
/* #undef HAVE_STRTOLL */

/* Define to 1 if you have the `strtoull' function. */
/* #undef HAVE_STRTOULL */

/* Define to 1 if you have the `strtoumax' function. */
#define HAVE_STRTOUMAX 1

/* Define to 1 if `ifr_addr' is a member of `struct ifreq'. */
#define HAVE_STRUCT_IFREQ_IFR_ADDR 1

/* Define to 1 if `ifr_addr.sa_len' is a member of `struct ifreq'. */
/* #undef HAVE_STRUCT_IFREQ_IFR_ADDR_SA_LEN */

/* Define to 1 if `ifr_broadaddr' is a member of `struct ifreq'. */
#define HAVE_STRUCT_IFREQ_IFR_BROADADDR 1

/* Define to 1 if `ifr_flags' is a member of `struct ifreq'. */
#define HAVE_STRUCT_IFREQ_IFR_FLAGS 1

/* Define to 1 if `ifr_hwaddr' is a member of `struct ifreq'. */
#define HAVE_STRUCT_IFREQ_IFR_HWADDR 1

/* Define to 1 if `ifr_netmask' is a member of `struct ifreq'. */
#define HAVE_STRUCT_IFREQ_IFR_NETMASK 1

/* Define to 1 if `n_un.n_name' is a member of `struct nlist'. */
/* #undef HAVE_STRUCT_NLIST_N_UN_N_NAME */

/* Define to 1 if `tm_zone' is a member of `struct tm'. */
#define HAVE_STRUCT_TM_TM_ZONE 1

/* Define to 1 if `struct utimbuf' is declared by <utime.h>. */
#define HAVE_STRUCT_UTIMBUF 1

/* Define if struct stat has an st_dm_mode member. */
/* #undef HAVE_ST_DM_MODE */

/* Define to 1 if you have the `symlink' function. */
#define HAVE_SYMLINK 1

/* Define to 1 if you have the `sync' function. */
#define HAVE_SYNC 1

/* Define to 1 if you have the `sysinfo' function. */
#define HAVE_SYSINFO 1

/* Define to 1 if you have the <sys/bitypes.h> header file. */
/* #undef HAVE_SYS_BITYPES_H */

/* Define to 1 if you have the <sys/inttypes.h> header file. */
/* #undef HAVE_SYS_INTTYPES_H */

/* Define to 1 if you have the <sys/loadavg.h> header file. */
/* #undef HAVE_SYS_LOADAVG_H */

/* Define to 1 if you have the <sys/mman.h> header file. */
#define HAVE_SYS_MMAN_H 1

/* Define to 1 if you have the <sys/param.h> header file. */
#define HAVE_SYS_PARAM_H 1

/* Define to 1 if you have the <sys/resource.h> header file. */
#define HAVE_SYS_RESOURCE_H 1

/* Define to 1 if you have the <sys/select.h> header file. */
#define HAVE_SYS_SELECT_H 1

/* Define to 1 if you have the <sys/socket.h> header file. */
#define HAVE_SYS_SOCKET_H 1

/* Define to 1 if you have the <sys/soundcard.h> header file. */
#define HAVE_SYS_SOUNDCARD_H 1

/* Define to 1 if you have the <sys/stat.h> header file. */
#define HAVE_SYS_STAT_H 1

/* Define to 1 if you have the <sys/systeminfo.h> header file. */
/* #undef HAVE_SYS_SYSTEMINFO_H */

/* Define to 1 if you have the <sys/time.h> header file. */
#define HAVE_SYS_TIME_H 1

/* Define to 1 if you have the <sys/types.h> header file. */
#define HAVE_SYS_TYPES_H 1

/* Define to 1 if you have the <sys/un.h> header file. */
#define HAVE_SYS_UN_H 1

/* Define to 1 if you have the <sys/utsname.h> header file. */
#define HAVE_SYS_UTSNAME_H 1

/* Define to 1 if you have the <sys/vlimit.h> header file. */
#define HAVE_SYS_VLIMIT_H 1

/* Define to 1 if you have <sys/wait.h> that is POSIX.1 compatible. */
#define HAVE_SYS_WAIT_H 1

/* Define to 1 if you have the <sys/_mbstate_t.h> header file. */
/* #undef HAVE_SYS__MBSTATE_T_H */

/* Define to 1 if you have the <term.h> header file. */
/* #undef HAVE_TERM_H */

/* Define to 1 if you have the tiff library (-ltiff). */
#define HAVE_TIFF 1

/* Define to 1 if `struct timeval' is declared by <sys/time.h>. */
#define HAVE_TIMEVAL 1

/* Define if struct tm has the tm_gmtoff member. */
#define HAVE_TM_GMTOFF 1

/* Define to 1 if your `struct tm' has `tm_zone'. Deprecated, use
   `HAVE_STRUCT_TM_TM_ZONE' instead. */
#define HAVE_TM_ZONE 1

/* Define to 1 if you have the `touchlock' function. */
/* #undef HAVE_TOUCHLOCK */

/* Define to 1 if you don't have `tm_zone' but do have the external array
   `tzname'. */
/* #undef HAVE_TZNAME */

/* Define to 1 if you have the `tzset' function. */
#define HAVE_TZSET 1

/* Define to 1 if you have the `ualarm' function. */
#define HAVE_UALARM 1

/* Define to 1 if you have the <unistd.h> header file. */
#define HAVE_UNISTD_H 1

/* Define to 1 if the system has the type `unsigned long long int'. */
#define HAVE_UNSIGNED_LONG_LONG_INT 1

/* Define to 1 if you have the <util.h> header file. */
/* #undef HAVE_UTIL_H */

/* Define to 1 if you have the `utimes' function. */
#define HAVE_UTIMES 1

/* Define to 1 if you have the <utime.h> header file. */
#define HAVE_UTIME_H 1

/* Define to 1 if you have the <utmp.h> header file. */
#define HAVE_UTMP_H 1

/* Define to 1 if you have the `vfork' function. */
#define HAVE_VFORK 1

/* Define to 1 if you have the <vfork.h> header file. */
/* #undef HAVE_VFORK_H */

/* Define to 1 if you have the <wchar.h> header file. */
#define HAVE_WCHAR_H 1

/* Define if you have the 'wchar_t' type. */
#define HAVE_WCHAR_T 1

/* Define if you have a window system. */
#define HAVE_WINDOW_SYSTEM 1

/* Define to 1 if `fork' works. */
#define HAVE_WORKING_FORK 1

/* Define to 1 if `vfork' works. */
#define HAVE_WORKING_VFORK 1

/* Define to 1 if you have the <ws2tcpip.h> header file. */
/* #undef HAVE_WS2TCPIP_H */

/* Define to 1 if you want to use version 11 of X windows. Otherwise, Emacs
   expects to use version 10. */
#define HAVE_X11 1

/* Define to 1 if you have the X11R6 or newer version of Xlib. */
#define HAVE_X11R6 1

/* Define if you have usable X11R6-style XIM support. */
#define HAVE_X11R6_XIM 1

/* Define to 1 if you have the X11R6 or newer version of Xt. */
/* #undef HAVE_X11XTR6 */

/* Define to 1 if you have the Xaw3d library (-lXaw3d). */
/* #undef HAVE_XAW3D */

/* Define to 1 if you have the Xft library. */
#define HAVE_XFT 1

/* Define to 1 if XIM is available */
#define HAVE_XIM 1

/* Define to 1 if you have the XkbGetKeyboard function. */
#define HAVE_XKBGETKEYBOARD 1

/* Define to 1 if you have the Xpm libary (-lXpm). */
#define HAVE_XPM 1

/* Define to 1 if you have the `XrmSetDatabase' function. */
#define HAVE_XRMSETDATABASE 1

/* Define to 1 if you have the `XScreenNumberOfScreen' function. */
#define HAVE_XSCREENNUMBEROFSCREEN 1

/* Define to 1 if you have the `XScreenResourceString' function. */
#define HAVE_XSCREENRESOURCESTRING 1

/* Define to 1 if you have the `XSetWMProtocols' function. */
#define HAVE_XSETWMPROTOCOLS 1

/* Define if you have usable i18n support. */
#define HAVE_X_I18N 1

/* Define to 1 if you have the SM library (-lSM). */
#define HAVE_X_SM 1

/* Define to 1 if you want to use the X window system. */
#define HAVE_X_WINDOWS 1

/* Define to 1 if the system has the type `_Bool'. */
#define HAVE__BOOL 1

/* Define to 1 if you have the `__builtin_unwind_init' function. */
#define HAVE___BUILTIN_UNWIND_INIT 1

/* Define to 1 if you have the `__executable_start' function. */
#define HAVE___EXECUTABLE_START 1

/* Define to 1 if you have the `__fpending' function. */
#define HAVE___FPENDING 1

/* Define to support using a Hesiod database to find the POP server. */
/* #undef HESIOD */

/* Define to support Kerberos-authenticated POP mail retrieval. */
/* #undef KERBEROS */

/* Define to use Kerberos 5 instead of Kerberos 4. */
/* #undef KERBEROS5 */

/* Define to 1 if localtime caches TZ. */
/* #undef LOCALTIME_CACHE */

/* Define to 1 if `lstat' dereferences a symlink specified with a trailing
   slash. */
#define LSTAT_FOLLOWS_SLASHED_SYMLINK 1

/* String giving fallback POP mail host. */
/* #undef MAILHOST */

/* Define to unlink, rather than empty, mail spool after reading. */
/* #undef MAIL_UNLINK_SPOOL */

/* Define if the mailer uses flock to interlock the mail spool. */
#define MAIL_USE_FLOCK 1

/* Define if the mailer uses lockf to interlock the mail spool. */
/* #undef MAIL_USE_LOCKF */

/* Define to support MMDF mailboxes in movemail. */
/* #undef MAIL_USE_MMDF */

/* Define to support POP mail retrieval. */
#define MAIL_USE_POP 1

/* Define to 1 if you don't have struct exception in math.h. */
/* #undef NO_MATHERR */

/* Define to 1 if your C compiler doesn't accept -c and -o together. */
/* #undef NO_MINUS_C_MINUS_O */

/* Define to 1 if `NSInteger' is defined. */
/* #undef NS_HAVE_NSINTEGER */

/* Define to 1 if you are using NS windowing under MacOS X. */
/* #undef NS_IMPL_COCOA */

/* Define to 1 if you are using NS windowing under GNUstep. */
/* #undef NS_IMPL_GNUSTEP */

/* Define to 1 if the nlist n_name member is a pointer */
/* #undef N_NAME_POINTER */

/* Define if the C compiler is the linker. */
/* #undef ORDINARY_LINK */

/* Name of package */
#define PACKAGE "emacs"

/* Define to the address where bug reports for this package should be sent. */
#define PACKAGE_BUGREPORT ""

/* Define to the full name of this package. */
#define PACKAGE_NAME "emacs"

/* Define to the full name and version of this package. */
#define PACKAGE_STRING "emacs 24.0.91"

/* Define to the one symbol short name of this package. */
#define PACKAGE_TARNAME "emacs"

/* Define to the home page for this package. */
#define PACKAGE_URL ""

/* Define to the version of this package. */
#define PACKAGE_VERSION "24.0.91"

/* Define as `void' if your compiler accepts `void *'; otherwise define as
   `char'. */
#define POINTER_TYPE void

/* Define to 1 if the C compiler supports function prototypes. */
#define PROTOTYPES 1

/* Define to 1 if pthread_sigmask(), when it fails, returns -1 and sets errno.
   */
/* #undef PTHREAD_SIGMASK_FAILS_WITH_ERRNO */

/* Define to 1 if pthread_sigmask() may returns 0 and have no effect. */
/* #undef PTHREAD_SIGMASK_INEFFECTIVE */

/* Define to 1 if pthread_sigmask() unblocks signals incorrectly. */
/* #undef PTHREAD_SIGMASK_UNBLOCK_BUG */

/* Define to l, ll, u, ul, ull, etc., as suitable for constants of type
   'ptrdiff_t'. */
/* #undef PTRDIFF_T_SUFFIX */

/* Define to 1 if readlink fails to recognize a trailing slash. */
/* #undef READLINK_TRAILING_SLASH_BUG */

/* Define REL_ALLOC if you want to use the relocating allocator for buffer
   space. */
/* #undef REL_ALLOC */

/* Define to 1 if stat needs help when passed a directory name with a trailing
   slash */
/* #undef REPLACE_FUNC_STAT_DIR */

/* Define to 1 if stat needs help when passed a file name with a trailing
   slash */
/* #undef REPLACE_FUNC_STAT_FILE */

/* Define to l, ll, u, ul, ull, etc., as suitable for constants of type
   'sig_atomic_t'. */
/* #undef SIG_ATOMIC_T_SUFFIX */

/* Define to l, ll, u, ul, ull, etc., as suitable for constants of type
   'size_t'. */
/* #undef SIZE_T_SUFFIX */

/* If using the C implementation of alloca, define if you know the
   direction of stack growth for your system; otherwise it will be
   automatically deduced at runtime.
        STACK_DIRECTION > 0 => grows toward higher addresses
        STACK_DIRECTION < 0 => grows toward lower addresses
        STACK_DIRECTION = 0 => direction of growth unknown */
/* #undef STACK_DIRECTION */

/* Define to 1 if the `S_IS*' macros in <sys/stat.h> do not work properly. */
/* #undef STAT_MACROS_BROKEN */

/* Define to 1 if you have the ANSI C header files. */
#define STDC_HEADERS 1

/* Define to 1 on System V Release 4. */
/* #undef SVR4 */

/* Process async input synchronously. */
#define SYNC_INPUT 1

/* Define to use system malloc. */
/* #undef SYSTEM_MALLOC */

/* Define to 1 if you use terminfo instead of termcap. */
#define TERMINFO 1

/* Define to 1 if you can safely include both <sys/time.h> and <time.h>. */
#define TIME_WITH_SYS_TIME 1

/* Define to 1 if your <sys/time.h> declares `struct tm'. */
/* #undef TM_IN_SYS_TIME */

/* Define to 1 for Encore UMAX. */
/* #undef UMAX */

/* Define to 1 for Encore UMAX 4.3 that has <inq_status/cpustats.h> instead of
   <sys/cpustats.h>. */
/* #undef UMAX4_3 */

/* Define to 1 if using GTK. */
#define USE_GTK 1

/* Define this to use a lisp union for the Lisp_Object data type. */
/* #undef USE_LISP_UNION_TYPE */

/* Define to 1 if using the Lucid X toolkit. */
/* #undef USE_LUCID */

/* Define to use mmap to allocate buffer text. */
/* #undef USE_MMAP_FOR_BUFFERS */

/* Define to 1 if using the Motif X toolkit. */
/* #undef USE_MOTIF */

/* Define to 1 if we should use toolkit scroll bars. */
#define USE_TOOLKIT_SCROLL_BARS 1

/* Define to 1 if we should use XIM, if it is available. */
#define USE_XIM 1

/* Define to 1 if using an X toolkit. */
/* #undef USE_X_TOOLKIT */

/* Version number of package */
#define VERSION "24.0.91"

/* Define to l, ll, u, ul, ull, etc., as suitable for constants of type
   'wchar_t'. */
/* #undef WCHAR_T_SUFFIX */

/* Use long long for EMACS_INT if available. */
/* #undef WIDE_EMACS_INT */

/* Define to l, ll, u, ul, ull, etc., as suitable for constants of type
   'wint_t'. */
/* #undef WINT_T_SUFFIX */

/* Define WORDS_BIGENDIAN to 1 if your processor stores words with the most
   significant byte first (like Motorola and SPARC, unlike Intel). */
#if defined AC_APPLE_UNIVERSAL_BUILD
# if defined __BIG_ENDIAN__
#  define WORDS_BIGENDIAN 1
# endif
#else
# ifndef WORDS_BIGENDIAN
/* #  undef WORDS_BIGENDIAN */
# endif
#endif

/* Define this to check for malloc buffer overrun. */
/* #undef XMALLOC_OVERRUN_CHECK */

/* Define to the type of the 6th arg of XRegisterIMInstantiateCallback, either
   XPointer or XPointer*. */
#define XRegisterIMInstantiateCallback_arg6 XPointer

/* Enable large inode numbers on Mac OS X.  */
#ifndef _DARWIN_USE_64_BIT_INODE
# define _DARWIN_USE_64_BIT_INODE 1
#endif

/* Number of bits in a file offset, on hosts where this is settable. */
/* #undef _FILE_OFFSET_BITS */

/* Define to 1 to make fseeko visible on some hosts (e.g. glibc 2.2). */
/* #undef _LARGEFILE_SOURCE */

/* Define for large files, on AIX-style hosts. */
/* #undef _LARGE_FILES */

/* Define to 1 if on MINIX. */
/* #undef _MINIX */

/* Define if GNUstep uses ObjC exceptions. */
/* #undef _NATIVE_OBJC_EXCEPTIONS */

/* The _Noreturn keyword of draft C1X.  */
#ifndef _Noreturn
# if (3 <= __GNUC__ || (__GNUC__ == 2 && 8 <= __GNUC_MINOR__) \
      || 0x5110 <= __SUNPRO_C)
#  define _Noreturn __attribute__ ((__noreturn__))
# elif 1200 <= _MSC_VER
#  define _Noreturn __declspec (noreturn)
# else
#  define _Noreturn
# endif
#endif


/* Define to 2 if the system does not provide POSIX.1 features except with
   this defined. */
/* #undef _POSIX_1_SOURCE */

/* Define to 1 if you need to in order for `stat' and other things to work. */
/* #undef _POSIX_SOURCE */

/* Define to 500 only on HP-UX. */
/* #undef _XOPEN_SOURCE */

/* Enable extensions on AIX 3, Interix.  */
#ifndef _ALL_SOURCE
# define _ALL_SOURCE 1
#endif
/* Enable general extensions on MacOS X.  */
#ifndef _DARWIN_C_SOURCE
# define _DARWIN_C_SOURCE 1
#endif
/* Enable GNU extensions on systems that have them.  */
#ifndef _GNU_SOURCE
# define _GNU_SOURCE 1
#endif
/* Enable threading extensions on Solaris.  */
#ifndef _POSIX_PTHREAD_SEMANTICS
# define _POSIX_PTHREAD_SEMANTICS 1
#endif
/* Enable extensions on HP NonStop.  */
#ifndef _TANDEM_SOURCE
# define _TANDEM_SOURCE 1
#endif
/* Enable general extensions on Solaris.  */
#ifndef __EXTENSIONS__
# define __EXTENSIONS__ 1
#endif


/* Define to rpl_ if the getopt replacement functions and variables should be
   used. */
#define __GETOPT_PREFIX rpl_

/* Define like PROTOTYPES; this can be used by system headers. */
#define __PROTOTYPES 1

/* Ensure that <stdint.h> defines the limit macros, since gnulib's
   <inttypes.h> relies on them.  */
#if defined __cplusplus && !defined __STDC_LIMIT_MACROS && GL_TRIGGER_STDC_LIMIT_MACROS
# define __STDC_LIMIT_MACROS 1
#endif


/* Define to compiler's equivalent of C99 restrict keyword in array
   declarations. Define as empty for no equivalent. */
#define __restrict_arr __restrict

/* Define to the used machine dependent file. */
#define config_machfile "m/amdx86-64.h"

/* Define to the used os dependent file. */
#define config_opsysfile "s/gnu-linux.h"

/* Define to empty if `const' does not conform to ANSI C. */
/* #undef const */

/* A replacement for va_copy, if needed.  */
#define gl_va_copy(a,b) ((a) = (b))

/* Define to `__inline__' or `__inline' if that's what the C compiler
   calls it, or to nothing if 'inline' is not supported under any name.  */
#ifndef __cplusplus
/* #undef inline */
#endif

/* Work around a bug in Apple GCC 4.0.1 build 5465: In C99 mode, it supports
   the ISO C 99 semantics of 'extern inline' (unlike the GNU C semantics of
   earlier versions), but does not display it by setting __GNUC_STDC_INLINE__.
   __APPLE__ && __MACH__ test for MacOS X.
   __APPLE_CC__ tests for the Apple compiler and its version.
   __STDC_VERSION__ tests for the C99 mode.  */
#if defined __APPLE__ && defined __MACH__ && __APPLE_CC__ >= 5465 && !defined __cplusplus && __STDC_VERSION__ >= 199901L && !defined __GNUC_STDC_INLINE__
# define __GNUC_STDC_INLINE__ 1
#endif

/* Define to a type if <wchar.h> does not define. */
/* #undef mbstate_t */

/* Define to `int' if <sys/types.h> does not define. */
/* #undef mode_t */

/* Define to the name of the strftime replacement function. */
#define my_strftime nstrftime

/* Define to the type of st_nlink in struct stat, or a supertype. */
/* #undef nlink_t */

/* Define to `int' if <sys/types.h> does not define. */
/* #undef pid_t */

/* Define to the equivalent of the C99 'restrict' keyword, or to
   nothing if this is not supported.  Do not define if restrict is
   supported directly.  */
#define restrict __restrict
/* Work around a bug in Sun C++: it does not support _Restrict or
   __restrict__, even though the corresponding Sun C compiler ends up with
   "#define restrict _Restrict" or "#define restrict __restrict__" in the
   previous line.  Perhaps some future version of Sun C++ will work with
   restrict; if so, hopefully it defines __RESTRICT like Sun C does.  */
#if defined __SUNPRO_CC && !defined __RESTRICT
# define _Restrict
# define __restrict__
#endif

/* type to use in place of socklen_t if not defined */
/* #undef socklen_t */

/* Define as a signed type of the same size as size_t. */
/* #undef ssize_t */

/* Define to any substitute for sys_siglist. */
/* #undef sys_siglist */

/* Define as a marker that can be attached to declarations that might not
    be used.  This helps to reduce warnings, such as from
    GCC -Wunused-parameter.  */
#if __GNUC__ >= 3 || (__GNUC__ == 2 && __GNUC_MINOR__ >= 7)
# define _GL_UNUSED __attribute__ ((__unused__))
#else
# define _GL_UNUSED
#endif
/* The name _UNUSED_PARAMETER_ is an earlier spelling, although the name
   is a misnomer outside of parameter lists.  */
#define _UNUSED_PARAMETER_ _GL_UNUSED

/* The __pure__ attribute was added in gcc 2.96.  */
#if __GNUC__ > 2 || (__GNUC__ == 2 && __GNUC_MINOR__ >= 96)
# define _GL_ATTRIBUTE_PURE __attribute__ ((__pure__))
#else
# define _GL_ATTRIBUTE_PURE /* empty */
#endif

/* The __const__ attribute was added in gcc 2.95.  */
#if __GNUC__ > 2 || (__GNUC__ == 2 && __GNUC_MINOR__ >= 95)
# define _GL_ATTRIBUTE_CONST __attribute__ ((__const__))
#else
# define _GL_ATTRIBUTE_CONST /* empty */
#endif


/* Define as a macro for copying va_list variables. */
/* #undef va_copy */

/* Define as `fork' if `vfork' does not work. */
/* #undef vfork */

/* Define to empty if the keyword `volatile' does not work. Warning: valid
   code using `volatile' can become incorrect without. Disable with care. */
/* #undef volatile */


/* On AIX 3 this must be included before any other include file.  */
#include <alloca.h>
#if ! HAVE_ALLOCA
# error "alloca not available on this machine"
#endif

/* Define AMPERSAND_FULL_NAME if you use the convention
   that & in the full name stands for the login id.  */
/* Turned on June 1996 supposing nobody will mind it.  */
#define AMPERSAND_FULL_NAME

/* `subprocesses' should be defined if you want to
   have code for asynchronous subprocesses
   (as used in M-x compile and M-x shell).
   Only MSDOS does not support this (it overrides
   this in its config_opsysfile below).  */

#define subprocesses

/* Include the os and machine dependent files.  */
#include config_opsysfile
#ifdef config_machfile
# include config_machfile
#endif

/* GNUstep needs a bit more pure memory.  Of the existing knobs,
   SYSTEM_PURESIZE_EXTRA seems like the least likely to cause problems.
  (There is probably a better place to do this, but right now the
   Cocoa side does this in s/darwin.h and we cannot parallel this
   exactly since GNUstep is multi-OS.  */
#if defined HAVE_NS && defined NS_IMPL_GNUSTEP
#  define SYSTEM_PURESIZE_EXTRA 30000
#endif

#ifdef emacs /* Don't do this for lib-src.  */
/* Tell regex.c to use a type compatible with Emacs.  */
#define RE_TRANSLATE_TYPE Lisp_Object
#define RE_TRANSLATE(TBL, C) CHAR_TABLE_TRANSLATE (TBL, C)
#ifdef make_number
/* If make_number is a macro, use it.  */
#define RE_TRANSLATE_P(TBL) (!EQ (TBL, make_number (0)))
#else
/* If make_number is a function, avoid it.  */
#define RE_TRANSLATE_P(TBL) (!(INTEGERP (TBL) && XINT (TBL) == 0))
#endif
#endif

/* These default definitions are good for almost all machines.
   Any exceptions should override them in m/MACHINE.h.
   They must be usable in preprocessor conditionals.  */

#ifndef BITS_PER_CHAR
#define BITS_PER_CHAR 8
#endif

#ifndef BITS_PER_SHORT
#define BITS_PER_SHORT 16
#endif

#ifndef BITS_PER_INT
#define BITS_PER_INT 32
#endif

#ifndef BITS_PER_LONG
#ifdef _LP64
#define BITS_PER_LONG 64
#else
#define BITS_PER_LONG 32
#endif
#endif

#if !defined BITS_PER_LONG_LONG && HAVE_LONG_LONG_INT
#define BITS_PER_LONG_LONG 64
#endif

/* Define if the compiler supports function prototypes.  It may do so but
   not define __STDC__ (e.g. DEC C by default) or may define it as zero.  */
#define PROTOTYPES 1

#include <string.h>
#include <stdlib.h>

#if defined __GNUC__ && (__GNUC__ > 2 \
                         || (__GNUC__ == 2 && __GNUC_MINOR__ >= 5))
#define NO_RETURN	__attribute__ ((__noreturn__))
#else
#define NO_RETURN	/* nothing */
#endif

#if __GNUC__ >= 3  /* On GCC 3.0 we might get a warning.  */
#define NO_INLINE __attribute__((noinline))
#else
#define NO_INLINE
#endif

#if (__GNUC__ > 4 || (__GNUC__ == 4 && __GNUC_MINOR__ >= 1))
#define EXTERNALLY_VISIBLE __attribute__((externally_visible))
#else
#define EXTERNALLY_VISIBLE
#endif

#if __GNUC__ > 2 || (__GNUC__ == 2 && __GNUC_MINOR__ >= 7)
# define ATTRIBUTE_FORMAT(spec) __attribute__ ((__format__ spec))
#else
# define ATTRIBUTE_FORMAT(spec) /* empty */
#endif

#if __GNUC__ > 4 || (__GNUC__ == 4 && __GNUC_MINOR__ >= 4)
# define ATTRIBUTE_FORMAT_PRINTF(formatstring_parameter, first_argument) \
   ATTRIBUTE_FORMAT ((__gnu_printf__, formatstring_parameter, first_argument))
#else
# define ATTRIBUTE_FORMAT_PRINTF(formatstring_parameter, first_argument) \
   ATTRIBUTE_FORMAT ((__printf__, formatstring_parameter, first_argument))
#endif

/* Some versions of GNU/Linux define noinline in their headers.  */
#ifdef noinline
/* #undef noinline */
#endif

/* These won't be used automatically yet.  We also need to know, at least,
   that the stack is continuous.  */
#ifdef __GNUC__
#  ifndef GC_SETJMP_WORKS
  /* GC_SETJMP_WORKS is nearly always appropriate for GCC.  */
#    define GC_SETJMP_WORKS 1
#  endif
#endif

#endif /* EMACS_CONFIG_H */

/*
Local Variables:
mode: c
End:
*/

