#!/bin/sh
cd $(dirname $0)
. ./includes.sh

######### Configuring variables #######
local BUILD_SCRIPT=$SCRIPTS_DIR/build-lisp.sh
local PROVIDE_M4_SCRIPT=$SCRIPTS_DIR/provide-m4.sh

########## Computing variables ########
abs_path LISP_DIR

local CUR_LISP_UP=$(uppercase $CUR_LISP)

###### Provide m4 ######
$PROVIDE_M4_SCRIPT

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
ERROR: Providing builded $CUR_LISP_UP $LISP_DIRNAME failed.
Directory (not been created): $LISP_DIR

FAILED."

provide_dir "$DIR" "$PROCESS_SCRIPT" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"