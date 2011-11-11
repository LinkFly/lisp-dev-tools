#!/bin/sh
cd $(dirname $0)
echo "Cleaning all ..."
rm -rf lisp sources compilers archives utils/tools tmp
echo "OK"