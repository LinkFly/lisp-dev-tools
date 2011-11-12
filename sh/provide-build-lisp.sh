#!/bin/sh
cd $(dirname $0)
. ./includes.sh

######### Configuring variables #######
BUILD_SCRIPT=build-lisp.sh

########## Computing variables ########
abs_path LISP_DIR
abs_path BUILD_SCRIPT

local CUR_LISP_UP=$(uppercase $CUR_LISP)
########## Building sbcl if needed ####
DIR=$LISP_DIR

PROCESS_SCRIPT=$BUILD_SCRIPT

MES_START_PROCESS="
Providing builded $CUR_LISP_UP $LISP_DIRNAME ...
Directory for build results: $LISP_DIR"

MES_ALREADY="
$CUR_LISP_UP already builded. Run rebuild-lisp.sh for rebuilding.
Directory: $LISP_DIR

ALREADY.";

MES_SUCCESS="
Providing builded $CUR_LISP_UP $LISP_DIRNAME successful.
Directory: $LISP_DIR

OK."

MES_FAILED="
Providing builded $CUR_LISP_UP $LISP_DIRNAME failed.
Directory that has not been created: $LISP_DIR

FAILED."

provide_dir "$DIR" "$PROCESS_SCRIPT" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"