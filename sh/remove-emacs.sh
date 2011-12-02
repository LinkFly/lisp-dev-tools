#!/bin/sh
cd $(dirname $0)
. ./includes.sh
EMACS_DIR="$UTILS/$TOOLS_DIRNAME/$EMACS_TOOL_DIR"
rm -rf "$EMACS_DIR"
echo "Emacs in $EMACS_DIR removed."
