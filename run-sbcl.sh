#!/bin/sh

######### Configuring variables ####
LISP_DIRNAME=lisp
SBCL_LISPS_DIRNAME=sbcl
SBCL_DIRNAME=sbcl-1.0.52
SBCL_PATH=$PWD/$LISP_DIRNAME/$SBCL_LISPS_DIRNAME/$SBCL_DIRNAME/bin/sbcl
SBCL_CORE_PATH=$PWD/$LISP_DIRNAME/$SBCL_LISPS_DIRNAME/$SBCL_DIRNAME/lib/sbcl/sbcl.core
####################################

$SBCL_PATH --core $SBCL_CORE_PATH "$@"