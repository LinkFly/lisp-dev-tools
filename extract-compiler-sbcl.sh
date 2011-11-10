#!/bin/sh

##### Include scripts #####
. ./includes.sh
. ./core.sh

######### Configuring and computing variables ####
abs_path ARCHIVES
abs_path COMPILERS
SBCL_LISPS_COMPILERS=$COMPILERS/$SBCL_LISPS_COMPILERS
SBCL_COMPILER_ARCHIVE=$ARCHIVES/$SBCL_BIN_ARCHIVE
EXTRACT_CMD="tar --directory $SBCL_LISPS_COMPILERS -xjvf"


################# Extracted SBCL sources #########
mkdir --parents $SBCL_LISPS_COMPILERS
echo "
Extracting SBCL compiler from $SBCL_BIN_ARCHIVE ...
Directory with archives: $ARCHIVES"

### Call extract_arhcive function ###
EXTRACT_CMD=$EXTRACT_CMD
ARCHIVE=$SBCL_COMPILER_ARCHIVE
RESULT_DIR=$SBCL_LISPS_COMPILERS/$SBCL_COMPILER_DIRNAME

MES_CHECK_ALREADY_FAIL="
SBCL compiler $SBCL_COMPILER_DIRNAME already the existing.
Directory with compilers: $SBCL_LISPS_COMPILERS
Directory with archives: $ARCHIVES

Not extracted (existing)."

MES_CHECK_AR_FAIL="ERROR: Archive $ARCHIVE not found.
Directory with archives: $ARCHIVES
Please ensure the existence of the archive, for this run the:

provide-archive.sh <archive-name> <url>

FAILED."

MES_START_EXTRACTED="Extracting from $ARCHIVE  ..."
MES_CHECK_RES_FAIL="ERROR: Extracted $ARCHIVE failed.
Directory with archives: $ARCHIVES"
MES_CHECK_RES_SUCC="
Extracted $ARCHIVE successful.
Directory with result: $RESULT_DIR

OK."

extract_archive "$EXTRACT_CMD" "$ARCHIVE" "$RESULT_DIR" \
"$MES_CHECK_ALREADY_FAIL" "$MES_CHECK_AR_FAIL" \
"$MES_START_EXTRACTED" "$MES_CHECK_RES_FAIL" "$MES_CHECK_RES_SUCC"
 