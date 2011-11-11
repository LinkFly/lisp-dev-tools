#!/bin/sh

##### Include scripts #####
. ./includes.sh
. ./core.sh

######### Configuring and computing variables ####

LISPS_SOURCES_PATH=$SOURCES/$LISP_LISPS_SOURCES
LISP_SOURCE_ARCHIVE_PATH=$ARCHIVES/$LISP_SOURCE_ARCHIVE
if [ "$LISP_ARCHIVE_TYPE" = "gzip" ]; then ARCHIVE_TYPE=z; fi
if [ "$LISP_ARCHIVE_TYPE" = "bzip2" ]; then ARCHIVE_TYPE=j; fi
EXTRACT_CMD="tar -x${ARCHIVE_TYPE}vf"
CUR_LISP_UP=$(uppercase $CUR_LISP)

################# Extracted LISP sources #########
mkdir --parents $LISPS_SOURCES_PATH
echo "
Extracting $CUR_LISP_UP sources from $LISP_SOURCE_ARCHIVE_PATH ...
Directory with archives: $ARCHIVES"

### Call extract_arhcive function ###
EXTRACT_CMD=$EXTRACT_CMD
ARCHIVE=$LISP_SOURCE_ARCHIVE_PATH
RESULT_DIR=$LISPS_SOURCES_PATH/$LISP_SOURCES_DIRNAME

MES_CHECK_ALREADY_FAIL="
ERROR: $CUR_LISP_UP sources already the existing.
Run remove-sources-lisp.sh and retry extracting.
Directory with sources: $RESULT_DIR
Directory with archives: $ARCHIVES

ALREADY."

MES_CHECK_AR_FAIL="
ERROR: Archive $ARCHIVE not found.
Directory with archives: $ARCHIVES
Please ensure the existence of the archive, for this run the:

provide-archive.sh <archive-name> <url>

FAILED."

MES_START_EXTRACTED="
Extracting from $ARCHIVE  ..."

MES_CHECK_RES_FAIL="
ERROR: Extracted $LISP_SOURCE_ARCHIVE_PATH failed.
Directory with archives: $ARCHIVES

FAILED."

MES_CHECK_RES_SUCC="
Extracted $ARCHIVE successful.
Directory (with result): $RESULT_DIR

OK."

extract_archive "$EXTRACT_CMD" "$ARCHIVE" "$RESULT_DIR" \
"$MES_CHECK_ALREADY_FAIL" "$MES_CHECK_AR_FAIL" \
"$MES_START_EXTRACTED" "$MES_CHECK_RES_FAIL" "$MES_CHECK_RES_SUCC"
