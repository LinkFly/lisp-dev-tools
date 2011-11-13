#!/bin/sh
cd $(dirname $0)
. ./includes.sh

TOOL=$(downcase "$1")
provide_tool $TOOL $SCRIPTS_DIR/build-${TOOL}.sh $SCRIPTS_DIR/provide-archive-${TOOL}.sh