#!/bin/sh
cd "$(dirname "$0")"
. ./includes.sh

### Used: ####
# GET_CMD_P - if "yes" then showing command line
#    for running lisp (without lisp starting)
############## 

abs_path LISP_DIR

######## Checking lisp ###########
if ! [ -d "$LISP_DIR" ]; then
    echo "
ERROR: Running $(uppercase $CUR_LISP) failed - lisp does not exist (please to run provide-lisp)
Directory (that does not exist): $LISP_DIR

FAILED."; exit 1;
fi
##################################

EVAL_OPTIONS="
SBCL=--eval
CCL=--eval
ECL=-eval
ABCL=--eval
CLISP=emulate_by_load
XCL=
MKCL=-eval
CMUCL=-eval
GCL=-eval
WCL="

LOAD_OPTIONS="
SBCL=--load
CCL=--load
ECL=-load
ABCL=--load
CLISP=-i
XCL=
MKCL=-load
CMUCL=-load
GCL=-load
WCL="

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

### Shared variables ###
IF_EMULATE_BY_LOAD= 
NEXT_ARG_SEXPR_P=no
HANDLED_ARG=

CORRECTED_ARGS=
########################

WAS_COMMON_QUIT_P=no
handling_common_param () {
### Changed variables: ###
# HANDLED_ARG - saved result into it
# IF_EMULATE_BY_LOAD - changed prepared code for running (initialization)
# NEXT_ARG_SEXPR_P - set in "yes", if need handling next arg 
##########################
local TMP_HANDLED_ARG=

HANDLED_ARG=

case "$1" in 
    "'--common-eval'")
	HANDLED_ARG="$(get_val_by_key $(uppercase $CUR_LISP) "$EVAL_OPTIONS")"
	
	### Emulation eval by load ###
	if test "$HANDLED_ARG" = "emulate_by_load"
	then 

	    if test -z "$IF_EMULATE_BY_LOAD"
	    then IF_EMULATE_BY_LOAD='ACC_TMP_FILES=;
add_tmp_file() { ACC_TMP_FILES="$ACC_TMP_FILES $1"; }
del_tmp_files(){ for file in $ACC_TMP_FILES;do rm $file;done; }
trap "del_tmp_files" EXIT;

';
	    fi

	    if test "$WAS_COMMON_QUIT_P" = "yes"
	    then
		WAS_COMMON_QUIT_P=no
		TMP_HANDLED_ARG="$(get_val_by_key $(uppercase $CUR_LISP) "$LOAD_OPTIONS")"
		save_sexpr_and_prepare_for_load "'(quit)'"
		HANDLED_ARG="$TMP_HANDLED_ARG $HANDLED_ARG"
	    else
		NEXT_ARG_SEXPR_P=yes
		HANDLED_ARG="$(get_val_by_key $(uppercase $CUR_LISP) "$LOAD_OPTIONS")"
	    fi

	else ## if not emulate_by_load
	    if test "$WAS_COMMON_QUIT_P" = "yes"
	    then
		WAS_COMMON_QUIT_P=no
		HANDLED_ARG="$HANDLED_ARG '(quit)'" 
	    fi
	fi	
	###############################    
	    ;;
    "'--common-load'")
	HANDLED_ARG="$(get_val_by_key $(uppercase $CUR_LISP) "$LOAD_OPTIONS")"
	    ;;
    "'--common-quit'")
	WAS_COMMON_QUIT_P=yes
	handling_common_param "'--common-eval'"
	    ;;
    *)
	    HANDLED_ARG="$1"
	    ;;
esac
}

### Emulation eval by load ###
NUMBER_TMPFILE=0
save_sexpr_and_prepare_for_load () {
### Changed variables: ###
# HANDLED_ARG - saved result into it
# IF_EMULATE_BY_LOAD - changed prepared code for running
# NUMBER_TMPFILE - counter for temp files
##########################
HANDLED_ARG=
NUMBER_TMPFILE=$((1 + $NUMBER_TMPFILE))
local CUR_TMPFILE_VARNAME="FOR_EMUL_TMPFILE_$NUMBER_TMPFILE"
local D='$'
IF_EMULATE_BY_LOAD="${IF_EMULATE_BY_LOAD}$CUR_TMPFILE_VARNAME=$D(mktemp)
printf $1 > $D$CUR_TMPFILE_VARNAME
add_tmp_file $D$CUR_TMPFILE_VARNAME

"
HANDLED_ARG="$D$CUR_TMPFILE_VARNAME"
}
##############################

correct_quote () {
echo "$1" | sed "s/'/'\"'\"'/g;s/^.*$/'&'/"
}

prepare_args () {
### Changed vars: ###
# CORRECTED_ARGS
#####################

### Using: ###
### ./script2 "$(prepare_args "$@")"
##############
local ARGS=""
local handle_next_param_p=

for arg in "$@"
do
    if ! [ -z "$ARGS" ]
    then
	ARGS="$ARGS "
    fi

    ## Save handling result into HANDLED_ARG
    if test "$NEXT_ARG_SEXPR_P" = "yes"
    then
	### Emulation eval by load ###
	save_sexpr_and_prepare_for_load "$(correct_quote "$arg")"
	NEXT_ARG_SEXPR_P=no
	##############################
    else
	handling_common_param "$(correct_quote "$arg")"
    fi	
    ARGS="$ARGS""$HANDLED_ARG";
done

CORRECTED_ARGS="$ARGS"
}

### Correcting XDG_CONFIG_DIRS ###
XDG_CONFIG_DIRS="'$PREFIX/conf:$XDG_CONFIG_DIRS'"


RUN_COMMAND=$(get_run_lisp_cmd)

######## Checking command ###########
if [ "$(echo $RUN_COMMAND | cut -b 1-5)" = "ERROR" ];then
    echo "$RUN_COMMAND";
    exit 1;
fi

if [ "$RUN_COMMAND" = "" ]; then echo "ERROR: empty lisp command."; fi
#####################################

if test "$GET_CMD_P" = "yes"
then
    LOAD_QUICKLISP_ARGS="$(get_load_quicklisp_args nocheck)"
else 
    LOAD_QUICKLISP_ARGS="$(get_load_quicklisp_args)"
fi

####### Checking quicklisp require loading #########
if [ "$(echo $LOAD_QUICKLISP_ARGS | cut -b 1-5)" = "ERROR" ];then
    echo "$LOAD_QUICKLISP_ARGS";
    exit 1;
fi

## Filled CORRECTED_ARGS
prepare_args "$@"

## Handling CORRECTED_ARGS for support common parameters: --common-[load | eval | quit]


FULL_RUN_CMD="${IF_EMULATE_BY_LOAD}XDG_CONFIG_DIRS=$XDG_CONFIG_DIRS $RUN_COMMAND $CORRECTED_ARGS${LOAD_QUICKLISP_ARGS}"

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
