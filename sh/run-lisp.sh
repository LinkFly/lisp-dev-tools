#!/bin/sh
cd $(dirname $0)
. ./includes.sh

abs_path LISP_DIR

######## Checking lisp ###########
if ! [ -d "$LISP_DIR" ]; then
    echo "
ERROR: Running $(uppercase $CUR_LISP) failed - lisp does not exist (please to run provide-lisp)
Directory (that does not exist): $LISP_DIR

FAILED."; exit 1;
fi
##################################

RUN_COMMAND=$(get_run_lisp_cmd)

######## Checking command ###########
if [ $(echo $RUN_COMMAND | cut --bytes=1-5) = ERROR ];then
    echo "$RUN_COMMAND";
    exit 1;
fi

if [ "$RUN_COMMAND" = "" ]; then echo "ERROR: empty lisp command."; fi
#####################################

RESULT=1
eval "XDG_CONFIG_DIRS=$PREFIX/conf $RUN_COMMAND $@" && RESULT=0

if [ $RESULT = 1 ]; then
    echo "
ERROR: Running $(uppercase $CUR_LISP) failed (if lisp isn't existing then to run provide-lisp.sh).
Running command: $RUN_COMMAND 

FAILED."; exit 1;
fi
