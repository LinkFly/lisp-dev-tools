#!/bin/sh
cd $(dirname $0)
. ./includes.sh

###################################
#### Checking dependecies libs ####
local LIBS="$LISP_LIB_DEPS"
check_dep_libs "$LIBS"

#### Resolving dependencies #######
resolve_deps "$LISP_DEPS_ON_TOOLS"

########
abs_path LISP_DIR

COMPILER_DIR="$COMPILERS/$LISP_LISPS_COMPILERS/$LISP_COMPILER_DIRNAME"


if [ $(elt_in_set_p $(downcase "$CUR_LISP") "sbcl abcl") = "no" ]
then echo "
ERROR: Not implemented.

FAILED."; exit 1;
fi

RESULT=1
rm -rf $LISP_DIR && \
mkdir --parents $LISP_DIR && \
case $(downcase "$CUR_LISP") in
    "sbcl")
	cd $COMPILER_DIR;
	INSTALL_ROOT=$LISP_DIR $LISP_INSTALL_CMD;
	;;
    "abcl")
	cp $COMPILERS/$LISP_LISPS_COMPILERS/$LISP_COMPILER_DIRNAME/abcl.jar $LISP_DIR/abcl.jar;
	cp $COMPILERS/$LISP_LISPS_COMPILERS/$LISP_COMPILER_DIRNAME/abcl-contrib.jar $LISP_DIR/abcl-contrib.jar;
	;;
esac && RESULT=0;

if [ $RESULT = 1 ]; then 
    rm -rf "$LISP_DIR"; 
    echo "\nERROR: not prebuilded.\n\nFAILED."; 
    exit 1; 
else echo "\nPrebuilded success.\n\nOK."
fi

