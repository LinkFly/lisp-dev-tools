#!/bin/sh
echo "
Running download-archive.sh ..."

######### Parameters ###############
URL=$1
RENAME_DOWNLOAD=$2

######## Include scripts ###########
#. $(dirname $0)/global-params.conf
#. $(dirname $0)/utils.sh
local D=\$
local CUR_PATH=$PWD
local TMP_PATH=$CUR_PATH
cd $(dirname $0)
. ./includes.sh
. ./core.sh
cd $TMP_PATH

######### Configuring variables ####
local PROVIDE_LOADER=provide-wget.sh
local LOADER=wget
local EXTRA_PARAMS

######### Computing variables ######
abs_path PROVIDE_LOADER
abs_path UTILS
LOADER=$UTILS/$LOADER

if ! [ "$RENAME_DOWNLOAD" = "" ];
then EXTRA_PARAMS="--output-document $RENAME_DOWNLOAD"; 
fi

########## Downloading #############
$PROVIDE_LOADER
echo "URL: $URL"
$LOADER $URL $EXTRA_PARAMS

echo "End running download-archive.sh"