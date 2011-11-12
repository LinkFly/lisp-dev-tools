#!/bin/sh
cd $(dirname $0)
. ./includes.sh

### Call build_tool ###
local ARCHIVE_PATH=$PREFIX/$WGET_ARCHIVE
local TMP_TOOL_DIR=$TMP/wget-compiling
local EXTRACT_SCRIPT="tar -xzvf"
local RESULT_DIR=$UTILS/$TOOLS_DIRNAME/$WGET_TOOL_DIR
local COMPILING_EXTRA_PARAMS="--without-ssl"
local MES_ARCHIVE_CHECK_FAIL="
ERROR: archive $ARCHIVE_PATH does not exist!

FAILED."
build_tool "$ARCHIVE_PATH" "$TMP_TOOL_DIR" "$EXTRACT_SCRIPT" "$RESULT_DIR" \
"$COMPILING_EXTRA_PARAMS" "$MES_ARCHIVE_CHECK_FAIL"
