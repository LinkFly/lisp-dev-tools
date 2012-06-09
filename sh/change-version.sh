#!/bin/sh
cd "$(dirname "$0")"
. ./includes.sh

LISP_VERSION_PARAM=$(uppercase $CUR_LISP)_VERSION
./change-default-param.sh $LISP_VERSION_PARAM $1 "$LDT_CUSTOM_CONF_DIR/custom-lisp-and-version.conf" && echo "Current lisp version: $(./get-default-param.sh $LISP_VERSION_PARAM)"

