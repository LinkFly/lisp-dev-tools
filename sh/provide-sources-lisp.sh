#!/bin/sh

##### Include scripts #####
. ./includes.sh
. ./core.sh

######### Configuring variables ####
EXTRACT_SOURCES_SCRIPT=extract-sources-lisp.sh

######### Computing variables ####
abs_path EXTRACT_SOURCES_SCRIPT
abs_path SOURCES
local LISPS_SOURCES=$SOURCES/$LISP_LISPS_SOURCES
local LISP_SOURCES_PATH=$LISPS_SOURCES/$LISP_SOURCES_DIRNAME

local CUR_LISP_UP=$(uppercase $CUR_LISP)
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
Providing $CUR_LISP_UP $LISP_SOURCES_DIRNAME successful.
Directory: $LISP_SOURCES_PATH

OK."

MES_FAILED="
ERROR: Providing $CUR_LISP_UP $LISP_SOURCES_DIRNAME failed.
Directory that has not been created: $LISP_SOURCES_PATH

FAILED."

provide_dir "$DIR" "$PROCESS_SCRIPT" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"
