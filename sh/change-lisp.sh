#!/bin/sh
cd "$(dirname "$0")"
. ./includes.sh

./change-default-param.sh CUR_LISP $1 $SCRIPTS_DIR/conf/lisps.conf && echo "Current lisp: $(./get-default-param.sh CUR_LISP)"