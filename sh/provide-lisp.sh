#!/bin/sh
cd "$(dirname "$0")"
. ./includes.sh

#### Resolving dependencies #######
resolve_deps "$LISP_DEPS_ON_TOOLS"

######### Configuring variables ####
PROVIDE_ARCHIVE_LISP_BIN=$SCRIPTS_DIR/provide-archive-lisp-bin.sh
PROVIDE_COMPILER_LISP=$SCRIPTS_DIR/provide-compiler-lisp.sh
PROVIDE_ARCHIVE_LISP_SOURCE=$SCRIPTS_DIR/provide-archive-lisp-src.sh
PROVIDE_SOURCES_LISP=$SCRIPTS_DIR/provide-sources-lisp.sh
PROVIDE_BUILD_SCRIPT=$SCRIPTS_DIR/provide-build-lisp.sh
PROVIDE_PREBUILD_SCRIPT=$SCRIPTS_DIR/provide-prebuilded-lisp.sh

BUILD_OR_PREBUILD_SCRIPT= #computing latter
PROVIDE_QUICKLISP_SCRIPT= #computing latter
PROVIDE_SELF_COMPILER= #computing latter
PROVIDE_SOURCES= #computing latter

######### Computing variables ####
abs_path LISP_DIR

CUR_LISP_UP=$(uppercase $CUR_LISP)

if [ "$LISP_NO_BUILDING_P" = "yes" ];
then BUILD_OR_PREBUILD_SCRIPT=$PROVIDE_PREBUILD_SCRIPT;
else BUILD_OR_PREBUILD_SCRIPT=$PROVIDE_BUILD_SCRIPT;
fi

if ( [ "$LISP_SELF_COMPILATION_P" = "yes" ] || [ "$LISP_NO_BUILDING_P" = "yes" ] ) && \
    [ "$LISP_BIN_IN_SOURCES" != "yes" ];
then 
    PROVIDE_SELF_COMPILER="$PROVIDE_ARCHIVE_LISP_BIN && $PROVIDE_COMPILER_LISP";
else 
    PROVIDE_SELF_COMPILER="echo 'nop' > /dev/null";
fi

if [ "$LISP_NO_BUILDING_P" = "no" ];
then 
    PROVIDE_SOURCES="$PROVIDE_ARCHIVE_LISP_SOURCE && $PROVIDE_SOURCES_LISP"
else 
    PROVIDE_SOURCES="echo 'nop' > /dev/null";
fi

if [ "$LISP_ENABLE_QUICKLISP" = "yes" ];then
    PROVIDE_QUICKLISP_SCRIPT=" && $SCRIPTS_DIR/provide-quicklisp.sh"
fi

######## Download compiler, get compiler, download ################
######## sources, get sources and building lisp if needed #########
DIR=$LISP_DIR

PROCESS_SCRIPT="$PROVIDE_SELF_COMPILER && $PROVIDE_SOURCES && ${BUILD_OR_PREBUILD_SCRIPT}${PROVIDE_QUICKLISP_SCRIPT}"

MES_START_PROCESS="
Providing $CUR_LISP_UP $LISP_DIRNAME ...
Directory for results: $LISP_DIR"

MES_ALREADY="
$CUR_LISP_UP already exist.
Run run-lisp.sh for using, or run rebuild-lisp.sh for retry build). 
Directory: $LISP_DIR

OK.";

MES_SUCCESS="
$CUR_LISP_UP $LISP_DIRNAME provided successful.
Directory: $LISP_DIR

OK."

MES_FAILED="ERROR: LISP $LISP_DIRNAME provided failed.
Directory that has not been created: $LISP_DIR

FAILED." 

provide_dir "$DIR" "$PROCESS_SCRIPT" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"
