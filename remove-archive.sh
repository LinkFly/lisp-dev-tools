#!/bin/sh

######### Parameters ###############
ARCHIVE_NAME=$1

######## Include scripts ###########
. ./global-params.conf
. ./utils.sh

######### Configuring variables ####


######### Computing variables ######
abs_path ARCHIVES_DIR
ARCHIVE_PATH=$ARCHIVES_DIR/$ARCHIVE_NAME

######### Removing if is exist #####
if [ -f $ARCHIVE_PATH ];
then rm $ARCHIVE_PATH && echo "$ARCHIVE_NAME removed successful.";
else echo "$ARCHIVE_NAME not found."
fi

