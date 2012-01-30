#!/bin/sh

resolve_deps () {
local DEPS="$1"
if ! [ "$1" = "" ];
then
    for dep in $DEPS
    do
	echo "Resolving dependency: $dep ...";
	provide_tool "$dep" || exit 1;
	echo "OK.";
    done
fi
}

provide_tool () {
### Parameters ###
local TOOL_NAME=$1

TOOL_NAME=$(downcase $TOOL_NAME)
local TOOL_VERSION=$(get_spec_val $TOOL_NAME _VERSION)
if [ "$TOOL_VERSION" = "" ];then 
    echo "
ERROR: Tool $TOOL_NAME does not registered.

FAILED.";exit 1;
fi
local TOOL_DIR=$(get_spec_val $TOOL_NAME _TOOL_DIR)
local TOOL_RELATIVE_DIR=$(get_spec_val $TOOL_NAME _RELATIVE_DIR)
local TOOL_ARCHIVE=$(get_spec_val $TOOL_NAME _ARCHIVE)
local TOOL_DEPS_ON_TOOLS="$(get_spec_val $TOOL_NAME _DEPS_ON_TOOLS)"
local TOOL_PROVIDE_FILES="$(get_spec_val $TOOL_NAME _PROVIDE_FILES)"

local LINK_TO_TOOL_DIR_P="no"
if [ "$TOOL_PROVIDE_FILES" = "" ]; then
    TOOL_PROVIDE_FILES="$TOOL_DIR";
    LINK_TO_TOOL_DIR_P="yes";
fi

echo "Processing of tool: $TOOL_NAME"
if [ $(links_is_exist_p "$TOOL_PROVIDE_FILES" "$UTILS") = "yes" ];then
  echo "
Tool $TOOL_NAME already provided.
Provided concrete files (links into directory $UTILS): $TOOL_PROVIDE_FILES

ALREADY."; exit 0;
fi
resolve_deps "$TOOL_DEPS_ON_TOOLS" || exit 1;

#### Providing archive if needed ####
local ALL_FILES_EXIST_P=$(links_is_exist_p "$TOOL_PROVIDE_FILES" "$UTILS_DIR")

if [ "$ALL_FILES_EXIST_P" = "no" ]
then if ! [ -f $ARCHIVES/$TOOL_ARCHIVE ]; then
	if [ "$TOOL_NAME" = "wget" ]; then 
	    ln -fs $SCRIPTS_DIR/$WGET_ARCHIVE $ARCHIVES/$WGET_ARCHIVE;	
	else 
	    if [ "$TOOL_NAME" = "openssl" ]; then 
		ln -fs $SCRIPTS_DIR/$OPENSSL_ARCHIVE $ARCHIVES/$OPENSSL_ARCHIVE;
	    else provide_archive_tool "$TOOL_NAME";
	    fi
	fi
     fi
fi

#########################################
local LINK_REFERS_STR="
"
for link in $TOOL_PROVIDE_FILES;
do
    local REFER=$(readlink $UTILS/$link);
    local NOT_FOUND=$(if [ "$REFER" = "" ]; then echo '<not-found>'; fi);
    LINK_REFERS_STR="${LINK_REFERS_STR}
${NOT_FOUND} ${link}: $REFER";
done

if ! [ "$TOOL_RELATIVE_DIR" = "" ]; then
    TOOL_RELATIVE_DIR="/$TOOL_RELATIVE_DIR"
fi

local BUILDED_FILES=""
if [ "$LINK_TO_TOOL_DIR_P" = "yes" ]; then
	BUILDED_FILES="$TOOLS_DIRNAME/$TOOL_DIR
";
else 
    for link in $TOOL_PROVIDE_FILES;
    do 
	BUILDED_FILES="${BUILDED_FILES}$TOOLS_DIRNAME/$TOOL_DIR${TOOL_RELATIVE_DIR}/$link
";
    done
fi

### Call build_if_no ###
FILE_LINK_NAMES="$TOOL_PROVIDE_FILES"
UTILS_DIR=$UTILS
BUILD_CMD="PATH=$UTILS:$PATH; build_tool $TOOL_NAME"
BUILDED_FILES="$BUILDED_FILES"
MES_ALREADY="
Tool $TOOL_NAME found in $UTILS
Directory (with utils): $UTILS
Symbolic links refers to:$LINK_REFERS_STR

OK."

MES_BUILDED_FAIL="
Builded $TOOL_NAME failed.

FAILED."

MES_BUILDED_SUCC="
Builded $TOOL_NAME success.

OK."

build_if_no "$FILE_LINK_NAMES" "$UTILS_DIR" "$BUILD_CMD" "$BUILDED_FILES" \
"$MES_ALREADY" "$MESS_BUILDED_FAIL" "$MES_BUILDED_SUCC"
}

remove_tool () {
### Parameters ###
local TOOL_NAME=$1

local TOOL_NAME=$(downcase $TOOL_NAME)
local TOOL_DIRNAME=$(get_spec_val $TOOL_NAME _TOOL_DIR)
local TOOL_DIR="$UTILS/$TOOLS_DIRNAME/$TOOL_DIRNAME"

### Call remove_dir ###
DIR="$TOOL_DIR"
MES_SUCC="
$TOOL_DIRNAME removed successful.
Directory (that was deleted): $TOOL_DIR

OK."

MES_FAIL="
$TOOL_DIRNAME removed failed.
Directory (that was not deleted): $TOOL_DIRNAME

FAILED."

MES_ABSENCE="
Tool $TOOL_NAME (directory name: $TOOL_DIRNAME) already does not exist.
Directory (than does not exist): $TOOL_DIR

ALREADY."

remove_dir "$DIR" "$MES_SUCC" "$MES_FAIL" "$MES_ABSENCE"
}

