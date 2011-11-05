#!/bin/sh

######### Configuring variables ####

######### Including scripts ######
. $PWD/global-params.conf
. $PWD/utils.sh

######### Computing variables ####
LISP=$1
VERSION=$2

var-def VERSION $DEFAULT_LISP
echo "Providing lisp-system: $LISP version: $VERSION..."

BUILD_SCRIPT=provide-${LISP}.sh
BUILD_CMD=$PWD/$BUILD_SCRIPT $VERSION

LISP_DIRNAME=$LISP-$VERSION
SBCL_DIR=$PWD/$LISPS_DIRNAME/$LISP/$LISP_DIRNAME

##################################
if [ -d $SBCL_DIR ]; 
then echo "Lisp-system ${LISP_DIRNAME} already provided.";
else $BUILD_CMD && echo "Lisp-system $(LISP_DIRNAME) provided";
fi
