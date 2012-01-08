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
POST_DOWNLOAD_CMD="$3"

######### Configuring and computing variables ####
PROVIDE_LOADER=$SCRIPTS_DIR/provide-wget.sh
LOADER=$UTILS/wget
CHECK_URL_CMD="$UTILS/wget --spider"
EXTRA_PARAMS

if ! [ "$RENAME_DOWNLOAD" = "" ];
then EXTRA_PARAMS="--output-document $RENAME_DOWNLOAD"; 
fi

########## Checking URL #############
echo "
Checking URL $URL ...
"
RESULT=1;
$CHECK_URL_CMD $URL && RESULT=0
if [ $RESULT = 0 ];
then echo "OK.";
else echo "
ERROR: bad URL: $URL

FAILED."; exit 1;
fi

########## Downloading #############
$PROVIDE_LOADER || exit 1

echo "
URL: $URL"
$LOADER $URL $EXTRA_PARAMS
if ! [ "$POST_DOWNLOAD_CMD" = "" ]; then
    echo "Now evaluating POST_DOWNLOAD_CMD: $POST_DOWNLOAD_CMD";
    PATH=$UTILS:$PATH;
    eval "$POST_DOWNLOAD_CMD";
fi
echo "End running download-archive.sh"