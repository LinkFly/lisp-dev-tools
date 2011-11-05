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

######## Build sbcl if needed #########
echo "Providing SBCL compiler $SBCL_COMPILER_DIRNAME ...
Directory: $SBCL_LISPS_COMPILERS";
if [ -d $SBCL_LISPS_COMPILERS/$SBCL_COMPILER_DIRNAME ];
then echo "SBCL compiler already exist (run build-sbcl.sh for building SBCL sources).";
else $EXTRACT_COMPILER_SCRIPT && echo "Providing SBCL compiler $SBCL_COMPILER_DIRNAME successful.
Directory: $SBCL_LISPS_COMPILERS/$SBCL_COMPILER_DIRNAME";
fi


