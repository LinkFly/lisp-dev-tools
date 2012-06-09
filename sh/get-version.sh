#!/bin/sh
cd "$(dirname "$0")"
. ./includes.sh
D=\$
LISP_VERSION_PARAM="$(uppercase $CUR_LISP)_VERSION"
eval echo "$D$LISP_VERSION_PARAM"

