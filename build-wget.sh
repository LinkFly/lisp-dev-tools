#!/bin/sh

######### Configuring variables ####
WGET_TARGZ_ARCHIVE=wget-1.13.4.tar.gz
UTILS_DIRNAME=utils
TMP_DIRNAME="tmp"
TMP_WGET_DIRNAME="wget-compiling"
########## Computing variables ####
START_DIR=$PWD
WGET_TARGZ_ARCHIVE_PATH=$PWD/$WGET_TARGZ_ARCHIVE
UTILS_DIR=$PWD/$UTILS_DIRNAME

TMP_DIR=$PWD/$TMP_DIRNAME
TMP_WGET_DIR=$TMP_DIR/$TMP_WGET_DIRNAME

WGET_SOURCE_DIR= #computing later
################################
### Clean ###
rm -rf $TMP_WGET_DIRNAME/*
rm -f $UTILS_DIR/wget
#############
mkdir --parents $TMP_WGET_DIR
cd $TMP_WGET_DIR/ && tar -xzvf $WGET_TARGZ_ARCHIVE_PATH
cd $START_DIR
WGET_SOURCE_DIR=$TMP_WGET_DIR/$(ls $TMP_WGET_DIR)
mkdir --parents $WGET_SOURCE_DIR
cd $WGET_SOURCE_DIR
./configure --without-ssl
make
cp src/wget $UTILS_DIR/usr/bin/wget

### Clean ###
rm -rf $TMP_WGET_DIR/*
#############