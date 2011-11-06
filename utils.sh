#!/bin/sh

#### Using entities ####
# cut
# dirname
# ./global-params.conf
# PREFIX from global-params.conf
#

######## Correcting path ###########
CUR_PATH=$PWD
cd $(dirname $0)

######## Include scripts ###########
. ./global-params.conf

######## Function definitions ######
check_args () {
local ARGS
local ARGS_NEED
local MES_CHECK_START
local MES_SUCCESS
local MES_FAILED

ARG=$1
ARGS_NEED=$2
MES_CHECK_START=$3
MES_SUCCESS=$4
MES_FAILED=$5

echo $MES_CHECK_START
if [ "$SRC_OR_BIN" = "" ];
then echo $MES_FAILED; return 1;
else 
    for arg in $ARGS_NEED;
    do
	if [ $arg = $ARG ];
        then echo $MES_SUCCESS; return 0;
	fi
    done;
    echo $MES_FAILED; return 1;
fi
}

vardef () {
local D
local TMP
D=\$
eval TMP=$D$1
if [ "$TMP" = "" ];
then eval $1=$2;
fi
}


fst_char () {
echo $1 | cut -c 1
}

abs_path_p () {
local TMP
TMP=$(fst_char $1)
if [ $TMP ]; then 
  if [ "$TMP" = "/" ];
  then echo "yes";
  else echo "no";
  fi
fi
}

abs_path () {
local D
local TMP
local ABS_P
D=\$
eval TMP=$D$1
ABS_P=$(abs_path_p $TMP)

if [ $ABS_P = "no" ];
then eval $1=$PREFIX/$TMP;
fi
}

provide_dir_or_file () {
local DIR
local PROCESS_SCRIPT
local MES_START_PROCESS
local MES_ALREADY
local MES_SUCCESS
local MES_FAILED

DIR=$2
PROCESS_SCRIPT=$3
MES_START_PROCESS=$4
MES_ALREADY=$5
MES_SUCCESS=$6
MES_FAILED=$7

echo $MES_START_PROCESS
if [ -$1 $DIR ];
then 
    echo $MES_ALREADY;
else 
    RESULT=1;
    eval "$PROCESS_SCRIPT" && RESULT=0;
    if [ $RESULT = 0 ];
    then echo $MES_SUCCESS
    else echo $MES_FAILED; return 1;
    fi
fi
}

provide_dir () {
local DIR
local PROCESS_SCRIPT
local MES_START_PROCESS
local MES_ALREADY
local MES_SUCCESS
local MES_FAILED

DIR=$1
PROCESS_SCRIPT=$2
MES_START_PROCESS=$3
MES_ALREADY=$4
MES_SUCCESS=$5
MES_FAILED=$6

provide_dir_or_file d "$DIR" "$PROCESS_SCRIPT" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"
}

provide_file () {
local DIR
local PROCESS_SCRIPT
local MES_START_PROCESS
local MES_ALREADY
local MES_SUCCESS
local MES_FAILED

DIR=$1
PROCESS_SCRIPT=$2
MES_START_PROCESS=$3
MES_ALREADY=$4
MES_SUCCESS=$5
MES_FAILED=$6

provide_dir_or_file f "$DIR" "$PROCESS_SCRIPT" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"
}

######## Restore path $$$$$$$$$$$
cd $CUR_PATH

