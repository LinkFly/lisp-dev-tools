#!/bin/sh
cd $(dirname $0)

#### Includes ####
. ./includes.sh
. ./core.sh

######### Parameters ###############
ARCHIVE_NAME=$1

######## Include scripts ###########
. ./includes.sh
. ./core.sh

######### Computing variables ######
ARCHIVE_PATH=$ARCHIVES/$ARCHIVE_NAME

######### Removing if is exist #####
if [ -f $ARCHIVE_PATH ];
then rm $ARCHIVE_PATH && echo "
Archive $ARCHIVE_NAME removed successful.

OK.";
else echo "
Archive $ARCHIVE_NAME already does not exist.

ALREADY."
fi

