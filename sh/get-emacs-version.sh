#!/bin/sh
cd "$(dirname "$0")"
. ./includes.sh

echo $($UTILS/emacs --version | head -n 1 | $UTILS/gawk '{print $3}')