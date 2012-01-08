#!/bin/sh
cd $(dirname $0)
. ./includes.sh

##### Parameters #####
local SRC_OR_BIN=$1
if [ "$SRC_OR_BIN" = "" ]; then SRC_OR_BIN=src; fi

######## Checking  parameters ######
ARGS="$SRC_OR_BIN"
ARGS_NEED="src bin"
MES_CHECK_START="
Checking argument '$SRC_OR_BIN' for $0 ... "
MES_SUCCESS="ok."
MES_FAILED="ERROR: checking params failed - first argument must be \"src\" or \"bin\"!"
check_args "$ARGS" "$ARGS_NEED" "$MES_CHECK_START" "$MES_SUCCESS" "$MES_FAILED" || return 1

######### Parameters ###############
if [ $SRC_OR_BIN = "src" ]; then ARCHIVE_FILE=$LISP_SOURCE_ARCHIVE;fi
if [ $SRC_OR_BIN = "bin" ]; then ARCHIVE_FILE=$LISP_BIN_ARCHIVE; fi

$(dirname $0)/remove-archive.sh "$ARCHIVE_FILE"
