/* Hey Emacs, this is -*- C -*- code!  */
/*
Copyright (C) 1993, 1995, 1997, 1999, 2001-2011
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


/* The default search path for Lisp function "load".
   This sets load-path.  */
#define PATH_LOADSEARCH "/home/linkfly/tmp/tmp-emacs/share/emacs/24.0.91/site-lisp:/home/linkfly/tmp/tmp-emacs/share/emacs/site-lisp:/home/linkfly/tmp/tmp-emacs/share/emacs/24.0.91/lisp:/home/linkfly/tmp/tmp-emacs/share/emacs/24.0.91/leim"

/* Like PATH_LOADSEARCH, but used only when Emacs is dumping.  This
   path is usually identical to PATH_LOADSEARCH except that the entry
   for the directory containing the installed lisp files has been
   replaced with ../lisp.  */
#define PATH_DUMPLOADSEARCH "/home/linkfly/Downloads/lisp-dev-tools/tmp/emacs-compiling/emacsmirror-emacs-0b70f75/lisp"

/* The extra search path for programs to invoke.  This is appended to
   whatever the PATH environment variable says to set the Lisp
   variable exec-path and the first file name in it sets the Lisp
   variable exec-directory.  exec-directory is used for finding
   executables and other architecture-dependent files.  */
#define PATH_EXEC "/home/linkfly/tmp/tmp-emacs/libexec/emacs/24.0.91/x86_64-unknown-linux-gnu"

/* Where Emacs should look for its architecture-independent data
   files, like the NEWS file.  The lisp variable data-directory
   is set to this value.  */
#define PATH_DATA "/home/linkfly/tmp/tmp-emacs/share/emacs/24.0.91/etc"

/* Where Emacs should look for X bitmap files.
   The lisp variable x-bitmap-file-path is set based on this value.  */
#define PATH_BITMAPS "/usr/include/X11/bitmaps"

/* Where Emacs should look for its docstring file.  The lisp variable
   doc-directory is set to this value.  */
#define PATH_DOC "/home/linkfly/tmp/tmp-emacs/share/emacs/24.0.91/etc"

/* Where the configuration process believes the info tree lives.  The
   lisp variable configure-info-directory gets its value from this
   macro, and is then used to set the Info-default-directory-list.  */
#define PATH_INFO "/home/linkfly/tmp/tmp-emacs/share/info"

/* Where Emacs should store game score files.  */
#define PATH_GAME "/home/linkfly/tmp/tmp-emacs/var/games/emacs"

/* Where Emacs should look for the application default file. */
#define PATH_X_DEFAULTS "/usr/share/X11/%L/%T/%N%C%S:/usr/share/X11/%l/%T/%N%C%S:/usr/share/X11/%T/%N%C%S:/usr/share/X11/%L/%T/%N%S:/usr/share/X11/%l/%T/%N%S:/usr/share/X11/%T/%N%S:/usr/lib/X11/%L/%T/%N%C%S:/usr/lib/X11/%l/%T/%N%C%S:/usr/lib/X11/%T/%N%C%S:/usr/lib/X11/%L/%T/%N%S:/usr/lib/X11/%l/%T/%N%S:/usr/lib/X11/%T/%N%S"

