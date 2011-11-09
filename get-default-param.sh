#!/bin/sh

. ./global-params.conf
. ./tools.conf

local D=\$
local TMP=$1
eval TMP=$D$1

echo $TMP