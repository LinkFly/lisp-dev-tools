#!/bin/sh
cd $(dirname $0)
. ./includes.sh

local D=\$
local TMP=$1
eval TMP=$D$1

echo $TMP