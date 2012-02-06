#!/bin/sh

get_build_lisp_cmd () {
abs_path LISP_DIR
local LISP_COMPILER_DIR="$COMPILERS/$LISP_LISPS_COMPILERS/$LISP_COMPILER_DIRNAME"

if [ $(downcase "$CUR_LISP") = "xcl" ]; 
then
    local PATH_TO_LIBS='\\\\/usr\\\\/lib\\\\/x86_64-linux-gnu\\\\/';
    local D='$';
    echo "
if [ \"$D(type lsb_release &> /dev/null && echo yes))\" = yes ] && [ \"$D(lsb_release -si)\" = \"Ubuntu\" ] && [ \"$D(lsb_release -sr)\" = \"11.04\" ];then
  echo '
ATTENTION!!!
Patching Makefile for correcting path to finded libpthread.so (copy will be saved as Makefile.backup'

  if ! [ -f kernel/Makefile.backup ];then
      cp kernel/Makefile kernel/Makefile.backup;
  fi

  sed -i s/\\\\\\/usr\\\\\\/lib\\\\\\/libpthread.so/${PATH_TO_LIBS}libpthread.so/ kernel/Makefile
fi
PATH=$UTILS:$PATH make && echo '(rebuild-lisp)' | ./xcl"; 
fi

if [ $(downcase "$CUR_LISP") = "ecl" ] || [ $(downcase "$CUR_LISP") = "mkcl" ]; 
then
    if ! [ "$LISP_PREBUILD_CMD" = "" ];then
	LISP_PREBUILD_CMD="$LISP_PREBUILD_CMD; ";
    fi
    echo "${LISP_PREBUILD_CMD}PATH=$UTILS:$PATH ./configure --prefix $LISP_DIR && PATH=$UTILS:$PATH $LISP_BUILD_CMD"; 
fi

if [ $(downcase "$CUR_LISP") = "clisp" ]; 
then
#    local LIBSIGSEGV_DIR=$UTILS/$LIBSIGSEGV_TOOL_DIR;
    local NCURSES_DIR=$UTILS/$NCURSES_TOOL_DIR
#    echo "PATH=$UTILS:$PATH ./configure --with-libsigsegv-prefix=${LIBSIGSEGV_DIR} --prefix $LISP_DIR && PATH=$UTILS:$PATH $LISP_BUILD_CMD && $LISP_INSTALL_CMD"; 
    echo "make distclean;rm -f src/config.cache;CPPFLAGS=-I${NCURSES_DIR}/include LDFLAGS=-L${NCURSES_DIR}/lib PATH=$UTILS:$PATH ./configure --ignore-absence-of-libsigsegv --prefix $LISP_DIR && PATH=$UTILS:$PATH $LISP_BUILD_CMD"; 
fi

if [ $(downcase "$CUR_LISP") = "sbcl" ];
then 
    if ! [ "$LISP_PREBUILD_CMD" = "" ];then
	LISP_PREBUILD_CMD="$LISP_PREBUILD_CMD;";
    fi
    echo "${LISP_PREBUILD_CMD}PATH=$UTILS:$LISP_COMPILER_DIR/$LISP_BIN_DIR:$PATH $LISP_HOME_VAR_NAME=$LISP_COMPILER_DIR/$LISP_CORE_BIN_DIR $LISP_BUILD_CMD --prefix=$LISP_DIR"
fi

if [ $(downcase "$CUR_LISP") = "cmucl" ];
then 
    local D='$';
    echo "
if [ \"$D(type lsb_release &> /dev/null && echo yes))\" = yes ] && [ \"$D(lsb_release -si)\" = \"Ubuntu\" ] && [ \"$D(lsb_release -sr)\" = \"11.04\" ];then
  if ! [ -f /usr/include/gnu/stubs-32.h ];then echo '    
ERROR: For building CMUCL in Ubuntu 11.04 please installing libc6-dev-i386.

FAILED.';exit 1;fi
fi
cd ../;PATH=$UTILS:$LISP_COMPILER_DIR/$LISP_BIN_DIR:$PATH src/tools/build.sh -C \"\" -o lisp";
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
    echo "
cd linux/src/build;rm -rf ../../bin ../../lib
mkdir --parents generated-for-build ../../bin ../../lib
echo '$LD_DECORATOR_CONTENT' > generated-for-build/ld;chmod u+x generated-for-build/ld
PATH=$SOURCES/$LISP_LISPS_SOURCES/$LISP_SOURCES_DIRNAME/linux/src/build/generated-for-build:$PATH C_INCLUDE_PATH=$UTILS/$GMP_TOOL_DIR/include:$UTILS/$BINUTILS_TOOL_DIR/include LIBGMP_LIB_PATH=$UTILS/$GMP_TOOL_DIR/lib BINUTILS_LIB_PATH=$UTILS/$BINUTILS_TOOL_DIR/lib LD_LIBRARY_PATH=$UTILS/$GMP_TOOL_DIR/lib:$COMPILERS/$LISP_LISPS_COMPILERS/$LISP_COMPILER_DIRNAME/$LISP_OS/lib $COMPILERS/$LISP_LISPS_COMPILERS/$LISP_COMPILER_DIRNAME/$LISP_OS/bin/wcl -m 24000 < compile-cl-script.lisp";
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
    echo "
mkdir --parents generated-for-build
echo '$PDFLATEX_DECORATOR_CONTENT' > generated-for-build/pdflatex
chmod u+x generated-for-build/pdflatex
echo '$TEX_DECORATOR_CONTENT' > generated-for-build/tex
chmod u+x generated-for-build/tex
PATH=$UTILS:$PATH ./configure --prefix $LISP_DIR && PATH=$SOURCES/$LISP_LISPS_SOURCES/$LISP_SOURCES_DIRNAME/generated-for-build:$UTILS:$PATH $LISP_BUILD_CMD"
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
then echo "
cp -r $SOURCES/$LISP_LISPS_SOURCES/$LISP_SOURCES_DIRNAME/../build-4 $LISP_DIR/build-4
mkdir --parents $LISP_DIR/src/i18n
cp $SOURCES/$LISP_LISPS_SOURCES/$LISP_SOURCES_DIRNAME/i18n/unidata.bin $LISP_DIR/src/i18n/unidata.bin";
fi

if [ $(downcase "$CUR_LISP") = "wcl" ]; then 
    echo "
mv ../../bin $RESULT_DIR/bin
mv ../../lib $RESULT_DIR/lib";
fi

if [ $(downcase "$CUR_LISP") = "ccl" ]; then 
    echo "
cp $SOURCES/$LISP_LISPS_SOURCES/$LISP_SOURCES_DIRNAME/$LISP_BIN_BUILD_RESULT $LISP_DIR/$LISP_BIN_BUILD_RESULT
cp $SOURCES/$LISP_LISPS_SOURCES/$LISP_SOURCES_DIRNAME/${LISP_BIN_BUILD_RESULT}.image $LISP_DIR/${LISP_BIN_BUILD_RESULT}.image";
fi
}

get_run_lisp_cmd () {
local LOAD_QUICKLISP
abs_path LISP_DIR

if ! [ -z "$LISP_BEGIN_OPTIONS" ];then
    LISP_BEGIN_OPTIONS=" $LISP_BEGIN_OPTIONS";
fi

if [ "$LISP_ENABLE_QUICKLISP" = "yes" ];then
    if ! [ -f "$QUICKLISP/setup.lisp" ];then
	echo "
ERROR: quicklisp can't be enabled - file $QUICKLISP/setup.lisp not found.
Please to run ./provide-quicklisp

FAILED."; exit 1;
    fi
    LOAD_QUICKLISP=" $LISP_LOAD_OPTION $QUICKLISP/setup.lisp";
fi

if [ $(downcase "$CUR_LISP") = "clisp" ];then
    echo "$LISP_DIR/${LISP_RELATIVE_PATH}${LISP_BEGIN_OPTIONS}${LOAD_QUICKLISP} -ansi"; 
fi

if [ $(downcase "$CUR_LISP") = "xcl" ] || [ $(downcase "$CUR_LISP") = "ecl" ] || \
    [ $(downcase "$CUR_LISP") = "mkcl" ] || \
    [ $(downcase "$CUR_LISP") = "gcl" ] || [ $(downcase "$CUR_LISP") = "ccl" ]; 
then 
    echo "$LISP_DIR/${LISP_RELATIVE_PATH}${LISP_BEGIN_OPTIONS}${LOAD_QUICKLISP}"; 
fi

if [ $(downcase "$CUR_LISP") = "sbcl" ];then
    echo "$LISP_DIR/$LISP_RELATIVE_PATH --core $LISP_DIR/lib/sbcl/sbcl.core${LISP_BEGIN_OPTIONS}${LOAD_QUICKLISP}";
fi

if [ $(downcase "$CUR_LISP") = "cmucl" ];then
    echo "
cd $LISP_DIR
./${LISP_RELATIVE_PATH}${LISP_BEGIN_OPTIONS}${LOAD_QUICKLISP}";
fi

if [ $(downcase "$CUR_LISP") = "abcl" ];then
    JAVA_REALPATH=$($SCRIPTS_DIR/realpath $UTILS/java);
    echo "
cd $LISP_DIR
PATH=$UTILS:$PWD JAVA_HOME=$(dirname $(dirname $JAVA_REALPATH)) java -jar abcl.jar${LISP_BEGIN_OPTIONS}${LOAD_QUICKLISP}"
fi    

if [ $(downcase "$CUR_LISP") = "wcl" ];then
    echo "LD_LIBRARY_PATH=$UTILS/$GMP_TOOL_DIR/lib:$LISP_DIR/lib:$LD_LIBRARY_PATH $LISP_DIR/${LISP_RELATIVE_PATH}${LISP_BEGIN_OPTIONS}${LOAD_QUICKLISP}";
fi    
}
