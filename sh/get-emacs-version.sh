#!/bin/sh
cd $(dirname $0)
. ./includes.sh

echo $($UTILS/emacs --version | head -n 1 | awk '{print $3}')