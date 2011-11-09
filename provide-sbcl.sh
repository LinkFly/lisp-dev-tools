#!/bin/sh

##### Include scripts #####
. ./includes.sh

######### Configuring variables ####
local PROVIDE_ARCHIVE_SBCL_BIN=provide-archive-sbcl-bin.sh
local PROVIDE_COMPILER_SBCL=provide-compiler-sbcl.sh
local PROVIDE_ARCHIVE_SBCL_SOURCE=provide-archive-sbcl-src.sh
local PROVIDE_SOURCES_SBCL=provide-sources-sbcl.sh
local PROVIDE_BUILD_SCRIPT=provide-build-sbcl.sh
local PROVIDE_PREBUILD_SCRIPT=provide-prebuilded-sbcl.sh
local BUILD_OR_PREBUILD_SCRIPT #computing latter
######### Computing variables ####
abs_path SBCL_DIR
abs_path PROVIDE_ARCHIVE_SBCL_BIN
abs_path PROVIDE_COMPILER_SBCL
abs_path PROVIDE_ARCHIVE_SBCL_SOURCE
abs_path PROVIDE_SOURCES_SBCL
abs_path PROVIDE_BUILD_SCRIPT
abs_path PROVIDE_PREBUILD_SCRIPT
abs_path SOURCES

if [ "$SBCL_NO_BUILDING" = "yes" ];
then BUILD_OR_PREBUILD_SCRIPT=$PROVIDE_PREBUILD_SCRIPT;
else BUILD_OR_PREBUILD_SCRIPT=$PROVIDE_BUILD_SCRIPT;
fi

######## Download compiler, get compiler, download ################
######## sources, get sources and building sbcl if needed #########
DIR=$SBCL_DIR

PROCESS_SCRIPT="$PROVIDE_ARCHIVE_SBCL_BIN && $PROVIDE_COMPILER_SBCL && $PROVIDE_ARCHIVE_SBCL_SOURCE && $PROVIDE_SOURCES_SBCL && $BUILD_OR_PREBUILD_SCRIPT"

MES_START_PROCESS="
Providing SBCL $SBCL_DIRNAME ...
Directory for results: $SBCL_DIR"

MES_ALREADY="
SBCL already exist.
Run run-sbcl.sh for using, or run rebuild-sbcl.sh for retry build). 
Directory: $SBCL_DIR

OK.";

MES_SUCCESS="
SBCL $SBCL_DIRNAME provided successful.
Directory: $SBCL_DIR

OK."

MES_FAILED="ERROR: SBCL $SBCL_DIRNAME provided failed.
Directory that has not been created: $SBCL_DIR" 

provide_dir "$DIR" "$PROCESS_SCRIPT" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"
