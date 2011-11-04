#!/bin/sh

######### Parameters ###############
### ARCHIVE_NAME - name archives
### URL - where to locate archive
######### Configuring variables ####
UTILS_DIRNAME=utils
ARCHIVES_DIRNAME=archives
WGET=$PWD/$UTILS_DIRNAME/wget
PROVIDE_WGET=$PWD/provide-wget.sh
TMP_DIRNAME="tmp"
TMP_DOWNLOAD_DIRNAME="tmp-download"
###########
#ARCHIVE_NAME=slime-current.tgz
#URL=http://common-lisp.net/project/slime/snapshots/slime-current.tgz
########## Computing variables ####
ARCHIVES_DIR=$PWD/$ARCHIVES_DIRNAME
ARCHIVE_PATH=$ARCHIVES_DIR/$ARCHIVE_NAME
TMP_DIR=$PWD/$TMP_DIRNAME
TMP_DOWNLOAD_DIR=$TMP_DIR/$TMP_DOWNLOAD_DIRNAME
TMP_ARCHIVE_PATH=$TMP_DOWNLOAD_DIR/$ARCHIVE_NAME

if [ -f $ARCHIVE_PATH ];
then echo "$ARCHIVE_NAME already downloaded ... OK.";
else 
$PROVIDE_WGET
mkdir --parents $TMP_DOWNLOAD_DIR
cd $TMP_DOWNLOAD_DIR;
$WGET $URL;
if [ -f $TMP_ARCHIVE_PATH ];
  then 
    mkdir --parents $ARCHIVES_DIR
    mv $TMP_ARCHIVE_PATH $ARCHIVE_PATH; 
    echo "$ARCHIVE_NAME downloaded ... OK.";
  else echo "ERROR downloaded $ARCHIVE_NAME";
fi
fi