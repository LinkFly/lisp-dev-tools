#!/bin/sh

. ./includes.sh

provide_tool () {
### Parameters ###
local TOOL_NAME=$1
local BUILD_SCRIPT=$2

local D=\$
local TOOL_DIR=$(eval echo $D$(uppercase $TOOL_NAME)_TOOL_DIR)
local TOOL_RELATIVE_DIR=$(eval echo $D$(uppercase $TOOL_NAME)_RELATIVE_DIR)

abs_path UTILS

### Call build_if_no ###
FILE_LINK_NAME=$TOOL_NAME
UTILS_DIR=$UTILS
BUILD_SCRIPT=$BUILD_SCRIPT
BUILDED_FILE=$TOOLS_DIRNAME/$TOOL_DIR/$TOOL_RELATIVE_DIR/$TOOL_NAME

MES_ALREADY="
Tool $TOOL_NAME found in $UTILS/$FILE_LINK_NAME
Link refers to: $(readlink $UTILS/$FILE_LINK_NAME))

OK."

MES_BUILDED_FAIL="
Builded $TOOL_NAME failed.

FAILED."

MES_BUILDED_SUCC="
Builded $TOOL_NAME success.

OK."

build_if_no "$FILE_LINK_NAME" "$UTILS_DIR" "$BUILD_SCRIPT" "$BUILDED_FILE" \
"$MES_ALREADY" "$MESS_BUILDED_FAIL" "$MES_BUILDED_SUCC"
}

get_lisp_param () {
REST_PARAM_PART="$1"
echo $(get_spec_val $CUR_LISP _$REST_PARAM_PART)
}

########## Created general "LISP_" parameters ########## 
local ALL_LISP_PARAMS="
VERSION
ARCH
OS
DIRNAME
LISPS_DIR
DIR
LISPS_SOURCES
SOURCES_DIRNAME
LISPS_COMPILERS
COMPILER_DIRNAME
NO_BUILDING
BUILD_CMD
HOME_VAR_NAME
BIN_DIR
CORE_BIN_DIR
BIN_BUILD_RESULT
BIN_ARCHIVE
BIN_URL
SOURCE_ARCHIVE
SOURCE_URL"

for param in $ALL_LISP_PARAMS;
do 
    eval LISP_${param}="\"$(get_lisp_param $param)\""; 
done
##################### end filling LISP_ variables ##############