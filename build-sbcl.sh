#!/bin/sh

##### Include scripts #####
. ./global-params.conf
. ./tools.conf
. ./utils.sh

######### Configuring variables ####
LISP_DIRNAME=lisp
SBCL_LISPS_DIRNAME=sbcl
SBCL_LISPS_SOURCES_DIRNAME=sbcl-sources
SBCL_BIN_DIRNAME=src/runtime
SBCL_CORE_BIN_DIRNAME=output
SBCL_BIN_BUILD_RESULT=src/runtime/sbcl

########## Computing variables #####
abs_path COMPILERS
abs_path SOURCES
abs_path SBCL_DIR
SBCL_COMPILER_DIR=$COMPILERS/$SBCL_LISPS_COMPILERS/$SBCL_COMPILER_DIRNAME
SBCL_SOURCES_DIR=$SOURCES/$SBCL_LISPS_SOURCES/$SBCL_SOURCES_DIRNAME
SBCL_BIN_DIR=$SBCL_COMPILER_DIR/$SBCL_BIN_DIRNAME
SBCL_CORE_BIN_DIR=$SBCL_COMPILER_DIR/$SBCL_CORE_BIN_DIRNAME
SBCL_BIN_BUILD_RESULT=$SBCL_SOURCES_DIR/$SBCL_BIN_BUILD_RESULT

########## Checking sources directory #####
if [ -d $SBCL_SOURCES_DIR ];
then echo "OK - sources is found.
Directory: $SBCL_SOURCES_DIR";
else echo "ERROR: directory $SBCL_SOURCES_DIR does not exist! Please running provide-sources-sbcl.sh"
fi

######### Building sbcl sources ###########
echo "Building $SBCL_SOURCES_DIR ..."
cd $SBCL_SOURCES_DIR
RESULT=1
PATH=$SBCL_BIN_DIR:$PATH SBCL_HOME=$SBCL_CORE_BIN_DIR sh make.sh --prefix=$SBCL_DIR && RESULT=0

######### Checking building sources ###########
if [ $RESULT = 0 ];
then echo "Building sbcl from $SBCL_SOURCES_DIRNAME successful.
Directory containded sources: $SBCL_SOURCES_DIR";
else echo "ERROR: Building sbcl from $SBCL_SOURCES_DIRNAME failed.
Directory contained sources: $SBCL_SOURCES_DIR"; return 1;
fi

echo "Coping results into $SBCL_DIR ..."
mkdir --parents $SBCL_DIR
RESULT=1
sh install.sh && RESULT=0

######### Checking coping building result ###########
if [ $RESULT = 0 ];
then echo "Coping building sbcl results into $SBCL_DIR successful.
Directory with results: $SBCL_DIR";
else echo "ERROR: Coping building sbcl results into $SBCL_DIR failed.
Directory containded sources: $SBCL_SOURCES_DIR"; return 1;
fi
