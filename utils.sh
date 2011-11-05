#!/bin/sh

######## Correcting path ###########
CUR_PATH=$PWD
cd $(dirname $0)

######## Include scripts ###########
. ./global-params.conf

######## Function definitions ######
vardef () {
local D
local TMP
D=\$
eval TMP=$D$1
if [ $TMP ];
then echo "" > /dev/null; 
else eval $1=$2;
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

echo $MES_START_PROCESS
if [ -d $DIR ];
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

######## Restore path $$$$$$$$$$$
cd $CUR_PATH

