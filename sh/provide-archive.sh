#!/bin/sh
cd "$(dirname "$0")"
. ./includes.sh

echo "
Running provide-archive.sh ..."

######## Correcting path $$$$$$$$$$$
CUR_PATH=$DIR
cd "$(dirname "$0")"

######### Parameters ###############
ARCHIVE_NAME="$1"
URL="$2"
LOADER_EXTRA_ARGS="$3"
NO_CHECK_URL_P="$4"
RENAME_DOWNLOAD="$5"
POST_DOWNLOAD_CMD="$6"

######### Configuring variables ####
DOWNLOAD_SCRIPT=$SCRIPTS_DIR/download-archive.sh
ARCHIVE_PATH=$ARCHIVES/$ARCHIVE_NAME
TMP_ARCHIVE=$TMP_DOWNLOAD/$ARCHIVE_NAME

######### Downloading if needed ######
if [ -f $ARCHIVE_PATH ];
then echo "
$ARCHIVE_NAME already downloaded ... 

ALREADY.";
else 
mkdir --parents $TMP_DOWNLOAD
rm -f $TMP_ARCHIVE
cd $TMP_DOWNLOAD;

$DOWNLOAD_SCRIPT "$URL" "$LOADER_EXTRA_ARGS" "$NO_CHECK_URL_P" "$RENAME_DOWNLOAD" "$POST_DOWNLOAD_CMD" || exit 1;
if [ -f $TMP_ARCHIVE ];
  then 
    mkdir --parents $ARCHIVES;
    mv $TMP_ARCHIVE $ARCHIVE_PATH; 
    echo "
$ARCHIVE_NAME downloaded. 

OK."; 
  else echo "ERROR: downloading $ARCHIVE_NAME

FAILED."; exit 1;
fi
fi

echo "End running provide-archive.sh ..."