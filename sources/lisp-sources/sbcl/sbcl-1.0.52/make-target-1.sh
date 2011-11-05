#!/bin/sh
set -e

# This is a script to be run as part of make.sh. The only time you'd
# want to run it by itself is if you're trying to cross-compile the
# system or if you're doing some kind of troubleshooting.

# This software is part of the SBCL system. See the README file for
# more information.
#
# This software is derived from the CMU CL system, which was
# written at Carnegie Mellon University and released into the
# public domain. The software is in the public domain and is
# provided with absolutely no warranty. See the COPYING and CREDITS
# files for more information.

echo //entering make-target-1.sh

LANG=C
LC_ALL=C
export LANG LC_ALL

# Build the runtime system and symbol table (.nm) file.
#
# (This C build has to come after the first genesis in order to get
# the sbcl.h the C build needs, and come before the second genesis in
# order to produce the symbol table file that second genesis needs. It
# could come either before or after running the cross compiler; that
# doesn't matter.)
echo //building runtime system and symbol table file

# The clean is needed for Darwin's readonlyspace hack.
$GNUMAKE -C src/runtime clean
# $GNUMAKE -C src/runtime depend
$GNUMAKE -C src/runtime all

# Use a little C program to grab stuff from the C header files and
# smash it into Lisp source code.
$GNUMAKE -C tools-for-build -I../src/runtime grovel-headers
tools-for-build/grovel-headers > output/stuff-groveled-from-headers.lisp

$GNUMAKE -C src/runtime after-grovel-headers
