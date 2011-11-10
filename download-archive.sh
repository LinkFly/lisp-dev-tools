#!/bin/sh
echo "
Running download-archive.sh ..."

######### Parameters ###############
URL=$1

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
PROVIDE_LOADER=provide-wget.sh
LOADER=wget

######### Computing variables ######
abs_path PROVIDE_LOADER
abs_path UTILS
LOADER=$UTILS/$LOADER

########## Downloading #############
$PROVIDE_LOADER
echo "URL: $URL"
$LOADER $URL

echo "End running download-archive.sh"