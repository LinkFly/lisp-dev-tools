#!/bin/sh
cd $(dirname $0)
. ./includes.sh

provide_tool emacs $SCRIPTS_DIR/build-emacs.sh $SCRIPTS_DIR/provide-archive-emacs.sh