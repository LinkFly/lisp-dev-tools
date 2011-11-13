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
local CHECK_URL_CMD="$UTILS/wget --spider"
local EXTRA_PARAMS

if ! [ "$RENAME_DOWNLOAD" = "" ];
then EXTRA_PARAMS="--output-document $RENAME_DOWNLOAD"; 
fi

########## Checking URL #############
echo "\nChecking URL $URL ...\n"
local RESULT=1;
$CHECK_URL_CMD $URL && RESULT=0
if [ $RESULT = 0 ];
then echo "OK.";
else echo "
ERROR: bad URL: $URL

FAILED."; exit 1;
fi

########## Downloading #############
$PROVIDE_LOADER
echo "\nURL: $URL"
$LOADER $URL $EXTRA_PARAMS
echo "End running download-archive.sh"