#!/bin/sh
cd $(dirname $0)/sh 
. ./includes.sh

echo "Cleaning all ..."
local CREATED_DIRS="sources compilers utils/tools archives tmp tmp-download"; 
for dir in $CREATED_DIRS
do rm -rf "$PREFIX/$dir";
done
echo "OK"