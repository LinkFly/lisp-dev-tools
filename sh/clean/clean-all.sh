#!/bin/sh
cd $(dirname $0)/sh
. ./includes.sh

echo "Cleaning all ..."
local CREATED_DIRS="archives lisp compilers sources tmp tmp-download utils/tools"; 
for dir in $CREATED_DIRS
do rm -rf "$PREFIX/$dir";
done
echo "OK."