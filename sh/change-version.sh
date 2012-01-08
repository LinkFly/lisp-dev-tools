#!/bin/sh
cd $(dirname $0)
. ./includes.sh

LISP_VERSION_PARAM=$(uppercase $CUR_LISP)_VERSION
./change-default-param.sh $LISP_VERSION_PARAM $1 $SCRIPTS_DIR/conf/lisps.conf && echo "Current lisp version: $(./get-default-param.sh $LISP_VERSION_PARAM)"

