#!/bin/sh

######### Configuring variables ####
UTILS_DIRNAME=utils

########## Computing variables ####
UTILS_DIR=$PWD/$UTILS_DIRNAME
WGET_REALPATH=$(readlink $UTILS_DIR/wget)
if [ $WGET_REALPATH ] && [ -f $WGET_REALPATH ]; 
  then echo "wget found in $WGET_REALPATH ... OK.";
  else ./build-wget.sh && rm -f $UTILS_DIR/wget && ln -s $UTILS_DIR/usr/bin/wget $UTILS_DIR/wget
fi