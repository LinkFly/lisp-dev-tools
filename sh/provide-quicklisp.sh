#!/bin/sh
cd $(dirname $0)
. ./includes.sh

if [ -f "$QUICKLISP/setup.lisp" ];then
    echo "
Quicklisp already installed in: $QUICKLISP

ALREADY."; exit 0
fi

$SCRIPTS_DIR/provide-lisp.sh
mkdir --parents "$LISP_LIBS"
$SCRIPTS_DIR/download-archive.sh "http://beta.quicklisp.org/quicklisp.lisp" "$LISP_LIBS/quickload.lisp"

echo "(progn 
        (print (truename \"$LISP_LIBS/quickload.lisp\"))
        (load \"$LISP_LIBS/quickload.lisp\")
        (funcall (find-symbol \"INSTALL\" :quicklisp-quickstart) :path \"$QUICKLISP/\")
        (funcall (find-symbol \"ADD-TO-INIT-FILE\" :ql))
        )" \
 | ./run-lisp.sh
