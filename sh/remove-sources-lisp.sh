#!/bin/sh
cd $(dirname $0)
. ./includes.sh

######### Computing variables ######
LISPS_SOURCES_PATH=$SOURCES/$LISP_LISPS_SOURCES
SOURCES_DIR=$LISPS_SOURCES_PATH/$LISP_SOURCES_DIRNAME
CUR_LISP_UP=$(uppercase $CUR_LISP)

######### Removing if is exist #####

### Call remove_dir ###
DIR=$SOURCES_DIR
MES_SUCC="
$CUR_LISP_UP sources $LISP_SOURCES_DIRNAME removed successful.
Directory (with lisps sources): $LISPS_SOURCES_PATH

OK."

MES_FAIL="
$CUR_LISP_UP sources $LISP_SOURCES_DIRNAME removed failed.
Directory with (with sources): $LISPS_SOURCES_PATH

FAILED."

MES_ABSENCE="
$CUR_LISP_UP sources $LISP_SOURCES_DIRNAME already does not exist.
Directory (with lisps sources): $LISPS_SOURCES_PATH

ALREADY."

remove_dir "$DIR" "$MES_SUCC" "$MES_FAIL" "$MES_ABSENCE"


