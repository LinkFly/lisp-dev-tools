#!/bin/sh
######
# Note: includes when current-dir = <lisp-dev-tools>/sh
######

## get-prefix.sh must be into sh/get-prefix.sh
PREFIX=$(./get-prefix.sh) 
LDT_CUSTOM_CONF_DIR=${LDT_CUSTOM_CONF_DIR:-"$PREFIX/sh/conf"}

include_if_exist () {
if test -f "$1"
then
    . "$1"
fi
}

##### Include scripts #####
. ./conf/dirs.conf
include_if_exist "$LDT_CUSTOM_CONF_DIR/custom-dirs.conf"    
. ./internal-conf/internal-dirs.conf
. ./include/utils.sh
. ./include/absolutized-pathes.sh
. ./include/exit-if-lock.sh
. ./include/copy-links.sh
. ./conf/tools.conf
. ./conf/lisp-and-version.conf
include_if_exist "$LDT_CUSTOM_CONF_DIR/custom-lisp-and-version.conf"    
. ./conf/lisps.conf
. ./include/correct-params.sh
. ./internal-conf/internal-lisps.conf
. ./created-general-lisp-params.sh
. ./core.sh
. ./get-build-install-run-cmds.sh









