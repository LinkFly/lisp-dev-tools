#!/bin/sh

. ./tools.conf
. ./utils.sh

local D=\$
local TMP=$1
eval TMP=$D$1

PARAM=$1
FILE=$3
OLD_VAL=$TMP
NEW_VAL=$2

change_param "$PARAM" "$FILE" "$OLD_VAL" "$NEW_VAL"
