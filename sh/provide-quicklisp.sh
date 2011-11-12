#!/bin/sh
cd $(dirname $0)
. ./includes.sh

$SCRIPTS_DIR/provide-lisp.sh
#$SCRIPTS_DIR/provide-wget.sh
#./download-archive.sh http://beta.quicklisp.org/quicklisp.lisp $LISP_LIBS/quickload.lisp
./run-lisp.sh --load $LISP_LIBS/quickload.lisp --eval \"\(quicklisp-quickstart:install :path \\\"$LISP_LIBS/quicklisp\\\"\)\"