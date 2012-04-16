#!/bin/sh
cd "$(dirname "$0")"
. ./includes.sh

find "$UTILS" -maxdepth 1 -name "*" -type l -exec rm {} \;