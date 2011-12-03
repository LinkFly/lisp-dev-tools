#!/bin/sh
cd $(dirname $0)
. ./includes.sh

if [ -f $EMACS_LIBS/init.el ];then
    LOAD_INIT=" --load $EMACS_LIBS/init.el"
fi

if [ -f $EMACS_LIBS/init-slime.el ];then
    LOAD_INIT="$LOAD_INIT --load $EMACS_LIBS/init-slime.el"
fi
PATH=$PREFIX:$PATH QUICKLISP=$QUICKLISP $UTILS/emacs --no-init-file --no-site-file${LOAD_INIT} "$@"