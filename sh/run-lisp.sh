#!/bin/sh
cd "$(dirname "$0")"
. ./includes.sh

### Variable GET_CMD_P initialized into run-lisp script file ###
GET_CMD_P=$GET_CMD_P

### Correcting XDG_CONFIG_DIRS if not setting ###
if [ "$XDG_CONFIG_DIRS" = "" ];
then XDG_CONFIG_DIRS="$PREFIX/conf";
fi

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
if [ "$(echo $RUN_COMMAND | cut --bytes=1-5)" = "ERROR" ];then
    echo "$RUN_COMMAND";
    exit 1;
fi

if [ "$RUN_COMMAND" = "" ]; then echo "ERROR: empty lisp command."; fi
#####################################

if [ "$GET_CMD_P" = "yes" ];then
    printf "XDG_CONFIG_DIRS='$XDG_CONFIG_DIRS' %s %s" "$RUN_COMMAND" "$@";
    exit 0;
fi

RESULT=1
eval "$(printf "XDG_CONFIG_DIRS='$XDG_CONFIG_DIRS' %s %s" "$RUN_COMMAND" "$@")" && RESULT=0

if [ $RESULT = 1 ]; then
    echo "
ERROR: Running $(uppercase $CUR_LISP) failed (if lisp isn't existing then to run provide-lisp).
Running command: $RUN_COMMAND 

FAILED."; exit 1;
fi
