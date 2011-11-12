#!/bin/sh
cd $(dirname $0)
. ./includes.sh

######## Computing variables #####
abs_path LISP_DIR

######## Checking lisp ###########
if ! [ -f "$LISP_DIR/$LISP_RELATIVE_PATH" ];
then echo "
ERROR: $(uppercase $CUR_LISP) $LISP_DIR/$LISP_RELATIVE_PATH not found (please run provide-lisp.sh).

FAILED."; return 1;
fi

eval "$(get_run_lisp_cmd) $@"