#!/bin/sh
cd "$(dirname "$0")"
. ./includes.sh

./change-default-param.sh CUR_LISP $1 "$LDT_CUSTOM_CONF_DIR/custom-lisp-and-version.conf" && echo "Current lisp: $(./get-default-param.sh CUR_LISP)"