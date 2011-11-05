#!/bin/sh

##### Include scripts #########
. ./tools.conf
. ./utils.sh

###### Computing variables ####
abs_path SBCL_DIR

#### Build sbcl if needed #####
echo "Removing sbcl-$SBCL_VERSION ..."
if [ -d $SBCL_DIR ];
then rm -r $SBCL_DIR && echo "SBCL removed successful.
Directory (which has been deleted): $SBCL_DIR"
else echo "Builded sbcl not found. Directory: $SBCL_DIR";
fi


