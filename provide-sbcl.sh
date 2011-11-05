#!/bin/sh

##### Include scripts #####
. ./global-params.conf
. ./tools.conf
. ./utils.sh

######### Configuring variables ####
PROVIDE_ARCHIVE_SBCL_BIN=provide-archive-sbcl-bin.sh
PROVIDE_COMPILER_SBCL=provide-compiler-sbcl.sh
PROVIDE_ARCHIVE_SBCL_SOURCE=provide-archive-sbcl-src.sh
PROVIDE_SOURCES_SBCL=provide-sources-sbcl.sh
BUILD_SCRIPT=build-sbcl.sh

######### Computing variables ####
abs_path SBCL_DIR
abs_path PROVIDE_ARCHIVE_SBCL_BIN
abs_path PROVIDE_COMPILER_SBCL
abs_path PROVIDE_ARCHIVE_SBCL_SOURCE
abs_path PROVIDE_SOURCES_SBCL
abs_path BUILD_SCRIPT
abs_path SOURCES

######## Build sbcl if needed #########
echo "Providing $SBCL_DIRNAME ..."
if [ -d $SBCL_DIR ];
then echo "SBCL already exist (run run-sbcl.sh for using). 
Directory: $SBCL_DIR (run remove-sbcl.sh for retry build).";
else
RESULT=1
$PROVIDE_ARCHIVE_SBCL_BIN && $PROVIDE_COMPILER_SBCL && $PROVIDE_ARCHIVE_SBCL_SOURCE && $PROVIDE_SOURCES_SBCL && $BUILD_SCRIPT && RESULT=0;
  if [ $RESULT = 0 ];
  then echo "SBCL $SBCL_DIRNAME provided successful.
Directory: $SBCL_DIR";
  else echo "ERROR: SBCL $SBCL_DIRNAME provided failed."
  fi
fi


