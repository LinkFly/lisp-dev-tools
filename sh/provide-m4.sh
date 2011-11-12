#!/bin/sh
cd $(dirname $0)
. ./includes.sh

provide_tool m4 $SCRIPTS_DIR/build-m4.sh $SCRIPTS_DIR/provide-archive-m4.sh
