#!/bin/sh
cd $(dirname $0)

##### Include scripts #####
. ./conf/dirs.conf
. ./internal-conf/internal-dirs.conf
. ./include/utils.sh
. ./include/absolutized-pathes.sh
. ./conf/tools.conf
. ./conf/lisps.conf
. ./include/correct-params.sh
. ./internal-conf/internal-lisps.conf
. ./created-general-lisp-params.sh
. ./core.sh
. ./get-build-install-run-cmds.sh








