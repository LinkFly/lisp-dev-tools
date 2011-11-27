#!/bin/sh
cd $(dirname $0)/sh
. ./includes.sh

local SCRIPTS="
remove-lisp.sh
remove-sources-lisp.sh
remove-compiler-lisp.sh
remove-archive-lisp-src.sh
remove-archive-lisp-bin.sh"

for scr in $SCRIPTS;do sh $scr;done


