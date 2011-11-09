#!/bin/sh

######## Include scripts ###########
. ./global-params.conf
. ./tools.conf
. ./utils.sh

######### Computing variables ######
abs_path SOURCES
SBCL_LISPS_SOURCES=$SOURCES/$SBCL_LISPS_SOURCES
SBCL_SOURCES_DIR=
######### Removing if is exist #####

### Call remove_dir ###
DIR=$SBCL_COMPILER_DIR
MES_SUCC="$SBCL_SOURCES_DIRNAME removed successful.
Directory with compiler: $SBCL_COMPILER_DIR"

MES_FAIL="$SBCL_SOURCES_DIRNAME removed failed.
Directory with compiler: $SBCL_COMPILER_DIR"

MES_ABSENCE="SBCL compiler $SBCL_COMPILER_DIRNAME already does not exist.
Directory with SBCL compilers: $SBCL_LISPS_COMPILERS"

remove_dir "$DIR" "$MES_SUCC" "$MES_FAIL" "$MES_ABSENCE"

if [ -d $SBCL_LISPS_SOURCES/$SBCL_SOURCES_DIRNAME ];
then rm -r $SBCL_LISPS_SOURCES/$SBCL_SOURCES_DIRNAME && echo "$SBCL_SOURCES_DIRNAME removed successful.
Directory: $SBCL_LISPS_SOURCES/$SBCL_SOURCES_DIRNAME";
else echo "$SBCL_SOURCES_DIRNAME removed failed.
Directory: $SBCL_LISPS_SOURCES/$SBCL_SOURCES_DIRNAME";
fi

