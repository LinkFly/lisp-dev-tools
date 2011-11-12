#!/bin/sh

##### Include scripts #####
. ./includes.sh
. ./core.sh

######### Configuring variables ####
EXTRACT_COMPILER_SCRIPT=extract-compiler-lisp.sh

######### Computing variables ####
abs_path EXTRACT_COMPILER_SCRIPT
abs_path COMPILERS
LISPS_COMPILERS=$COMPILERS/$LISP_LISPS_COMPILERS
LISP_COMPILER_PATH=$LISPS_COMPILERS/$LISP_COMPILER_DIRNAME

local CUR_LISP_UP=$(uppercase $CUR_LISP)

######## Providing LISP binary for compilation if needed #########
DIR=$LISP_COMPILER_PATH

PROCESS_SCRIPT="$EXTRACT_COMPILER_SCRIPT"

MES_START_PROCESS="
Providing $CUR_LISP_UP compiler $LISP_COMPILER_DIRNAME ...
Directory for $CUR_LISP_UP compilers: $LISPS_COMPILERS";

MES_ALREADY="
$CUR_LISP_UP compiler $LISP_COMPILER_DIRNAME already exist.
Run build-lisp.sh for building $CUR_LISP_UP sources.
Directory: $LISP_COMPILER_PATH

ALREADY.";

MES_SUCCESS="
Providing $CUR_LISP_UP compiler $LISP_COMPILER_DIRNAME successful.
Directory: $LISP_COMPILER_PATH

OK."

MES_FAILED="
ERROR: Providing $CUR_LISP_UP compiler $LISP_COMPILER_DIRNAME failed.
Directory that has not been created: $LISP_COMPILER_PATH

FAILED." 

provide_dir "$DIR" "$PROCESS_SCRIPT" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"




