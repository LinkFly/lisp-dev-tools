#!/bin/sh
cd "$(dirname "$0")"
. ./includes.sh

D=\$
TMP=$1
eval TMP=$D$1

echo $TMP