#!/bin/sh

###### Includes ########
. ./includes.sh
. ./core.sh

########
abs_path LISP_DIR

if [ $(downcase "$CUR_LISP") = "sbcl" ];
then
    cd $COMPILERS/$LISP_LISPS_COMPILERS/$LISP_COMPILER_DIRNAME;
    INSTALL_ROOT=$LISP_DIR sh install.sh;
else echo "
ERROR: Not implemented.

FAILED.";
fi
