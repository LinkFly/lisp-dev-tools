#!/bin/sh

##### Include scripts #####
. ./includes.sh
. ./core.sh

###### Computing variables ####
abs_path SBCL_DIR

#### Build sbcl if needed #####
echo "Removing sbcl-$SBCL_VERSION ..."
if [ -d $SBCL_DIR ];
then rm -r $SBCL_DIR && echo "
SBCL removed successful.
Directory (which has been deleted): $SBCL_DIR

OK."
else echo "
Builded SBCL $SBCL_DIRNAME not found. 
Directory (which has been deleted): $SBCL_DIR

ALREADY.";
fi


