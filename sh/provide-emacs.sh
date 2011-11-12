#!/bin/sh

######## Include scripts ###########
. $(dirname $0)/includes.sh
. $(dirname $0)/core.sh

######## Configuring variables #####
BUILD_SCRIPT=build-emacs.sh

########## Computing variables ####
abs_path BUILD_SCRIPT

##########
provide_tool emacs $BUILD_SCRIPT