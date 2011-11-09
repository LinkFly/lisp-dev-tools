#!/bin/sh

#### Using entities ####
# cut
# dirname
# ./global-params.conf
# PREFIX from global-params.conf
#
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

printf "$MES_CHECK_START"
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

uppercase () {
echo $1 | tr 'a-z' 'A-Z'
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
local ABS_PATH_D
local ABS_PATH_TMP
local ABS_PATH_ABS_P
ABS_PATH_D=\$
eval ABS_PATH_TMP=$ABS_PATH_D$1
ABS_PATH_ABS_P=$(abs_path_p $ABS_PATH_TMP)
if [ $ABS_PATH_ABS_P = "no" ];
then eval $1=$PREFIX/$ABS_PATH_TMP;
fi
}

provide_dir_or_file () {
local DIR_OR_FILE="$2"
local PROCESS_CMD="$3"
local MES_START_PROCESS="$4"
local MES_ALREADY="$5"
local MES_SUCCESS="$6"
local MES_FAILED="$7"

echo "$MES_START_PROCESS"
if [ -$1 $DIR_OR_FILE ];
then 
    echo "$MES_ALREADY";
else 
    RESULT=1;
    eval "$PROCESS_CMD" && RESULT=0;
    if [ $RESULT = 0 ];
    then echo "$MES_SUCCESS"
    else echo "$MES_FAILED"; return 1;
    fi
fi
}

provide_dir () {
local DIR="$1"
local PROCESS_CMD="$2"
local MES_START_PROCESS="$3"
local MES_ALREADY="$4"
local MES_SUCCESS="$5"
local MES_FAILED="$6"
provide_dir_or_file d "$DIR" "$PROCESS_CMD" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"
}

provide_file () {
local FILE="$1"
local PROCESS_CMD="$2"
local MES_START_PROCESS="$3"
local MES_ALREADY="$4"
local MES_SUCCESS="$5"
local MES_FAILED="$6"
provide_dir_or_file f "$FILE" "$PROCESS_CMD" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"
}

extract_archive () {
#### Parameters ####
local EXTRACT_CMD="$1"
local ARCHIVE="$2"
local RESULT_DIR="$3"
local MES_CHECK_ALREADY_FAIL="$4"
local MES_CHECK_AR_FAIL="$5"
local MES_START_EXTRACTED="$6"
local MES_CHECK_RES_FAIL="$7"
local MES_CHECK_RES_SUCC="$8"

#### Other variables ####
local RESULT

######### Checking archive extracted ####### 
if [ -d "$RESULT_DIR" ];
then echo "$MES_CHECK_ALREADY_FAIL"; return 1;
fi

######### Checking archive file ####### 
if ! [ -f "$ARCHIVE" ];
then echo "$MES_CHECK_AR_FAIL"; return 1;
fi

######### Extracted archive file ####### 
echo $MES_START_EXTRACTED
RESULT=1
$EXTRACT_CMD $ARCHIVE && RESULT=0

##### Checking of extracted #######
if [ -d "$RESULT_DIR" ] && [ $RESULT = 0 ];
then echo "$MES_CHECK_RES_SUCC"; 
else rm -rf "$RESULT_DIR"; echo "$MES_CHECK_RES_FAIL"; return 1;
fi
}


remove_dir () {
local DIR="$1"
local MES_SUCC="$2"
local MES_FAIL="$3"
local MES_ABSENCE="$4"

local RESULT

RESULT=1
if [ -d "$DIR" ];
then 
    rm -r "$DIR" && RESULT=0;
    if ( ! [ -d $DIR ] ) && [ $RESULT = 0 ];
    then echo "$MES_SUCC";
    else echo "$MES_FAIL"; return 1;
    fi
else echo "$MES_ABSENCE";
fi

}

build_if_no () {
###### Parameters ######
local FILE_LINK_NAME="$1"
local UTILS_DIR="$2"
local BUILD_SCRIPT="$3"
local BUILDED_FILE="$4"
local MES_ALREADY="$5"
local MES_BUILDED_FAIL="$6"
local MES_BUILDED_SUCC="$7"
########################

local RESULT
local FILE_REALPATH=$(readlink $UTILS_DIR/$FILE_LINK_NAME)
local FILE_LINK=$UTILS_DIR/$FILE_LINK_NAME

if [ $FILE_REALPATH ] && [ $(abs_path_p FILE_REALPATH) = "no" ];
then FILE_REALPATH=$UTILS_DIR/$FILE_REALPATH
fi

########## Building wget if does not exist #######
if [ $FILE_REALPATH ] && [ -f $FILE_REALPATH ]; 
  then echo "$MES_ALREADY";
  else
    RESULT=1;
    $BUILD_SCRIPT && RESULT=0;
    if [ $RESULT = 0 ];
    then
	rm -f $FILE_LINK && ln -s $BUILDED_FILE $FILE_LINK;
	echo "$MES_BUILDED_SUCC"
    else echo "$MES_BUILDED_FAIL"
    fi
fi
}

change_param () {
local PARAM="$1"
local FILE="$2"
local OLD_VAL="$3"
local NEW_VAL="$4"

local CHANGE_REGEX="s/$PARAM=$OLD_VAL/$PARAM=$NEW_VAL/g"
sed -i $CHANGE_REGEX $FILE
}

build_tool () {
#### Parameters ####
local ARCHIVE_PATH="$1"
local TMP_TOOL_DIR="$2"
local EXTRACT_SCRIPT="$3"
local RESULT_DIR="$4"
local COMPILING_EXTRA_PARAMS="$5"

local START_DIR=$PWD

################################
rm -rf $TMP_TOOL_DIR
mkdir --parents $TMP_TOOL_DIR
cd $TMP_TOOL_DIR
$EXTRACT_SCRIPT $ARCHIVE_PATH
cd $TMP_TOOL_DIR/$(ls $TMP_TOOL_DIR)
./configure --prefix $RESULT_DIR $COMPILING_EXTRA_PARAMS
make
make install
cd $START_DIR
rm -rf $TMP_TOOL_DIR
}

######## Restore path $$$$$$$$$$$
cd $CUR_PATH
