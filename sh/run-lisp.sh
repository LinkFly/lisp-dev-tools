#!/bin/sh
cd "$(dirname "$0")"
. ./includes.sh

### Used: ####
# GET_CMD_P - if "yes" then showing command line
#    for running lisp (without lisp starting)
############## 

correct_quote () {
echo "$1" | sed "s/'/'\"'\"'/g;s/^.*$/'&'/"
}

prepare_args () {
### Using: ###
### ./script2 "$(prepare_args "$@")"
##############

local ARGS=""
local FST="yes"
local CURARG=
for arg in "$@";do
if [ -z "$FST" ];then
    ARGS="$ARGS ";
else FST=""
fi
ARGS="$ARGS"$(correct_quote "$arg");
done
printf "%s" "$ARGS"
}

### Correcting XDG_CONFIG_DIRS ###
XDG_CONFIG_DIRS="'$PREFIX/conf:$XDG_CONFIG_DIRS'"

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

LOAD_QUICKLISP_ARGS="$(get_load_quicklisp_args)"

####### Checking quicklisp require loading #########
if [ "$(echo $LOAD_QUICKLISP_ARGS | cut --bytes=1-5)" = "ERROR" ];then
    echo "$LOAD_QUICKLISP_ARGS";
    exit 1;
fi

FULL_RUN_CMD="XDG_CONFIG_DIRS=$XDG_CONFIG_DIRS $RUN_COMMAND $(prepare_args "$@")${LOAD_QUICKLISP_ARGS}"

### Variable GET_CMD_P initialized into run-lisp script file ###
if [ "$GET_CMD_P" = "yes" ];then
    echo "$FULL_RUN_CMD";
    exit 0;
fi

RESULT=1
eval "$FULL_RUN_CMD" && RESULT=0

if [ $RESULT = 1 ]; then
    echo "
ERROR: Running $(uppercase $CUR_LISP) failed (if lisp isn't existing then to run provide-lisp).
Running command: $FULL_RUN_CMD

FAILED."; exit 1;
fi
