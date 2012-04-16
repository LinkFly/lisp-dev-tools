#!/bin/sh
cd "$(dirname "$0")"
. ./includes.sh

abs_path LISP_DIR

### Checking lisp supported quicklisp ###
if [ -z $LISP_ENABLE_QUICKLISP ] || [ "$LISP_ENABLE_QUICKLISP" = "no" ];then 
    echo "
ERROR: Quicklisp isn't work with current lisp: $CUR_LISP.

FAILED."; exit 1;
fi
#################################

if [ -f "$QUICKLISP/setup.lisp" ];then
    echo "
Quicklisp already installed in: $QUICKLISP

ALREADY."; exit 0
fi

### Checking lisp is existing ###
if ! [ -d "$LISP_DIR" ];then
    echo "
ERROR: Not found lisp for install quicklisp. Lisp $(uppercase $CUR_LISP) isn't existing (please to run provide-lisp.sh).
Directory (that does not exist): $LISP_DIR

FAILED."; exit 1;
fi
#################################

$SCRIPTS_DIR/provide-lisp.sh
mkdir --parents "$LISP_LIBS"
LOADER_EXTRA_ARGS="-"
NO_CHECK_URL_P="no"
$SCRIPTS_DIR/download-archive.sh "http://beta.quicklisp.org/quicklisp.lisp" "$LOADER_EXTRA_ARGS" "$NO_CHECK_URL_P" "$LISP_LIBS/quickload.lisp"

echo "(progn 
        (print (truename \"$LISP_LIBS/quickload.lisp\"))
        (load \"$LISP_LIBS/quickload.lisp\")
        (funcall (find-symbol \"INSTALL\" :quicklisp-quickstart) :path \"$QUICKLISP/\")
        )" \
 | ENABLE_QUICKLISP=no ./run-lisp.sh
