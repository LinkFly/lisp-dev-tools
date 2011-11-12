#!/bin/sh
cd $(dirname $0)
. ./includes.sh

######## Configuring variables #####
BUILD_SCRIPT=build-m4.sh

########## Computing variables ####
abs_path BUILD_SCRIPT

##########
./provide-archive-m4.sh
provide_tool m4 $BUILD_SCRIPT
