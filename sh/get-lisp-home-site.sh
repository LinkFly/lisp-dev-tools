#!/bin/sh

##### Include scripts #####
. ./includes.sh
. ./core.sh

LISP_HOME_SITE_PARAM=$(uppercase $CUR_LISP)_HOME_SITE
$(dirname $0)/get-default-param.sh $LISP_HOME_SITE_PARAM $(dirname $0)/conf/lisps.conf

