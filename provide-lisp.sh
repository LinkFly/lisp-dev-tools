#!/bin/sh

##### Include scripts #####
. ./includes.sh
. ./core.sh

######### Configuring variables ####
local PROVIDE_ARCHIVE_LISP_BIN=provide-archive-lisp-bin.sh
local PROVIDE_COMPILER_LISP=provide-compiler-lisp.sh
local PROVIDE_ARCHIVE_LISP_SOURCE=provide-archive-lisp-src.sh
local PROVIDE_SOURCES_LISP=provide-sources-lisp.sh
local PROVIDE_BUILD_SCRIPT=provide-build-lisp.sh
local PROVIDE_PREBUILD_SCRIPT=provide-prebuilded-lisp.sh
local BUILD_OR_PREBUILD_SCRIPT #computing latter
######### Computing variables ####
abs_path LISP_DIR
abs_path PROVIDE_ARCHIVE_LISP_BIN
abs_path PROVIDE_COMPILER_LISP
abs_path PROVIDE_ARCHIVE_LISP_SOURCE
abs_path PROVIDE_SOURCES_LISP
abs_path PROVIDE_BUILD_SCRIPT
abs_path PROVIDE_PREBUILD_SCRIPT
abs_path SOURCES

local CUR_LISP_UP=$(uppercase $CUR_LISP)
if [ "$LISP_NO_BUILDING" = "yes" ];
then BUILD_OR_PREBUILD_SCRIPT=$PROVIDE_PREBUILD_SCRIPT;
else BUILD_OR_PREBUILD_SCRIPT=$PROVIDE_BUILD_SCRIPT;
fi

######## Download compiler, get compiler, download ################
######## sources, get sources and building lisp if needed #########
DIR=$LISP_DIR

PROCESS_SCRIPT="$PROVIDE_ARCHIVE_LISP_BIN && $PROVIDE_COMPILER_LISP && $PROVIDE_ARCHIVE_LISP_SOURCE && $PROVIDE_SOURCES_LISP && $BUILD_OR_PREBUILD_SCRIPT"

MES_START_PROCESS="
Providing $CUR_LISP_UP $LISP_DIRNAME ...
Directory for results: $LISP_DIR"

MES_ALREADY="
$CUR_LISP_UP already exist.
Run run-lisp.sh for using, or run rebuild-lisp.sh for retry build). 
Directory: $LISP_DIR

OK.";

MES_SUCCESS="
$CUR_LISP_UP $LISP_DIRNAME provided successful.
Directory: $LISP_DIR

OK."

MES_FAILED="ERROR: LISP $LISP_DIRNAME provided failed.
Directory that has not been created: $LISP_DIR

FAILED." 

provide_dir "$DIR" "$PROCESS_SCRIPT" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"
