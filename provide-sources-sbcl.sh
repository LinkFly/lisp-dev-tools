#!/bin/sh

##### Include scripts #####
. ./global-params.conf
. ./tools.conf
. ./utils.sh

######### Configuring variables ####
EXTRACT_SOURCES_SCRIPT=extract-sources-sbcl.sh

######### Computing variables ####
abs_path EXTRACT_SOURCES_SCRIPT
abs_path SOURCES
SBCL_LISPS_SOURCES=$SOURCES/$SBCL_LISPS_SOURCES

######## Build sbcl if needed #########
DIR=$SBCL_LISPS_SOURCES/$SBCL_SOURCES_DIRNAME

PROCESS_SCRIPT="$EXTRACT_SOURCES_SCRIPT"

MES_START_PROCESS="Providing sources $SBCL_SOURCES_DIRNAME ...
\nDirectory: $SBCL_LISPS_SOURCES/$SBCL_SOURCES_DIRNAME"

MES_ALREADY="SBCL sources already exist.
\nRun provide-sbcl.sh for ensure builded SBCL.
\nDirectory: $SBCL_LISPS_SOURCES/$SBCL_SOURCES_DIRNAME"

MES_SUCCESS="Providing SBCL $SBCL_SOURCES_DIRNAME successful.
\nDirectory: $SBCL_LISPS_SOURCES/$SBCL_SOURCES_DIRNAME"

MES_FAILED="ERROR: Providing SBCL $SBCL_SOURCES_DIRNAME failed.
\nDirectory that has not been created: $SBCL_LISPS_SOURCES/$SBCL_SOURCES_DIRNAME"

provide_dir "$DIR" "$PROCESS_SCRIPT" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"
