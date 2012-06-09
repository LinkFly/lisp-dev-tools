#!/bin/sh
cd "$(dirname "$0")"
. ./includes.sh

D=\$
TMP=$1
eval TMP=$D$1

PARAM="$1"
FILE="$3"
OLD_VAL="$TMP"
NEW_VAL="$2"

if ! test -f "$FILE"
then
    touch "$FILE"
fi

if test "$(is_param_p "$PARAM" "$FILE")" = "no"
then 
    add_empty_param "$PARAM" "$FILE"
    OLD_VAL=""
fi    

change_param "$PARAM" "$FILE" "$OLD_VAL" "$NEW_VAL"
