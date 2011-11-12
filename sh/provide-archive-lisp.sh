#!/bin/sh
cd $(dirname $0)
. ./includes.sh

##### Parameters #####
SRC_OR_BIN=$1

######## Checking  parameters ######
ARGS="$SRC_OR_BIN"
ARGS_NEED="src bin"
MES_CHECK_START="\nChecking argument '$SRC_OR_BIN' for $0 ... "
MES_SUCCESS="ok."
MES_FAILED="ERROR: checking params failed - first argument must be \"src\" or \"bin\"!"
check_args "$ARGS" "$ARGS_NEED" "$MES_CHECK_START" "$MES_SUCCESS" "$MES_FAILED" || return 1

######### Configuring variables ####
local PROVIDE_ARCHIVE_SCRIPT=provide-archive.sh

######### Computing variables ######
abs_path PROVIDE_ARCHIVE_SCRIPT

######## Computing variables #######
if [ $SRC_OR_BIN = "src" ];
then 
ARCHIVE_TYPE=sources; 
ARCHIVE_FILE=$LISP_SOURCE_ARCHIVE;
ARCHIVE_URL=$LISP_SOURCE_URL;
RENAME_DOWNLOAD=$LISP_RENAME_SRC_DOWNLOAD
fi

if [ $SRC_OR_BIN = "bin" ];
then
ARCHIVE_TYPE=binary;
ARCHIVE_FILE=$LISP_BIN_ARCHIVE;
ARCHIVE_URL=$LISP_BIN_URL;
RENAME_DOWNLOAD=$LISP_RENAME_BIN_DOWNLOAD
fi

local CUR_LISP_UP=$(uppercase $CUR_LISP)
######## Providing lisp archive if needed #########
FILE=$LISP_DIR

PROCESS_SCRIPT="$PROVIDE_ARCHIVE_SCRIPT $ARCHIVE_FILE $ARCHIVE_URL $RENAME_DOWNLOAD"

MES_START_PROCESS="
Providing $CUR_LISP_UP $ARCHIVE_TYPE archive $ARCHIVE_FILE ...
Directory with archives: $ARCHIVES"

MES_ALREADY="
$CUR_LISP_UP $ARCHIVE_TYPE archive $ARCHIVE_FILE already exist.
Directory with archives: $ARCHIVES

OK."

MES_SUCCESS="
Providing $CUR_LISP_UP $ARCHIVE_TYPE archive $ARCHIVE_FILE successful.
Directory with archives: $ARCHIVES

OK."

MES_FAILED="ERROR: providing $CUR_LISP_UP $ARCHIVE_TYPE archive!"

provide_file "$FILE" "$PROCESS_SCRIPT" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"

