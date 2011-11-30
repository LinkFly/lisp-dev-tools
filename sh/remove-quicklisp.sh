#!/bin/sh
cd $(dirname $0)
. ./includes.sh

if ! [ -d "$QUICKLISP" ];then
    echo "
Quicklisp already removed.
Directory (where was quicklisp): $QUICKLISP

ALREADY."; exit 0
fi

printf  "Quicklisp removing ... "
rm -rf "$QUICKLISP"
rm -f "$LISP_LIBS/quicklisp.lisp"
if [ -d "$QUICKLISP" ];
then echo "failed.";
else echo "ok.";
fi
