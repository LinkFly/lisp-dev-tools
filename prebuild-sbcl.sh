#!/bin/sh

. ./includes.sh

abs_path COMPILERS
abs_path SBCL_DIR

cd $COMPILERS/$SBCL_LISPS_COMPILERS/$SBCL_COMPILER_DIRNAME
INSTALL_ROOT=$SBCL_DIR sh install.sh