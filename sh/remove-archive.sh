#!/bin/sh
cd $(dirname $0)
. ./includes.sh

######### Parameters ###############
ARCHIVE_NAME=$1

######### Computing variables ######
ARCHIVE_PATH=$ARCHIVES/$ARCHIVE_NAME

######### Removing if is exist #####
if [ -f $ARCHIVE_PATH ];
then rm $ARCHIVE_PATH && echo "
Archive $ARCHIVE_NAME removed successful.
Directory (with archives): $ARCHIVES

OK.";
else echo "
Archive $ARCHIVE_NAME already does not exist.
Directory (with archives): $ARCHIVES

ALREADY."
fi

