#!/bin/sh

##### Include scripts #####
. ./global-params.conf
. ./tools.conf
. ./utils.sh

######### Configuring variables ####
EXTRACT_CMD="tar -xjvf"

######### Computing variables ####
abs_path ARCHIVES
abs_path SOURCES
SBCL_LISPS_SOURCES=$SOURCES/$SBCL_LISPS_SOURCES
SBCL_SOURCE_ARCHIVE=$ARCHIVES/$SBCL_SOURCE_ARCHIVE

##### Checking existing sbcl archive #######
if [ -f $SBCL_SOURCE_ARCHIVE ];
then echo "Checking existing archive $SBCL_SOURCE_ARCHIVE successful. Extracting ...";
else echo "Checking existing archive $SBCL_SOURCE_ARCHIVE failed. Please ensure the existence of the archive."
fi

##### Getting sbcl compiler #######
mkdir --parents $SBCL_LISPS_SOURCES
cd $SBCL_LISPS_SOURCES
$EXTRACT_CMD $SBCL_SOURCE_ARCHIVE

##### Checking of extracted #######
if [ -d $SBCL_LISPS_SOURCES/$SBCL_SOURCES_DIRNAME ];
then echo "Extracted $SBCL_SOURCE_ARCHIVE successful."; 
else echo "Extracted $SBCL_SOURCE_ARCHIVE failed"; return -1;
fi
