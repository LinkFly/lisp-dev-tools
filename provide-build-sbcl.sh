#!/bin/sh

##### Include scripts #####
. ./includes.sh

######### Configuring variables #######
BUILD_SCRIPT=build-sbcl.sh

########## Computing variables ########
abs_path SBCL_DIR
abs_path BUILD_SCRIPT

########## Building sbcl if needed ####
DIR=$SBCL_DIR

PROCESS_SCRIPT=$BUILD_SCRIPT

MES_START_PROCESS="Providing builded SBCL $SBCL_DIRNAME ...
\nDirectory for build results: $SBCL_DIR"

MES_ALREADY="SBCL already builded. Run rebuild-sbcl.sh for rebuilding.
\nDirectory: $SBCL_DIR";

MES_SUCCESS="Providing builded SBCL $SBCL_DIRNAME successful.
\nDirectory: $SBCL_DIR"

MES_FAILED="Providing builded SBCL $SBCL_DIRNAME failed.
\nDirectory that has not been created: $SBCL_DIR"

provide_dir "$DIR" "$PROCESS_SCRIPT" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"