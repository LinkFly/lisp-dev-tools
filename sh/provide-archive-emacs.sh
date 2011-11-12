#!/bin/sh
cd $(dirname $0)
. ./includes.sh

######### Configuring variables ####
PROVIDE_ARCHIVE_SCRIPT=$SCRIPTS_DIR/provide-archive.sh

######## Providing sbcl archive if needed #########
FILE=$ARCHIVES/$EMACS_ARCHIVE

PROCESS_SCRIPT="$PROVIDE_ARCHIVE_SCRIPT $EMACS_ARCHIVE $EMACS_URL"

MES_START_PROCESS="
\nProviding EMACS archive $EMACS_ARCHIVE ...
\nDirectory with archives: $ARCHIVES"

MES_ALREADY="
\nEMACS archive $EMACS_ARCHIVE already exist.
\nDirectory with archives: $ARCHIVES
\n
\nOK."

MES_SUCCESS="
\nProviding emacs archive $EMACS_ARCHIVE successful.
\nDirectory with archives: $ARCHIVES
\n
\nOK."

MES_FAILED="
\nERROR: providing EMACS archive $EMACS_ARCHIVE failed!
\n
\nFAILED"

provide_file "$FILE" "$PROCESS_SCRIPT" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"

