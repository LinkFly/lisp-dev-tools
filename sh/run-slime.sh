#!/bin/sh
cd "$(dirname "$0")"
. ./includes.sh

if ! [ -f $EMACS_LIBS/init-slime.el ];then
    echo "
ERROR: not found init.el (please to run ./provide-slime)
Directory (where finded init-slime.el): $EMACS_LIBS

FAILED.";exit 1;
fi

QUICKLISP="$QUICLISP" ./run-emacs.sh --load "$EMACS_LIBS/init-slime.el" --eval "(slime)" "$@"