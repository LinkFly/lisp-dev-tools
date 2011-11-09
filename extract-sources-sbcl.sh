#!/bin/sh

##### Include scripts #####
. ./global-params.conf
. ./tools.conf
. ./utils.sh

######### Configuring and computing variables ####
abs_path ARCHIVES
abs_path SOURCES
SBCL_LISPS_SOURCES=$SOURCES/$SBCL_LISPS_SOURCES
SBCL_SOURCE_ARCHIVE=$ARCHIVES/$SBCL_SOURCE_ARCHIVE
EXTRACT_CMD="tar --directory $SBCL_LISPS_SOURCES -xjvf"

################# Extracted SBCL sources #########
mkdir --parents $SBCL_LISPS_SOURCES
echo "Extracting SBCL sources from $SBCL_SOURCE_ARCHIVE ...
Directory with archives: $ARCHIVES"

### Call extract_arhcive function ###
EXTRACT_CMD=$EXTRACT_CMD
ARCHIVE=$SBCL_SOURCE_ARCHIVE
RESULT_DIR=$SBCL_LISPS_SOURCES/$SBCL_SOURCES_DIRNAME

MES_CHECK_ALREADY_FAIL="ERROR: SBCL sources already the existing.
\nDirectory with sources: $RESULT_DIR
\nDirectory with archives: $ARCHIVES"

MES_CHECK_AR_FAIL="ERROR: Archive $ARCHIVE not found.
\nDirectory with archives: $ARCHIVES
\nPlease ensure the existence of the archive, for this run the:
\n
\nprovide-archive.sh <archive-name> <url>
\n
\nFAILED."

MES_START_EXTRACTED="Extracting from $ARCHIVE  ..."
MES_CHECK_RES_FAIL="ERROR: Extracted $SBCL_SOURCE_ARCHIVE failed.
\nDirectory with archives: $ARCHIVES"
MES_CHECK_RES_SUCC="Extracted $ARCHIVE successful.
\nDirectory with result: $RESULT_DIR
\nOK."

extract_archive "$EXTRACT_CMD" "$ARCHIVE" "$RESULT_DIR" \
"$MES_CHECK_ALREADY_FAIL" "$MES_CHECK_AR_FAIL" \
"$MES_START_EXTRACTED" "$MES_CHECK_RES_FAIL" "$MES_CHECK_RES_SUCC"
 