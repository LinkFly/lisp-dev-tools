#!/bin/sh
cd $(dirname $0)
. ./includes.sh

######### Configuring variables ####
PROVIDE_ARCHIVE_SCRIPT=$SCRIPTS_DIR/provide-archive.sh

######## Providing sbcl archive if needed #########
FILE=$ARCHIVES/$AUTOCONF_ARCHIVE

PROCESS_CMD="$PROVIDE_ARCHIVE_SCRIPT $AUTOCONF_ARCHIVE $AUTOCONF_URL $AUTOCONF_RENAME_DOWNLOAD"

MES_START_PROCESS="
\nProviding AUTOCONF archive $AUTOCONF_ARCHIVE ...
\nDirectory with archives: $ARCHIVES"

MES_ALREADY="
\nAUTOCONF archive $AUTOCONF_ARCHIVE already exist.
\nDirectory with archives: $ARCHIVES
\n
\nOK."

MES_SUCCESS="
\nProviding emacs archive $AUTOCONF_ARCHIVE successful.
\nDirectory with archives: $ARCHIVES
\n
\nOK."

MES_FAILED="
\nERROR: providing AUTOCONF archive $AUTOCONF_ARCHIVE failed!
\n
\nFAILED"

provide_file "$FILE" "$PROCESS_CMD" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"

