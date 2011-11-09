#!/bin/sh

. ./tools.conf
. ./utils.sh

local LISP_VERSION_PARAM=$(uppercase $CUR_LISP)_VERSION
$(dirname $0)/get-default-param.sh $LISP_VERSION_PARAM tools.conf

