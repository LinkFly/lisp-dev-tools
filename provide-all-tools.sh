#!/bin/sh

######### Include scripts ##########
. ./download-archives.conf

######### Configuring variables ####
PROVIDE_ARCHIVE=provide-archive.sh
PROVIDE_ARCHIVE_DIR=$PWD

#########################################

######### Computing variables ######
PROVIDE_ARCHIVE_PATH=$PWD/$PROVIDE_ARCHIVE

#########################################

######## Providing #############
$PROVIDE_ARCHIVE_PATH $SBCL_BIN $SBCL_BIN_URL
$PROVIDE_ARCHIVE_PATH $SBCL_SOURCE $SBCL_SOURCE_URL
$PROVIDE_ARCHIVE_PATH $SLIME $SLIME_URL
$PROVIDE_ARCHIVE_PATH $EMACS $EMACS_URL
