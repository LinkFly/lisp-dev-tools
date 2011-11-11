#!/bin/sh

##### Include scripts #####
. ./includes.sh
. ./core.sh

######### Configuring variables #######
BUILD_SCRIPT=prebuild-lisp.sh

########## Computing variables ########
abs_path LISP_DIR
abs_path BUILD_SCRIPT

local CUR_LISP_UP=$(uppercase $CUR_LISP)

########## Building sbcl if needed ####
DIR=$LISP_DIR

PROCESS_SCRIPT=$BUILD_SCRIPT

MES_START_PROCESS="
Providing pre-builded $CUR_LISP_UP $LISP_COMPILER_DIRNAME ...
Directory for coping pre-build results: $LISP_DIR"

MES_ALREADY="
$CUR_LISP_UP files into $LISP_DIRNAME already existing.
Directory: $LISP_DIR

ALREADY.";

MES_SUCCESS="
Providing pre-builded $CUR_LISP_UP $LISP_DIRNAME successful.
Directory: $LISP_DIR

OK."

MES_FAILED="
Providing pre-builded $CUR_LISP_UP $LISP_DIRNAME failed.
Directory (that has not been created): $LISP_DIR

FAILED."

provide_dir "$DIR" "$PROCESS_SCRIPT" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"