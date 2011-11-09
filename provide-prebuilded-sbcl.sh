#!/bin/sh

##### Include scripts #####
. ./includes.sh

######### Configuring variables #######
BUILD_SCRIPT=prebuild-sbcl.sh

########## Computing variables ########
abs_path SBCL_DIR
abs_path BUILD_SCRIPT
abs_path COMPILERS

########## Building sbcl if needed ####
DIR=$SBCL_DIR

PROCESS_SCRIPT=$BUILD_SCRIPT

MES_START_PROCESS="
Providing pre-builded SBCL $SBCL_COMPILER_DIRNAME ...
Directory for coping pre-build results: $SBCL_DIR"

MES_ALREADY="
SBCL files into $SBCL_DIRNAME already existing.
Directory: $SBCL_DIR

ALREADY.";

MES_SUCCESS="
Providing pre-builded SBCL $SBCL_DIRNAME successful.
Directory: $SBCL_DIR

OK."

MES_FAILED="
Providing pre-builded SBCL $SBCL_DIRNAME failed.
Directory (that has not been created): $SBCL_DIR

FAILED."

provide_dir "$DIR" "$PROCESS_SCRIPT" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"