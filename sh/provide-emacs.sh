#!/bin/sh
cd $(dirname $0)
. ./includes.sh

######## Configuring variables #####
BUILD_SCRIPT=build-emacs.sh

########## Computing variables ####
abs_path BUILD_SCRIPT

##########
provide_tool emacs $BUILD_SCRIPT