#!/bin/sh
cd $(dirname $0)

ref=$(readlink $(pwd))
if ! [ -z $ref ]; then 
    cd ../$ref/..;
else
    cd ..
fi

. ./includes.sh

SCRIPTS="
remove-lisp.sh
remove-sources-lisp.sh
remove-compiler-lisp.sh
remove-archive-lisp-src.sh
remove-archive-lisp-bin.sh"

for scr in $SCRIPTS;do sh $scr;done


