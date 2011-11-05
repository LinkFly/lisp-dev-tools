#!/bin/sh

##### Include scripts #####
. ./global-params.conf
. ./tools.conf
. ./utils.sh

######### Configuring variables ####
EXTRACT_SOURCES_SCRIPT=extract-sources-sbcl.sh

######### Computing variables ####
abs_path EXTRACT_SOURCES_SCRIPT
abs_path SOURCES
SBCL_LISPS_SOURCES=$SOURCES/$SBCL_LISPS_SOURCES

######## Build sbcl if needed #########
echo "Providing sources $SBCL_SOURCES_DIRNAME ...
Directory: $SBCL_LISPS_SOURCES"
if [ -d $SBCL_LISPS_SOURCES/$SBCL_SOURCES_DIRNAME ];
then echo "SBCL sources already exist (run provide-sbcl.sh for ensure builded SBCL)."
else $EXTRACT_SOURCES_SCRIPT && echo "Providing SBCL $SBCL_SOURCES_DIRNAME successful.
Directory: $SBCL_LISPS_SOURCES/$SBCL_SOURCES_DIRNAME";
fi


