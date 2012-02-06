#!/bin/sh
cd "$(dirname "$0")"
. ./includes.sh

########## Computing variables #####
abs_path LISP_DIR
CUR_LISP_UP=$(uppercase $CUR_LISP)
LISP_SOURCES_DIR=$SOURCES/$LISP_LISPS_SOURCES/$LISP_SOURCES_DIRNAME
LISP_COMPILER_DIR=$COMPILERS/$LISP_LISPS_COMPILERS/$LISP_COMPILER_DIRNAME

if [ "$1" = "rebuild" ];then
    REBUILD_P=yes;
fi

###################################
#### Checking dependecies libs ####
LIBS="$LISP_LIB_DEPS"
check_dep_libs "$LIBS"

if [ "$REBUILD_P" = yes ];then
    resolve_deps "$LISP_REBUILD_DEPS_ON_TOOLS"
fi

#### Call build ####
SOURCES_DIR="$LISP_SOURCES_DIR"
RESULT_DIR="$LISP_DIR"
PROCESS_CMD="$(get_build_lisp_cmd)"
#echo "$PROCESS_CMD"
#exit 1;
if [ "$PROCESS_CMD" = "" ];
then echo "
ERROR: empty build command.

FAILED."; exit 1;
fi

INSTALL_CMD="$(get_install_lisp_cmd)"
if [ "$INSTALL_CMD" = "" ];
then echo "
ERROR: empty install command.

FAILED."; exit 1;
fi

BIN_BUILD_RESULT="$LISP_SOURCES_DIR/$LISP_BIN_BUILD_RESULT"

MES_ALREADY="
Lisp $CUR_LISP_UP already builded.
Run remove-lisp.sh and retry building, or run rebuild-lisp.sh
Directory: $LISP_DIR

ALREADY."

MES_NOT_EXIST_SRC_FAIL="
ERROR: directory $LISP_SOURCES_DIR does not exist! 
Please run the provide-sources-sbcl.sh

FAILED."

MES_START_BUILDING="
Lisp $CUR_LISP_UP building ... 
Directory (contained sources): $LISP_SOURCES_DIR"

MES_BUILDING_SUCC="
Building $CUR_LISP_UP from $LISP_SOURCES_DIRNAME successful.
Directory (contained sources): $LISP_SOURCES_DIR

OK."

MES_BUILDING_FAIL="
ERROR: Building $CUR_LISP_UP from $LISP_SOURCES_DIRNAME failed.
Directory (contained sources): $LISP_SOURCES_DIR

FAILED."

MES_COPING_RESULT_SUCC="
Coping building $CUR_LISP_UP results into $LISP_DIR successful.
Directory (contained sources): $LISP_SOURCES_DIR
Directory (with build results): $LISP_DIR

OK."

MES_COPING_RESULT_FAIL="
ERROR: Coping building $CUR_LISP_UP results into $LISP_DIR failed.
Directory (contained sources): $LISP_SOURCES_DIR

FAILED."

build "$SOURCES_DIR" "$RESULT_DIR" "$PROCESS_CMD" "$INSTALL_CMD" "$BIN_BUILD_RESULT" \
"$MES_ALREADY" "$MES_NOT_EXIST_SRC_FAIL" \
"$MES_START_BUILDING" "$MES_BUILDING_SUCC" "$MES_BUILDING_FAIL" \
"$MES_COPING_RESULT_SUCC" "$MES_COPING_RESULT_FAIL"