#!/bin/sh

##### Include scripts #####
. ./includes.sh
. ./core.sh

########## Computing variables #####
abs_path LISP_DIR
local CUR_LISP_UP=$(uppercase $CUR_LISP)
local LISP_SOURCES_DIR=$SOURCES/$LISP_LISPS_SOURCES/$LISP_SOURCES_DIRNAME
local LISP_COMPILER_DIR=$COMPILERS/$LISP_LISPS_COMPILERS/$LISP_COMPILER_DIRNAME

#################
local SOURCES_DIR="$LISP_SOURCES_DIR"
local RESULT_DIR="$LISP_DIR"
local PROCESS_CMD="PATH=$LISP_COMPILER_DIR/$LISP_BIN_DIR:$PATH $LISP_HOME_VAR_NAME=$LISP_COMPILER_DIR/$LISP_CORE_BIN_DIR $LISP_BUILD_CMD --prefix=$LISP_DIR"
local BIN_BUILD_RESULT=$LISP_SOURCES_DIR/$LISP_BIN_BUILD_RESULT

local MES_ALREADY_FAIL="
ERROR: Lisp $CUR_LISP_UP already builded.
Run remove-lisp.sh and retry building, or run rebuild-lisp.sh
Directory: $LISP_DIR

FAILED."

local MES_NOT_EXIST_SRC_FAIL="
ERROR: directory $LISP_SOURCES_DIR does not exist! 
Please run the provide-sources-sbcl.sh

FAILED."

local MES_START_BUILDING="
Lisp $CUR_LISP_UP building ... 
Directory (contained sources): $LISP_SOURCES_DIR"

local MES_BUILDING_SUCC="
Building $CUR_LISP_UP from $LISP_SOURCES_DIRNAME successful.
Directory contained sources: $LISP_SOURCES_DIR

OK."

local MES_BUILDING_FAIL="
ERROR: Building $CUR_LISP_UP from $LISP_SOURCES_DIRNAME failed.
Directory contained sources: $LISP_SOURCES_DIR

FAILED."

local MES_COPING_RESULT_SUCC="
Coping building $CUR_LISP_UP results into $LISP_DIR successful.
Directory contained sources: $LISP_SOURCES_DIR
Directory with build results: $LISP_DIR

OK."

local MES_COPING_RESULT_FAIL="
ERROR: Coping building $CUR_LISP_UP results into $LISP_DIR failed.
Directory contained sources: $LISP_SOURCES_DIR

FAILED."

build "$SOURCES_DIR" "$RESULT_DIR" "$PROCESS_CMD" "$BIN_BUILD_RESULT" \
"$MES_ALREADY_FAIL" "$MES_NOT_EXIST_SRC_FAIL" \
"$MES_START_BUILDING" "$MES_BUILDING_SUCC" "$MES_BUILDING_FAIL" \
"$MES_COPING_RESULT_SUCC" "$MES_COPING_RESULT_FAIL"