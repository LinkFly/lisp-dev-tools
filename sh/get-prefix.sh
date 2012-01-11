#!/bin/sh
cd "$(dirname "$0")"
echo $(dirname $(dirname $(sh realpath ${0##*/})))