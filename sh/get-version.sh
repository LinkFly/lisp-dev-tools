#!/bin/sh
cd $(dirname $0)
##### Include scripts #####
. ./includes.sh
. ./core.sh

local LISP_VERSION_PARAM=$(uppercase $CUR_LISP)_VERSION
./get-default-param.sh $LISP_VERSION_PARAM conf/lisps.conf

