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
local D=\$
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
resolve_deps "$TOOL_DEPS_ON_TOOLS"

#### Providing archive if needed ####
local ALL_FILES_EXIST_P=$(links_is_exist_p "$TOOL_PROVIDE_FILES" "$UTILS_DIR")
if [ "$ALL_FILES_EXIST_P" = "no" ]
then if ! [ -f $ARCHIVES/$TOOL_ARCHIVE ]; then
	if [ "$TOOL_NAME" = "wget" ]; then 
	    ln -fs $SCRIPTS_DIR/$WGET_ARCHIVE $ARCHIVES/$WGET_ARCHIVE;
	else provide_archive_tool "$TOOL_NAME";
	fi
     fi
fi

#########################################
local LINK_REFERS_STR="\n"
for link in $TOOL_PROVIDE_FILES;
do
    local REFER=$(readlink $UTILS/$link);
    local NOT_FOUND=$(if [ "$REFER" = "" ]; then echo '<not-found>'; fi);
    LINK_REFERS_STR="${LINK_REFERS_STR}\n${NOT_FOUND} ${link}: $REFER";
done

if ! [ "$TOOL_RELATIVE_DIR" = "" ]; then
    TOOL_RELATIVE_DIR="/$TOOL_RELATIVE_DIR"
fi

local BUILDED_FILES=""
if [ "$LINK_TO_TOOL_DIR_P" = "yes" ]; then
	BUILDED_FILES="${BUILDED_FILES}
$TOOLS_DIRNAME/$TOOL_DIR";
else 
    for link in $TOOL_PROVIDE_FILES;
    do 
	BUILDED_FILES="${BUILDED_FILES}
$TOOLS_DIRNAME/$TOOL_DIR${TOOL_RELATIVE_DIR}/$link";
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

if [ "$TOOL_EXTRACT_CMD" = "" ]; then
    TOOL_EXTRACT_CMD=$(get_extract_begin_cmd "$ARCHIVES/$TOOL_ARCHIVE");
fi

### Call build_tool ###
local ARCHIVE_PATH=$ARCHIVES/$TOOL_ARCHIVE
local TMP_TOOL_DIR=$TMP/$TOOL_TMP_DIRNAME
local EXTRACT_SCRIPT="$TOOL_EXTRACT_CMD"
local RESULT_DIR=$UTILS/$TOOLS_DIRNAME/$TOOL_DIRNAME
local COMPILING_EXTRA_PARAMS="$TOOL_COMPILING_EXTRA_ARGS"
local MES_ARCHIVE_CHECK_FAIL="
ERROR: archive $ARCHIVE_PATH does not exist!

FAILED."

local MES_BUILD_FAIL="
ERROR: Building tool $NAME failed.

FAILED."

PRE_BUILD_CMD="$TOOL_PRE_BUILD_CMD"
PRE_MAKE_CMD=
PRE_INSTALL_CMD="$TOOL_PRE_INSTALL_CMD"
REQUIRED_COMPILE_P="$TOOL_REQUIRED_COMPILE_P"

extract_build_install "$ARCHIVE_PATH" "$TMP_TOOL_DIR" "$EXTRACT_SCRIPT" "$RESULT_DIR" \
"$COMPILING_EXTRA_PARAMS" "$MES_ARCHIVE_CHECK_FAIL" "$MES_BUILD_FAIL" "$PRE_BUILD_CMD" \
"$PRE_MAKE_CMD" "$PRE_INSTALL_CMD" "$REQUIRED_COMPILE_P"
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
ERROR: providing $NAME archive $TOOL_ARCHIVE failed!

FAILED"

provide_file "$FILE" "$PROCESS_CMD" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"
}

get_lisp_param () {
local REST_PARAM_PART="$1"
echo $(get_spec_val $CUR_LISP _$REST_PARAM_PART)
}

########## Created general "LISP_" parameters ########## 
local ALL_LISP_PARAMS="
VERSION
ARCH
OS
DIRNAME
LISPS_DIR
DIR
RELATIVE_PATH
LISPS_SOURCES
SOURCES_DIRNAME
LIB_DEPS
NO_LIB_DEPS_HINT
LISPS_COMPILERS
COMPILER_DIRNAME
NO_BUILDING_P
SELF_COMPILATION_P
PREBUILD_CMD
BUILD_CMD
INSTALL_CMD
HOME_VAR_NAME
BIN_DIR
CORE_BIN_DIR
BIN_BUILD_RESULT
BIN_IN_SOURCES
BIN_ARCHIVE
BIN_URL
BIN_POST_DOWNLOAD_CMD
RENAME_BIN_DOWNLOAD
RENAME_SRC_DOWNLOAD
SOURCE_ARCHIVE
SOURCE_URL
SRC_POST_DOWNLOAD_CMD
RENAME_SRC_DOWNLOAD
SRC_ARCHIVE_TYPE
BIN_ARCHIVE_TYPE
SRC_ARCHIVE_LOWERING_P
BIN_ARCHIVE_LOWERING_P
DEPS_ON_TOOLS"

