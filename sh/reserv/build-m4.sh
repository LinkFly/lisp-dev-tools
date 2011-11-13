#!/bin/sh
cd $(dirname $0)
. ./includes.sh

### Call build_tool ###
local ARCHIVE_PATH=$ARCHIVES/$M4_ARCHIVE
local TMP_TOOL_DIR=$TMP/m4-compiling
local EXTRACT_SCRIPT="tar -xzvf"
local RESULT_DIR=$UTILS/$TOOLS_DIRNAME/$M4_TOOL_DIR
local COMPILING_EXTRA_PARAMS=
local MES_ARCHIVE_CHECK_FAIL="
ERROR: archive $ARCHIVE_PATH does not exist!

FAILED."

local MES_BUILD_FAIL="
ERROR: Building tool m4 failed.

FAILED."

build_tool "$ARCHIVE_PATH" "$TMP_TOOL_DIR" "$EXTRACT_SCRIPT" "$RESULT_DIR" \
"$COMPILING_EXTRA_PARAMS" "$MES_ARCHIVE_CHECK_FAIL" "$MES_BUILD_FAIL"