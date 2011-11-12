#!/bin/sh
CUR_PATH=$PWD
cd $(dirname $0)
. ./includes.sh
cd $CUR_PATH

echo "
Running download-archive.sh ..."

######### Parameters ###############
URL=$1
RENAME_DOWNLOAD=$2

######### Configuring and computing variables ####
local PROVIDE_LOADER=$SCRIPTS_DIR/provide-wget.sh
local LOADER=$UTILS/wget
local EXTRA_PARAMS

if ! [ "$RENAME_DOWNLOAD" = "" ];
then EXTRA_PARAMS="--output-document $RENAME_DOWNLOAD"; 
fi

########## Downloading #############
$PROVIDE_LOADER
echo "\nURL: $URL"
$LOADER $URL $EXTRA_PARAMS
echo "End running download-archive.sh"