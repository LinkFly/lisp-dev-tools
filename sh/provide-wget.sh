#!/bin/sh
echo "
Running provide-wget.sh ..."
$(dirname $0)/provide-tool.sh wget || exit 1
