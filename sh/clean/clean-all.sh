#!/bin/sh
cd "$(dirname "$0")/sh"
. ./includes.sh

echo "Cleaning all ..."
CREATED_DIRS="$ARCHIVES $LISPS $COMPILERS $SOURCES $LISP-LIBS $TMP $TMP-DOWNLOAD $UTILS/$TOOLS_DIRNAME $EMACS-LIBS";
for dir in $CREATED_DIRS
do rm -rf "$PREFIX/$dir";
done
rm -f $UTILS/wget
rm -f $UTILS/emacs
echo "OK."
