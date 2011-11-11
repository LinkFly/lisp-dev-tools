#!/bin/sh

##### Include scripts #####
. ./includes.sh

######### Configuring variables ####
PROVIDE_ARCHIVE_SCRIPT=provide-archive.sh

######### Computing variables ######
abs_path PROVIDE_ARCHIVE_SCRIPT

######## Providing sbcl archive if needed #########
FILE=$ARCHIVES/$M4_ARCHIVE

PROCESS_SCRIPT="$PROVIDE_ARCHIVE_SCRIPT $M4_ARCHIVE $M4_URL"

MES_START_PROCESS="
Providing M4 archive $M4_ARCHIVE ...
Directory with archives: $ARCHIVES"

MES_ALREADY="
M4 archive $M4_ARCHIVE already exist.
Directory with archives: $ARCHIVES

OK."

MES_SUCCESS="
Providing emacs archive $M4_ARCHIVE successful.
Directory with archives: $ARCHIVES

OK."

MES_FAILED="
ERROR: providing M4 archive $M4_ARCHIVE failed!

FAILED"

provide_file "$FILE" "$PROCESS_SCRIPT" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"

