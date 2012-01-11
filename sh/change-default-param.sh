#!/bin/sh
cd "$(dirname "$0")"
. ./includes.sh

D=\$
TMP=$1
eval TMP=$D$1

PARAM=$1
FILE=$3
OLD_VAL=$TMP
NEW_VAL=$2

change_param "$PARAM" "$FILE" "$OLD_VAL" "$NEW_VAL"
