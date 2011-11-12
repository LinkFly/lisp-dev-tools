#!/bin/sh
cd $(dirname $0)
. ./includes.sh

echo "\nRunning provide-archive.sh ..."

######## Correcting path $$$$$$$$$$$
CUR_PATH=$DIR
cd $(dirname $0)

######### Parameters ###############
local ARCHIVE_NAME=$1
local URL=$2
local RENAME_DOWNLOAD=$3

######### Configuring variables ####
DOWNLOAD_SCRIPT=$SCRIPTS_DIR/download-archive.sh
ARCHIVE_PATH=$ARCHIVES/$ARCHIVE_NAME
TMP_ARCHIVE=$TMP_DOWNLOAD/$ARCHIVE_NAME

######### Downloading if needed ######
if [ -f $ARCHIVE_PATH ];
then echo "$ARCHIVE_NAME already downloaded ... \n\nALREADY.";
else 
mkdir --parents $TMP_DOWNLOAD
rm -f $TMP_ARCHIVE
cd $TMP_DOWNLOAD;
$DOWNLOAD_SCRIPT $URL $RENAME_DOWNLOAD;
if [ -f $TMP_ARCHIVE ];
  then 
    mkdir --parents $ARCHIVES;
    mv $TMP_ARCHIVE $ARCHIVE_PATH; 
    echo "
$ARCHIVE_NAME downloaded. 

OK."; 
  else echo "ERROR: downloading $ARCHIVE_NAME
\n
\nFAILED."; return 1;
fi
fi

echo "End running provide-archive.sh ..."