#!/bin/sh
cd $(dirname $0)
. ./includes.sh

### Call build_tool ###
local ARCHIVE_PATH=$ARCHIVES/$AUTOCONF_ARCHIVE
local TMP_TOOL_DIR=$TMP/autoconf-compiling
local EXTRACT_SCRIPT="tar -xzvf"
local RESULT_DIR=$UTILS/$TOOLS_DIRNAME/$AUTOCONF_TOOL_DIR
local COMPILING_EXTRA_PARAMS="$AUTOCONF_COMPILING_EXTRA_ARGS"
local MES_ARCHIVE_CHECK_FAIL="
ERROR: archive $ARCHIVE_PATH does not exist!

FAILED."

local MES_BUILD_FAIL="
ERROR: Building tool AUTOCONF failed.

FAILED."

PRE_BUILD_CMD="$AUTOCONF_PRE_BUILD_CMD"

build_tool autoconf
#build_tool "$ARCHIVE_PATH" "$TMP_TOOL_DIR" "$EXTRACT_SCRIPT" "$RESULT_DIR" \
#"$COMPILING_EXTRA_PARAMS" "$MES_ARCHIVE_CHECK_FAIL" "$MES_BUILD_FAIL" "$PRE_BUILD_CMD"
