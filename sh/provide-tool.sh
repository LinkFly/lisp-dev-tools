#!/bin/sh
cd "$(dirname "$0")"
echo "
Running 'provide-tool.sh $1' ..."
. ./includes.sh
provide_tool "$1" || exit 1
