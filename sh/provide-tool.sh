#!/bin/sh
cd "$(dirname "$0")"
. ./includes.sh
provide_tool "$1" || exit 1