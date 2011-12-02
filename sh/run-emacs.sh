#!/bin/sh
cd $(dirname $0)
. ./includes.sh
if [ -f $EMACS_LIBS/init.el ];then
    LOAD_INIT=" --load $EMACS_LIBS/init.el"
fi
PATH=$PREFIX:$PATH $UTILS/emacs --no-init-file --no-site-file${LOAD_INIT} "$@"