#!/bin/sh

##### Parameters #####
SRC_OR_BIN=$1

##### Include scripts #####
. ./global-params.conf
. ./tools.conf
. ./utils.sh

######### Configuring variables ####
PROVIDE_ARCHIVE_SCRIPT=provide-archive.sh

######### Computing variables ######
abs_path PROVIDE_ARCHIVE_SCRIPT
abs_path ARCHIVES

######## Checking  parameters ######
if [ $SRC_OR_BIN != "src" ];
then if [ $SRC_OR_BIN != "bin" ];
     then echo "ERROR: fist argument must be \"src\" or \"bin\"!"; return 1;
     fi
fi

######## Computing variables #######
if [ $SRC_OR_BIN = "src" ];
then 
ARCHIVE_TYPE=source; 
ARCHIVE_FILE=$SBCL_SOURCE_ARCHIVE;
ARCHIVE_URL=$SBCL_SOURCE_URL;
fi

if [ $SRC_OR_BIN = "bin" ];
then
ARCHIVE_TYPE=binary;
ARCHIVE_FILE=$SBCL_BIN_ARCHIVE;
ARCHIVE_URL=$SBCL_BIN_URL;
fi

######## Providing sbcl archive if needed #########
echo "Providing SBCL $ARCHIVE_TYPE archive $ARCHIVE_FILE ...
Directory with archives: $ARCHIVES";
if [ -f $ARCHIVES/$ARCHIVE_FILE ];
then echo "SBCL $ARCHIVE_TYPE archive $ARCHIVE_FILE already exist.";
else
  RESULT=1
  $PROVIDE_ARCHIVE_SCRIPT $ARCHIVE_FILE $ARCHIVE_URL && RESULT=0;
  if [ $RESULT = 0 ];
  then echo "Providing SBCL archive of sources $SBCL_SOURCE_ARCHIVE successful.
Archive file: $ARCHIVES/$SBCL_SOURCE_ARCHIVE";
  else echo "ERROR: providing SBCL $ARCHIVE_TYPE archive!"; return 1;
  fi
fi
