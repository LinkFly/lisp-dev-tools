#!/bin/sh

##### Include scripts #####
. ./global-params.conf
. ./tools.conf
. ./utils.sh

######### Configuring variables ####
EXTRACT_COMPILER_SCRIPT=extract-compiler-sbcl.sh

######### Computing variables ####
abs_path EXTRACT_COMPILER_SCRIPT
abs_path COMPILERS
SBCL_LISPS_COMPILERS=$COMPILERS/$SBCL_LISPS_COMPILERS

######## Providing SBCL binary for compilation if needed #########
DIR=$SBCL_LISPS_COMPILERS/$SBCL_COMPILER_DIRNAME

PROCESS_SCRIPT="$EXTRACT_COMPILER_SCRIPT"

MES_START_PROCESS="
Providing SBCL compiler $SBCL_COMPILER_DIRNAME ...
Directory for SBCL compilers: $SBCL_LISPS_COMPILERS";

MES_ALREADY="
SBCL compiler $SBCL_COMPILER_DIRNAME already exist.
Run build-sbcl.sh for building SBCL sources.
Directory: $SBCL_LISPS_COMPILERS/$SBCL_COMPILER_DIRNAME

ALREADY.";

MES_SUCCESS="
Providing SBCL compiler $SBCL_COMPILER_DIRNAME successful.
Directory: $SBCL_LISPS_COMPILERS/$SBCL_COMPILER_DIRNAME

OK."

MES_FAILED="
ERROR: Providing SBCL compiler $SBCL_COMPILER_DIRNAME failed.
Directory that has not been created: $SBCL_LISPS_COMPILERS/$SBCL_COMPILER_DIRNAME

FAILED." 

provide_dir "$DIR" "$PROCESS_SCRIPT" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"




