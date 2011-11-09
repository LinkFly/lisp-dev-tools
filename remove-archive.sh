#!/bin/sh

######### Parameters ###############
ARCHIVE_NAME=$1

######## Include scripts ###########
. ./includes.sh

######### Computing variables ######
abs_path ARCHIVES
ARCHIVE_PATH=$ARCHIVES/$ARCHIVE_NAME

######### Removing if is exist #####
if [ -f $ARCHIVE_PATH ];
then rm $ARCHIVE_PATH && echo "$ARCHIVE_NAME removed successful.
\n
\nOK.";
else echo "$ARCHIVE_NAME not found.
\n
\nNOT FOUND."
fi

