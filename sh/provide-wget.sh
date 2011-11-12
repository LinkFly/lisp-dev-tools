#!/bin/sh
cd $(dirname $0)
. ./includes.sh

######## Configuring variables #####
BUILD_SCRIPT=build-wget.sh

########## Computing variables ####
abs_path BUILD_SCRIPT

##########
provide_tool wget $BUILD_SCRIPT
