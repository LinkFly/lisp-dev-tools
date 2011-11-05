#!/bin/sh

##### Include scripts #####
. ./global-params.conf
. ./tools.conf
. ./utils.sh

######### Configuring variables ####
EXTRACT_CMD="tar -xjvf"

######### Computing variables ####
abs_path ARCHIVES
abs_path COMPILERS
SBCL_LISPS_COMPILERS=$COMPILERS/$SBCL_LISPS_COMPILERS
SBCL_COMPILER_ARCHIVE=$ARCHIVES/$SBCL_BIN_ARCHIVE

##### Checking existing sbcl archive #######
if [ -f $SBCL_COMPILER_ARCHIVE ];
then echo "Checking existing SBCL compiler archive $SBCL_COMPILER_ARCHIVE successful. Extracting ...";
else echo "Checking existing SBCL compiler archive $SBCL_COMPILER_ARCHIVE failed. Please ensure the existence of the archive."; return 1;
fi

##### Getting sbcl compiler #######
mkdir --parents $SBCL_LISPS_COMPILERS
cd $SBCL_LISPS_COMPILERS
$EXTRACT_CMD $SBCL_COMPILER_ARCHIVE

##### Checking of extracted #######
if [ -d $SBCL_LISPS_COMPILERS/$SBCL_COMPILER_DIRNAME ];
then echo "Extracted $SBCL_COMPILER_DIRNAME successful.
Directory: $SBCL_LISPS_COMPILERS/$SBCL_COMPILER_DIRNAME"; 
else echo "Extracted $SBCL_COMPILER_DIRNAME failed
Archive file: $SBCL_COMPILER_ARCHIVE"; return 1;
fi
