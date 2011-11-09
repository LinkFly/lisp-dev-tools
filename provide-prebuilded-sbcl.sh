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
\nProviding pre-builded SBCL $SBCL_COMPILER_DIRNAME ...
\nDirectory for coping pre-build results: $SBCL_DIR"

MES_ALREADY="
\nSBCL files into $SBCL_DIRNAME already existing.
\nDirectory: $SBCL_DIR
\n
\nALREADY.";

MES_SUCCESS="
\nProviding pre-builded SBCL $SBCL_DIRNAME successful.
\nDirectory: $SBCL_DIR
\n
\nOK."

MES_FAILED="
\nProviding pre-builded SBCL $SBCL_DIRNAME failed.
\nDirectory (that has not been created): $SBCL_DIR
\n
\nFAILED."

provide_dir "$DIR" "$PROCESS_SCRIPT" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"