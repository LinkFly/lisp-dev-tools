#!/bin/sh

######## Include scripts ###########
. ./global-params.conf
. ./tools.conf
. ./utils.sh

######### Computing variables ######
abs_path COMPILERS
SBCL_LISPS_COMPILERS=$COMPILERS/$SBCL_LISPS_COMPILERS
SBCL_COMPILER_DIR=$SBCL_LISPS_COMPILERS/$SBCL_COMPILER_DIRNAME

######### Removing if is exist #####

### Call remove_dir ###
DIR=$SBCL_COMPILER_DIR
MES_SUCC="
$SBCL_SOURCES_DIRNAME removed successful.
Directory with compiler: $SBCL_COMPILER_DIR

OK."

MES_FAIL="$SBCL_SOURCES_DIRNAME removed failed.
Directory with compiler: $SBCL_COMPILER_DIR
FAILED."

MES_ABSENCE="
SBCL compiler $SBCL_COMPILER_DIRNAME already does not exist.
Directory with SBCL compilers: $SBCL_LISPS_COMPILERS

NOT EXIST."

remove_dir "$DIR" "$MES_SUCC" "$MES_FAIL" "$MES_ABSENCE"


