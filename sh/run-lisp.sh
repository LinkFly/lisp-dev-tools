#!/bin/sh
cd $(dirname $0)
. ./includes.sh

RUN_COMMAND=$(get_run_lisp_cmd)

######## Checking lisp ###########
if ! [ -f "$RUN_COMMAND" ];
then echo "
ERROR: $(uppercase $CUR_LISP) $RUN_COMMAND not found (please run provide-lisp.sh).

FAILED."; exit 1;
fi

if [ "$(get_run_lisp_cmd)" = "" ]; then echo "ERROR: empty lisp command."; fi

eval "XDG_CONFIG_DIRS=$PREFIX/conf $RUN_COMMAND $@"