for param in $ALL_LISP_PARAMS;
do 
    eval LISP_${param}="\"$(get_lisp_param $param)\""; 
done
##################### end filling LISP_ variables ##############
get_build_lisp_cmd () {
abs_path LISP_DIR
if [ $(downcase "$CUR_LISP") = "xcl" ]; 
then
    local PATH_TO_LIBS='\\\\/usr\\\\/lib\\\\/x86_64-linux-gnu\\\\/';

    echo "echo '\nATTENTION!!!\nPatching Makefile for correcting path to finded libpthread.so (copy will be saved as Makefile.backup';if ! [ -f kernel/Makefile.backup ];then cp kernel/Makefile kernel/Makefile.backup; fi;sed -i s/\\\\\\/usr\\\\\\/lib\\\\\\/libpthread.so/${PATH_TO_LIBS}libpthread.so/ kernel/Makefile;PATH=$UTILS:$PATH make && echo '(rebuild-lisp)' | ./xcl"; 
fi
if [ $(downcase "$CUR_LISP") = "ecl" ] || [ $(downcase "$CUR_LISP") = "mkcl" ]; 
then
    if ! [ "$LISP_PREBUILD_CMD" = "" ]; then LISP_PREBUILD_CMD="$LISP_PREBUILD_CMD; "; fi
    echo "${LISP_PREBUILD_CMD}PATH=$UTILS:$PATH ./configure --prefix $LISP_DIR && PATH=$UTILS:$PATH $LISP_BUILD_CMD"; 
fi
if [ $(downcase "$CUR_LISP") = "clisp" ]; 
then
    local LIBSIGSEGV_DIR=$UTILS/$LIBSIGSEGV_TOOL_DIR;
    echo "PATH=$UTILS:$PATH ./configure --with-libsigsegv-prefix=${LIBSIGSEGV_DIR} --prefix $LISP_DIR && PATH=$UTILS:$PATH $LISP_BUILD_CMD && $LISP_INSTALL_CMD"; 
fi
if [ $(downcase "$CUR_LISP") = "sbcl" ];
then 
    echo "PATH=$LISP_COMPILER_DIR/$LISP_BIN_DIR:$PATH $LISP_HOME_VAR_NAME=$LISP_COMPILER_DIR/$LISP_CORE_BIN_DIR $LISP_BUILD_CMD --prefix=$LISP_DIR"
fi
if [ $(downcase "$CUR_LISP") = "cmucl" ];
then 
    echo "
if [ \"$(lsb_release -si)\" = \"Ubuntu\" ] && [ \"$(lsb_release -sr)\" = \"11.04\" ];then
  if ! [ -f /usr/include/gnu/stubs-32.h ];then echo '    
ERROR: For building CMUCL in Ubuntu 11.04 please installing libc6-dev-i386.

FAILED.';exit 1;fi
fi
cd ../;PATH=$LISP_COMPILER_DIR/$LISP_BIN_DIR:$PATH src/tools/build.sh -C \"\" -o lisp";
fi
if [ $(downcase "$CUR_LISP") = "wcl" ];
then 
    local LD_DECORATOR_CONTENT='#!/bin/sh
CURARGS="$@"

DIR_FOR_LD=/usr/bin
echo "... Decoration calling ld from file: $0 ..."
echo "Current args for ld: $CURARGS"
NEW_ARGS="-L${LIBGMP_LIB_PATH} $@"
echo "New args for ld: $NEW_ARGS"
$DIR_FOR_LD/ld $NEW_ARGS
';
    echo "cd linux/src/build;rm -rf ../../bin ../../lib;mkdir --parents generated-for-build ../../bin ../../lib;echo '$LD_DECORATOR_CONTENT' > generated-for-build/ld;chmod u+x generated-for-build/ld;PATH=$SOURCES/$LISP_LISPS_SOURCES/$LISP_SOURCES_DIRNAME/linux/src/build/generated-for-build:$PATH C_INCLUDE_PATH=$UTILS/$GMP_TOOL_DIR/include:$UTILS/$BINUTILS_TOOL_DIR/include LIBGMP_LIB_PATH=$UTILS/$GMP_TOOL_DIR/lib BINUTILS_LIB_PATH=$UTILS/$BINUTILS_TOOL_DIR/lib LD_LIBRARY_PATH=$COMPILERS/$LISP_LISPS_COMPILERS/$LISP_COMPILER_DIRNAME/$LISP_OS/lib $COMPILERS/$LISP_LISPS_COMPILERS/$LISP_COMPILER_DIRNAME/$LISP_OS/bin/wcl -m 24000 < compile-cl-script.lisp";
fi

if [ $(downcase "$CUR_LISP") = "gcl" ];
then 
    local PDFLATEX_DECORATOR_CONTENT='#!/bin/sh
echo "... Interception calling pdflatex from file: $0 ...
Documentation not builded."';
    local TEX_DECORATOR_CONTENT='#!/bin/sh
echo "... Interception calling tex from file: $0 ...
Documentation not builded."';  
## --enable-ansi in configure options - failed.
    echo "mkdir --parents generated-for-build;echo '$PDFLATEX_DECORATOR_CONTENT' > generated-for-build/pdflatex;chmod u+x generated-for-build/pdflatex;echo '$TEX_DECORATOR_CONTENT' > generated-for-build/tex;chmod u+x generated-for-build/tex;PATH=$UTILS:$PATH ./configure --prefix $LISP_DIR && PATH=$SOURCES/$LISP_LISPS_SOURCES/$LISP_SOURCES_DIRNAME/generated-for-build:$UTILS:$PATH $LISP_BUILD_CMD"
fi

if [ $(downcase "$CUR_LISP") = "ccl" ]; then 
    echo "echo '(rebuild-ccl :full t)' | PATH=$UTILS:$PATH ./lx86cl64";
fi
}

get_install_lisp_cmd () {
abs_path LISP_DIR

if [ $(downcase "$CUR_LISP") = "ecl" ] || [ $(downcase "$CUR_LISP") = "clisp" ] || [ $(downcase "$CUR_LISP") = "mkcl" ] || [ $(downcase "$CUR_LISP") = "gcl" ];
then echo "$LISP_INSTALL_CMD"; fi

if [ $(downcase "$CUR_LISP") = "xcl" ]; then echo "cp xcl $LISP_DIR/xcl"; fi
if [ $(downcase "$CUR_LISP") = "sbcl" ]; then echo "sh install.sh"; fi

if [ $(downcase "$CUR_LISP") = "cmucl" ]; 
then echo "cp -r $SOURCES/$LISP_LISPS_SOURCES/$LISP_SOURCES_DIRNAME/../build-4 $LISP_DIR/build-4;mkdir --parents $LISP_DIR/src/i18n;cp $SOURCES/$LISP_LISPS_SOURCES/$LISP_SOURCES_DIRNAME/i18n/unidata.bin $LISP_DIR/src/i18n/unidata.bin";
fi
if [ $(downcase "$CUR_LISP") = "wcl" ]; then 
    echo "mv ../../bin $RESULT_DIR/bin;mv ../../lib $RESULT_DIR/lib";
fi

if [ $(downcase "$CUR_LISP") = "ccl" ]; then 
    echo "
cp $SOURCES/$LISP_LISPS_SOURCES/$LISP_SOURCES_DIRNAME/$LISP_BIN_BUILD_RESULT $LISP_DIR/$LISP_BIN_BUILD_RESULT
cp $SOURCES/$LISP_LISPS_SOURCES/$LISP_SOURCES_DIRNAME/${LISP_BIN_BUILD_RESULT}.image $LISP_DIR/${LISP_BIN_BUILD_RESULT}.image";
fi
}

get_run_lisp_cmd () {
abs_path LISP_DIR

if [ $(downcase "$CUR_LISP") = "xcl" ] || [ $(downcase "$CUR_LISP") = "ecl" ] || \
    [ $(downcase "$CUR_LISP") = "clisp" ] || [ $(downcase "$CUR_LISP") = "mkcl" ] || \
    [ $(downcase "$CUR_LISP") = "gcl" ] || [ $(downcase "$CUR_LISP") = "ccl" ]; 
then echo "$LISP_DIR/$LISP_RELATIVE_PATH"; fi

if [ $(downcase "$CUR_LISP") = "sbcl" ]; 
then echo "$LISP_DIR/$LISP_RELATIVE_PATH --core $LISP_DIR/lib/sbcl/sbcl.core"; fi

if [ $(downcase "$CUR_LISP") = "cmucl" ]; 
then echo "cd $LISP_DIR;./$LISP_RELATIVE_PATH"; fi

if [ $(downcase "$CUR_LISP") = "abcl" ]; then
    echo "cd $LISP_DIR; PATH=$UTILS:$PWD JAVA_HOME=$(dirname $(dirname $($SCRIPTS_DIR/realpath $UTILS/java))) java -jar abcl.jar"
fi    

if [ $(downcase "$CUR_LISP") = "wcl" ]; then
    echo "LD_LIBRARY_PATH=$LISP_DIR/lib:$LD_LIBRARY_PATH $LISP_DIR/bin/wcl";
fi    
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
