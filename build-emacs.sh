#!/bin/sh

### Includes ###
. ./includes.sh

######### Computing variables ####
abs_path ARCHIVES
abs_path UTILS
abs_path TMP

### Call build_tool ###
local ARCHIVE_PATH=$ARCHIVES/$EMACS_ARCHIVE
local TMP_TOOL_DIR=$TMP/emacs-compiling
local EXTRACT_SCRIPT="tar -xzvf"
local RESULT_DIR=$UTILS/$TOOLS_DIRNAME/$EMACS_TOOL_DIR
local COMPILING_EXTRA_PARAMS="--without-gui"
local MES_ARCHIVE_CHECK_FAIL="
ERROR: archive $ARCHIVE_PATH does not exist!

FAILED."
build_tool "$ARCHIVE_PATH" "$TMP_TOOL_DIR" "$EXTRACT_SCRIPT" "$RESULT_DIR" \
"$COMPILING_EXTRA_PARAMS" "$MES_ARCHIVE_CHECK_FAIL"
