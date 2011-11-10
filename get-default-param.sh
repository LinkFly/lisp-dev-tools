#!/bin/sh

##### Include scripts #####
. ./includes.sh
. ./core.sh

local D=\$
local TMP=$1
eval TMP=$D$1

echo $TMP