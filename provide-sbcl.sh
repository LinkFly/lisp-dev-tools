#!/bin/sh

##### Include scripts #####
. ./global-params.conf
. ./tools.conf
. ./utils.sh

######### Configuring variables ####
PROVIDE_ARCHIVE_SBCL_BIN=provide-archive-sbcl-bin.sh
PROVIDE_COMPILER_SBCL=provide-compiler-sbcl.sh
PROVIDE_ARCHIVE_SBCL_SOURCE=provide-archive-sbcl-src.sh
PROVIDE_SOURCES_SBCL=provide-sources-sbcl.sh
PROVIDE_BUILD_SCRIPT=provide-build-sbcl.sh

######### Computing variables ####
abs_path SBCL_DIR
abs_path PROVIDE_ARCHIVE_SBCL_BIN
abs_path PROVIDE_COMPILER_SBCL
abs_path PROVIDE_ARCHIVE_SBCL_SOURCE
abs_path PROVIDE_SOURCES_SBCL
abs_path PROVIDE_BUILD_SCRIPT
abs_path SOURCES

######## Download compiler, get compiler, download ################
######## sources, get sources and building sbcl if needed #########
DIR=$SBCL_DIR

PROCESS_SCRIPT="$PROVIDE_ARCHIVE_SBCL_BIN && $PROVIDE_COMPILER_SBCL && $PROVIDE_ARCHIVE_SBCL_SOURCE && $PROVIDE_SOURCES_SBCL && $PROVIDE_BUILD_SCRIPT"

MES_START_PROCESS="Providing SBCL $SBCL_DIRNAME ...
\nDirectory for results: $SBCL_DIR"

MES_ALREADY="SBCL already exist.
\nRun run-sbcl.sh for using, or run rebuild-sbcl.sh for retry build). 
\nDirectory: $SBCL_DIR";

MES_SUCCESS="SBCL $SBCL_DIRNAME provided successful.
\nDirectory: $SBCL_DIR"

MES_FAILED="ERROR: SBCL $SBCL_DIRNAME provided failed.
\nDirectory that has not been created: $SBCL_DIR" 

provide_dir "$DIR" "$PROCESS_SCRIPT" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"
