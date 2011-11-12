#!/bin/sh
cd $(dirname $0)
. ./includes.sh

###### Computing variables ####
abs_path LISP_DIR

#### Build sbcl if needed #####
echo "Removing sbcl-$LISP_VERSION ..."
if [ -d $LISP_DIR ];
then rm -r $LISP_DIR && echo "
LISP removed successful.
Directory (which has been deleted): $LISP_DIR

OK."
else echo "
Builded LISP $LISP_DIRNAME not found. 
Directory (which has been deleted): $LISP_DIR

ALREADY.";
fi