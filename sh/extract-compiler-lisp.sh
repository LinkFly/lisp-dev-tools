#!/bin/sh
cd $(dirname $0)
. ./includes.sh

######### Configuring and computing variables ####
LISPS_COMPILERS=$COMPILERS/$LISP_LISPS_COMPILERS
COMPILER_ARCHIVE=$ARCHIVES/$LISP_BIN_ARCHIVE
EXTRACT_CMD="tar -xjvf"

local CUR_LISP_UP=$(uppercase $CUR_LISP)

################# Extracted LISP sources #########
mkdir --parents $LISPS_COMPILERS
echo "
Extracting $CUR_LISP_UP compiler from $LISP_BIN_ARCHIVE ...
Directory with archives: $ARCHIVES"

### Call extract_arhcive function ###
EXTRACT_CMD=$EXTRACT_CMD
ARCHIVE=$COMPILER_ARCHIVE
RESULT_DIR=$LISPS_COMPILERS/$LISP_COMPILER_DIRNAME

MES_CHECK_ALREADY_FAIL="
$CUR_LISP_UP compiler $LISP_COMPILER_DIRNAME already the existing.
Directory with compilers: $LISPS_COMPILERS
Directory with archives: $ARCHIVES

ALREADY."

MES_CHECK_AR_FAIL="
ERROR: Archive $ARCHIVE not found.
Directory with archives: $ARCHIVES
Please ensure the existence of the archive, for this run the:

provide-archive.sh <archive-name> <url>

FAILED."

MES_START_EXTRACTED="Extracting from $ARCHIVE  ..."

MES_CHECK_RES_FAIL="
ERROR: Extracted $ARCHIVE failed.
Directory with archives: $ARCHIVES

FAILED."

MES_CHECK_RES_SUCC="
Extracted $ARCHIVE successful.
Directory with result: $RESULT_DIR

OK."

ARCHIVE_LOWERING_P=$LISP_BIN_ARCHIVE_LOWERING_P

extract_archive "$EXTRACT_CMD" "$ARCHIVE" "$RESULT_DIR" \
    "$MES_CHECK_ALREADY_FAIL" "$MES_CHECK_AR_FAIL" \
    "$MES_START_EXTRACTED" "$MES_CHECK_RES_FAIL" \
    "$MES_CHECK_RES_SUCC" "$ARCHIVE_LOWERING_P"
 