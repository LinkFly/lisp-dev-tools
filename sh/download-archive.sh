#!/bin/sh
CUR_PATH=$PWD
cd "$(dirname "$0")"
. ./includes.sh
cd $CUR_PATH

echo "
Running download-archive.sh ..."

######### Parameters ###############
URL="$1"
LOADER_EXTRA_ARGS="$2"
NO_CHECK_URL_P="$3"
RENAME_DOWNLOAD="$4"
POST_DOWNLOAD_CMD="$5"

##my exp delete
if test "$LOADER_EXTRA_ARGS" = "-"
then 
    LOADER_EXTRA_ARGS=" "
else
    LOADER_EXTRA_ARGS=" $LOADER_EXTRA_ARGS"
fi

######### Configuring and computing variables ####
PROVIDE_LOADER=$SCRIPTS_DIR/provide-wget.sh
LOADER="$UTILS/wget${LOADER_EXTRA_ARGS}"
CHECK_URL_CMD="$LOADER --spider"
EXTRA_PARAMS=

if ! [ "$RENAME_DOWNLOAD" = "" ];
then EXTRA_PARAMS="--output-document $RENAME_DOWNLOAD"; 
fi

########## Providing wget ###########
$PROVIDE_LOADER || exit 1

########## Checking URL #############
if test "$NO_CHECK_URL_P" != "yes"
then
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
fi

########## Downloading #############
echo "
URL: $URL"
echo "Command line for loading:
$LOADER $URL $EXTRA_PARAMS
"
eval "$LOADER $URL $EXTRA_PARAMS"
if ! [ "$POST_DOWNLOAD_CMD" = "" ]; then
    echo "Now evaluating POST_DOWNLOAD_CMD: $POST_DOWNLOAD_CMD";
    PATH=$UTILS:$PATH;
    eval "$POST_DOWNLOAD_CMD";
fi
echo "End running download-archive.sh"