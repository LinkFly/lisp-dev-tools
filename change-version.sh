#!/bin/sh

##### Include scripts #####
. ./includes.sh
. ./core.sh

local LISP_VERSION_PARAM=$(uppercase $CUR_LISP)_VERSION
$(dirname $0)/change-default-param.sh $LISP_VERSION_PARAM $1 tools.conf

