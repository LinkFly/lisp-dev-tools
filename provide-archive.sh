#!/bin/sh
echo "Running provide-archive.sh ..."

######## Correcting path $$$$$$$$$$$
CUR_PATH=$DIR
cd $(dirname $0)

######### Parameters ###############
ARCHIVE_NAME=$1
URL=$2

######## Include scripts ###########
. ./global-params.conf
. ./tools.conf
. ./utils.sh

######### Configuring variables ####
DOWNLOAD_SCRIPT=download-archive.sh

######### Computing variables ######
abs_path DOWNLOAD_SCRIPT
abs_path TMP_DOWNLOAD
abs_path ARCHIVES

ARCHIVE_PATH=$ARCHIVES/$ARCHIVE_NAME
TMP_ARCHIVE=$TMP_DOWNLOAD/$ARCHIVE_NAME

######### Downloading if needed ######
if [ -f $ARCHIVE_PATH ];
then echo "$ARCHIVE_NAME already downloaded ... OK.";
else 
mkdir --parents $TMP_DOWNLOAD
cd $TMP_DOWNLOAD;
$DOWNLOAD_SCRIPT $URL
if [ -f $TMP_ARCHIVE ];
  then 
    mkdir --parents $ARCHIVES;
    mv $TMP_ARCHIVE $ARCHIVE_PATH; 
    echo "$ARCHIVE_NAME downloaded ... OK."; 
  else echo "ERROR: downloading $ARCHIVE_NAME failed"; return 1;
fi
fi

echo "End running provide-archive.sh ..."