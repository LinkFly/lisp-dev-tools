#!/bin/sh
cd $(dirname $0)
. ./includes.sh

RUN_COMMAND=$(get_run_lisp_cmd)

######## Checking lisp ###########

### !!! Checking not work for CMUCL ###
#if ! [ -f "$RUN_COMMAND" ];
#then echo "
#ERROR: $(uppercase $CUR_LISP) $RUN_COMMAND not found (please run provide-lisp.sh).
#
#FAILED."; exit 1;
#fi

if [ "$(get_run_lisp_cmd)" = "" ]; then echo "ERROR: empty lisp command."; fi

RESULT=1
eval "XDG_CONFIG_DIRS=$PREFIX/conf $RUN_COMMAND $@" && RESULT=0
if [ $RESULT = 1 ]; then
    echo "
ERROR: $(uppercase $CUR_LISP) $RUN_COMMAND failed. (please run provide-lisp.sh)

FAILED."; exit 1;
fi
