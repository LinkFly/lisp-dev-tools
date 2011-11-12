#!/bin/sh
cd $(dirname $0)/sh 
. ./includes.sh

######### Configuring variables ####
PROVIDE_ARCHIVE=provide-archive.sh
PROVIDE_ARCHIVE_DIR=$PWD

#########################################

######### Computing variables ######
PROVIDE_ARCHIVE_PATH=$PWD/$PROVIDE_ARCHIVE

#########################################

######## Providing #############
$PROVIDE_ARCHIVE_PATH $SBCL_BIN_ARCHIVE $SBCL_BIN_URL
$PROVIDE_ARCHIVE_PATH $SBCL_SOURCE_ARCHIVE $SBCL_SOURCE_URL
$PROVIDE_ARCHIVE_PATH $SLIME_ARCHIVE $SLIME_URL
$PROVIDE_ARCHIVE_PATH $EMACS_ARCHIVE $EMACS_URL
