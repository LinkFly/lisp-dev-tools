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

######## Restore path $$$$$$$$$$$
cd $CUR_PATH

