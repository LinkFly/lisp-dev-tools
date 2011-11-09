#!/bin/sh

### Includes ###
. ./includes.sh

######### Computing variables ####
abs_path UTILS
abs_path TMP

### Call build_tool ###
local ARCHIVE_PATH=$PREFIX/$WGET_ARCHIVE
local TMP_TOOL_DIR=$TMP/wget-compiling
local EXTRACT_SCRIPT="tar -xzvf"
local RESULT_DIR=$UTILS/$TOOLS_DIRNAME/$WGET_TOOL_DIR
local COMPILING_EXTRA_PARAMS="--without-ssl"
build_tool "$ARCHIVE_PATH" "$TMP_TOOL_DIR" "$EXTRACT_SCRIPT" "$RESULT_DIR" "$COMPILING_EXTRA_PARAMS"