#!/bin/sh

##### Parameters #####
SRC_OR_BIN=$1

##### Include scripts #####
. ./global-params.conf
. ./tools.conf
. ./utils.sh

######### Configuring variables ####
PROVIDE_ARCHIVE_SCRIPT=provide-archive.sh

######### Computing variables ######
abs_path PROVIDE_ARCHIVE_SCRIPT
abs_path ARCHIVES

######## Checking  parameters ######
ARGS="$SRC_OR_BIN"
ARGS_NEED="src bin"
MES_CHECK_START="Checking argument for $0 ..."
MES_SUCCESS="OK"
MES_FAILED="ERROR: checking params failed - first argument must be \"src\" or \"bin\"!"
check_args "$ARGS" "$ARGS_NEED" "$MES_CHECK_START" "$MES_SUCCESS" "$MES_FAILED" || return 1

######## Computing variables #######
if [ $SRC_OR_BIN = "src" ];
then 
ARCHIVE_TYPE=sources; 
ARCHIVE_FILE=$SBCL_SOURCE_ARCHIVE;
ARCHIVE_URL=$SBCL_SOURCE_URL;
fi

if [ $SRC_OR_BIN = "bin" ];
then
ARCHIVE_TYPE=binary;
ARCHIVE_FILE=$SBCL_BIN_ARCHIVE;
ARCHIVE_URL=$SBCL_BIN_URL;
fi

######## Providing sbcl archive if needed #########
DIR=$SBCL_DIR

PROCESS_SCRIPT="$PROVIDE_ARCHIVE_SCRIPT $ARCHIVE_FILE $ARCHIVE_URL"

MES_START_PROCESS="Providing SBCL $ARCHIVE_TYPE archive $ARCHIVE_FILE ...
\nDirectory with archives: $ARCHIVES"

MES_ALREADY="SBCL $ARCHIVE_TYPE archive $ARCHIVE_FILE already exist.
\nDirectory with archives: $ARCHIVES"

MES_SUCCESS="Providing SBCL $ARCHIVE_TYPE archive $ARCHIVE_FILE successful.
\nDirectory with archives: $ARCHIVES"

MES_FAILED="ERROR: providing SBCL $ARCHIVE_TYPE archive!"

provide_dir "$DIR" "$PROCESS_SCRIPT" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"

