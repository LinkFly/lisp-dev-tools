#!/bin/sh
cd "$(dirname "$0")"
. ./includes.sh

### Used: ####
# GET_CMD_P - if "yes" then showing command line
#    for running lisp (without lisp starting)
############## 

TMP=
trap "if test -n '$TMP';then rm '$tmp';fi" EXIT 

EVAL_OPTIONS="
SBCL=--eval
CCL=--eval
ECL=-eval
ABCL=--eval
CLISP=emulate_by_load"

LOAD_OPTIONS="
SBCL=--load"

get_val_by_key () {
local key="$1"
local keys_vals="$2"
for kv in $keys_vals
do     
    if test "$key" = "${kv%=*}"
    then
	echo "${kv#*=}"
	break
    fi
done
}

HANDLED_ARG=
handling_common_param () {
### Changed variables: ###
# HANDLED_ARG - saved result into it
##########################

HANDLED_ARG=

case "$1" in 
    "'--common-eval'")
	HANDLED_ARG="$(get_val_by_key $(uppercase $CUR_LISP) "$EVAL_OPTIONS")"
	
	if test "$HANDLED_ARG" = "emulate_by_load"
	then 
	    exit 1 #not worked
	fi	
	    ;;
    "'--common-load'")
	HANDLED_ARG="$(get_val_by_key $(uppercase $CUR_LISP) "$LOAD_OPTIONS")"
	    ;;
    *)
	    HANDLED_ARG="$1"
	    ;;
esac
}

#echo $(handling_common_param '--common-eval')
#exit 1

correct_quote () {
echo "$1" | sed "s/'/'\"'\"'/g;s/^.*$/'&'/"
}

CORRECTED_ARGS=

prepare_args () {
### Changed vars: ###
# CORRECTED_ARGS
#####################

### Using: ###
### ./script2 "$(prepare_args "$@")"
##############
local ARGS=""
local FST="yes"
local handle_next_param_p=

for arg in "$@"
do
    if [ -z "$FST" ]
    then
	ARGS="$ARGS "
    else FST=""
    fi

#    if test "$handle_next_param_p" = "yes"	
#    then
#	
#	handle_next_param_p=no
#    else handle_next_param_p=$(is_handle_next_param_p "$arg")
#    fi
    
    ## Save handling result into HANDLED_ARG
    handling_common_param "$(correct_quote "$arg")"
    ARGS="$ARGS""$HANDLED_ARG";
done

#printf "%s" "$ARGS"
CORRECTED_ARGS="$ARGS"
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

## Filled CORRECTED_ARGS
prepare_args "$@"

## Handling CORRECTED_ARGS for support common parameters: --common-[load | eval | quit]


FULL_RUN_CMD="XDG_CONFIG_DIRS=$XDG_CONFIG_DIRS $RUN_COMMAND $CORRECTED_ARGS${LOAD_QUICKLISP_ARGS}"

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