build_tool () {
local TOOL_NAME="$1"

local D=\$
local NAME=$(uppercase $TOOL_NAME)
local TOOL_TMP_DIRNAME=$(downcase $TOOL_NAME)-compiling
local TOOL_ARCHIVE="$(get_spec_val $TOOL_NAME _ARCHIVE)"
local TOOL_DIRNAME="$(get_spec_val $TOOL_NAME _TOOL_DIR)"
local TOOL_COMPILING_EXTRA_ARGS="$(get_spec_val $TOOL_NAME _COMPILING_EXTRA_ARGS)"
local TOOL_EXTRACT_CMD="$(get_spec_val $TOOL_NAME _EXTRACT_CMD)"
local TOOL_PRE_BUILD_CMD="$(get_spec_val $TOOL_NAME _PRE_BUILD_CMD)"
local TOOL_PRE_MAKE_CMD="$(get_spec_val $TOOL_NAME _PRE_MAKE_CMD)"
local TOOL_PRE_INSTALL_CMD="$(get_spec_val $TOOL_NAME _PRE_INSTALL_CMD)"
local TOOL_REQUIRED_COMPILE_P="$(get_spec_val $TOOL_NAME _REQUIRED_COMPILE_P)"
local TOOL_CONFIGURE_VARS="$(get_spec_val $TOOL_NAME _CONFIGURE_VARS)"

if ! [ -f "$ARCHIVES/$TOOL_ARCHIVE" ];then
    echo "
ERROR: Archive $ARCHIVES/$TOOL_ARCHIVE not found.

FAILED.";exit 1;
fi

if [ "$TOOL_EXTRACT_CMD" = "" ]; then
    TOOL_EXTRACT_CMD=$(get_extract_begin_cmd "$ARCHIVES/$TOOL_ARCHIVE");
fi

### Call extract_build_install ###
local ARCHIVE_PATH="$ARCHIVES/$TOOL_ARCHIVE"
local TMP_TOOL_DIR="$TMP/$TOOL_TMP_DIRNAME"
local EXTRACT_SCRIPT="$TOOL_EXTRACT_CMD"
local RESULT_DIR="$UTILS/$TOOLS_DIRNAME/$TOOL_DIRNAME"
local COMPILING_EXTRA_PARAMS="$TOOL_COMPILING_EXTRA_ARGS"
local MES_ARCHIVE_CHECK_FAIL="
ERROR: archive $ARCHIVE_PATH does not exist!

FAILED."

local MES_BUILD_FAIL="
ERROR: Building tool $NAME failed.

FAILED."

PRE_BUILD_CMD="$TOOL_PRE_BUILD_CMD"
PRE_MAKE_CMD="$TOOL_PRE_MAKE_CMD"
PRE_INSTALL_CMD="$TOOL_PRE_INSTALL_CMD"
REQUIRED_COMPILE_P="$TOOL_REQUIRED_COMPILE_P"
CONFIGURE_VARS="$TOOL_CONFIGURE_VARS"

extract_build_install "$ARCHIVE_PATH" "$TMP_TOOL_DIR" "$EXTRACT_SCRIPT" "$RESULT_DIR" \
"$COMPILING_EXTRA_PARAMS" "$MES_ARCHIVE_CHECK_FAIL" "$MES_BUILD_FAIL" "$PRE_BUILD_CMD" \
"$PRE_MAKE_CMD" "$PRE_INSTALL_CMD" "$REQUIRED_COMPILE_P" "$CONFIGURE_VARS"
}

provide_archive_tool () {
local TOOL_NAME="$1"

local NAME=$(uppercase $TOOL_NAME)
local TOOL_ARCHIVE=$(get_spec_val $TOOL_NAME _ARCHIVE)
local TOOL_URL=$(get_spec_val $TOOL_NAME _URL)
local TOOL_RENAME_DOWNLOAD=$(get_spec_val $TOOL_NAME _RENAME_DOWNLOAD)

######### Configuring variables ####
PROVIDE_ARCHIVE_SCRIPT=$SCRIPTS_DIR/provide-archive.sh

######## Providing sbcl archive if needed #########
FILE=$ARCHIVES/$TOOL_ARCHIVE

PROCESS_CMD="$PROVIDE_ARCHIVE_SCRIPT $TOOL_ARCHIVE $TOOL_URL $TOOL_RENAME_DOWNLOAD"

MES_START_PROCESS="
Providing $NAME archive $TOOL_ARCHIVE ...
Directory with archives: $ARCHIVES"

MES_ALREADY="
$NAME archive $TOOL_ARCHIVE already exist.
Directory with archives: $ARCHIVES

OK."

MES_SUCCESS="
Providing emacs archive $TOOL_ARCHIVE successful.
Directory with archives: $ARCHIVES

OK."

MES_FAILED="
ERROR: For $NAME tool archive $TOOL_ARCHIVE not provided!

FAILED."

provide_file "$FILE" "$PROCESS_CMD" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED" || exit 1
}

check_dep_libs () {
local LIBS="$1"
for lib in $LIBS; 
do if ! [ -f $lib ];
    then echo "
ERROR: library $lib not found.
$LISP_NO_LIB_DEPS_HINT

FAILED."; exit 1;
    fi
done
}
