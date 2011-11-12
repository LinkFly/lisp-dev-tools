#!/bin/sh
cd $(dirname $0)/sh 
. ./includes.sh

echo "Cleaning all ..."

for dir in "sources compilers utils/tools archives tmp tmp-download"; 
do rm -rf $PREFIX;
done
echo "OK"