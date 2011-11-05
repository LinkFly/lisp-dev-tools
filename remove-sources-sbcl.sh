#!/bin/sh

######## Include scripts ###########
. ./global-params.conf
. ./tools.conf
. ./utils.sh

######### Computing variables ######
abs_path SOURCES
SBCL_LISPS_SOURCES=$SOURCES/$SBCL_LISPS_SOURCES

######### Removing if is exist #####
if [ -d $SBCL_LISPS_SOURCES/$SBCL_SOURCES_DIRNAME ];
then rm -r $SBCL_LISPS_SOURCES/$SBCL_SOURCES_DIRNAME && echo "$SBCL_SOURCES_DIRNAME removed successful.
Directory: $SBCL_LISPS_SOURCES/$SBCL_SOURCES_DIRNAME";
else echo "$SBCL_SOURCES_DIRNAME removed failed.
Directory: $SBCL_LISPS_SOURCES/$SBCL_SOURCES_DIRNAME";
fi

