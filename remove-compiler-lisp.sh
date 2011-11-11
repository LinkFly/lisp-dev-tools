#!/bin/sh

##### Include scripts #####
. ./includes.sh
. ./core.sh

######### Computing variables ######
local LISPS_COMPILERS=$COMPILERS/$LISP_LISPS_COMPILERS
local COMPILER_DIR=$LISPS_COMPILERS/$LISP_COMPILER_DIRNAME
local CUR_LISP_UP=$(uppercase $CUR_LISP)

######### Removing if is exist #####

### Call remove_dir ###
DIR=$COMPILER_DIR
MES_SUCC="
$LISP_SOURCES_DIRNAME removed successful.
Directory with compiler: $COMPILER_DIR

OK."

MES_FAIL="$LISP_SOURCES_DIRNAME removed failed.
Directory with compiler: $COMPILER_DIR
FAILED."

MES_ABSENCE="
$CUR_LISP_UP compiler $LISP_COMPILER_DIRNAME already does not exist.
Directory with $CUR_LISP_UP compilers: $LISPS_COMPILERS

ALREADY."

remove_dir "$DIR" "$MES_SUCC" "$MES_FAIL" "$MES_ABSENCE"


