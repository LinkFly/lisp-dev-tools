#!/bin/sh
cd "$(dirname "$0")"
. ./includes.sh

######### Configuring variables ####
EXTRACT_SOURCES_SCRIPT=$SCRIPTS_DIR/extract-sources-lisp.sh
LISPS_SOURCES=$SOURCES/$LISP_LISPS_SOURCES
LISP_SOURCES_PATH=$LISPS_SOURCES/$LISP_SOURCES_DIRNAME
CUR_LISP_UP=$(uppercase $CUR_LISP)

######## Build lisp if needed #########
DIR=$LISP_SOURCES_PATH

PROCESS_SCRIPT="$EXTRACT_SOURCES_SCRIPT"

MES_START_PROCESS="
Providing sources $LISP_SOURCES_DIRNAME ...
Directory: $LISP_SOURCES_PATH"

MES_ALREADY="
$CUR_LISP_UP sources already exist.
Run provide-lisp.sh for ensure builded $CUR_LISP_UP.
Directory: $LISP_SOURCES_PATH

ALREADY."

MES_SUCCESS="
Providing sources $CUR_LISP_UP $LISP_SOURCES_DIRNAME successful.
Directory: $LISP_SOURCES_PATH

OK."

MES_FAILED="
ERROR: Providing $CUR_LISP_UP $LISP_SOURCES_DIRNAME failed.
Directory that has not been created: $LISP_SOURCES_PATH

FAILED."

provide_dir "$DIR" "$PROCESS_SCRIPT" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"
