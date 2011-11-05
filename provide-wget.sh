#!/bin/sh

######## Include scripts ###########
. $(dirname $0)/global-params.conf
. $(dirname $0)/utils.sh

######### Configuring variables ####
UTILS_DIRNAME=utils

########## Computing variables ####
abs_path UTILS
WGET_REALPATH=$(readlink $UTILS/wget)

########## Building wget if does not exist #######
if [ $WGET_REALPATH ] && [ -f $WGET_REALPATH ]; 
  then echo "wget found in $WGET_REALPATH ... OK.";
  else ./build-wget.sh && rm -f $UTILS_DIR/wget && ln -s $UTILS_DIR/usr/bin/wget $UTILS_DIR/wget
fi