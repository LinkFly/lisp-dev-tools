#!/bin/sh

#### Using entities ####
# PREFIX from dirs.conf
#

######## Function definitions ######
elt_in_set_p () {
local ELEMENT="$1"
local SET="$2"

for lisp in $SET; do
    if [ "$lisp" = "$ELEMENT" ]; then
	echo "yes"; return 0; 
    fi
done;
echo "no";
}

check_args () {
local ARGS
local ARGS_NEED
local MES_CHECK_START
local MES_SUCCESS
local MES_FAILED

ARG=$1
ARGS_NEED=$2
MES_CHECK_START=$3
MES_SUCCESS=$4
MES_FAILED=$5

printf "$MES_CHECK_START"
if [ "$SRC_OR_BIN" = "" ];
then echo $MES_FAILED; return 1;
else 
    for arg in $ARGS_NEED;
    do
	if [ $arg = $ARG ];
        then echo $MES_SUCCESS; return 0;
	fi
    done;
    echo $MES_FAILED; return 1;
fi
}

subdir_to_dir () {
local DIR=$1
local SUBDIR=$(ls $DIR)
for f in $(ls -A $DIR/$SUBDIR); 
do mv $DIR/$SUBDIR/$f $DIR/$f; done
rm -rf $DIR/$SUBDIR
}

uppercase () {
echo $1 | tr 'a-z' 'A-Z'
}

downcase () {
echo $1 | tr 'A-Z' 'a-z'
}

esc_slashes () {
echo "$(echo $1 | sed 's/\//\\\//g')"
}

get_n_arg () {
### Parameters ###
local ARRAY="$1"
local POS=$2
##########
local D=\$
echo $(eval "echo "$ARRAY" | awk '{print $D$POS}'")
}

vardef () {
local D
local TMP
D=\$
eval TMP=$D$1
if [ "$TMP" = "" ];
then eval $1=$2;
fi
}


fst_char () {
echo $1 | cut -c 1
}

abs_path_p () {
local TMP
TMP=$(fst_char $1)
if [ $TMP ]; then 
  if [ "$TMP" = "/" ];
  then echo "yes";
  else echo "no";
  fi
fi
}

abs_path () {
local PATH_SYM=$1

local ABS_PATH_TMP
local ABS_PATH_ABS_P
local ABS_PATH_D=\$

eval ABS_PATH_TMP=$ABS_PATH_D$PATH_SYM
if [ "$ABS_PATH_TMP" = "" ]; then return 0; fi
ABS_PATH_ABS_P=$(abs_path_p $ABS_PATH_TMP)
if [ $ABS_PATH_ABS_P = "no" ]; then
    eval $1=$PREFIX/$ABS_PATH_TMP;
fi

}

get_spec_val () {
### Parameters ###
local EVALUATED_PART=$1
local REST_PART=$2
######
local D=\$
echo $(eval echo $D$(uppercase $EVALUATED_PART)$REST_PART)
}

provide_dir_or_file () {
local DIR_OR_FILE="$2"
local PROCESS_CMD="$3"
local MES_START_PROCESS="$4"
local MES_ALREADY="$5"
local MES_SUCCESS="$6"
local MES_FAILED="$7"

echo "$MES_START_PROCESS"
if ! [ "$DIR_OR_FILE" = "" ] && [ -$1 $DIR_OR_FILE ];
then 
    echo "$MES_ALREADY";
else 
    RESULT=1;    
    eval "$PROCESS_CMD" && RESULT=0;    
    if [ $RESULT = 0 ];
    then echo "$MES_SUCCESS"
    else echo "$MES_FAILED"; exit 1;
    fi
fi
}

provide_dir () {

local DIR="$1"
local PROCESS_CMD="$2"
local MES_START_PROCESS="$3"
local MES_ALREADY="$4"
local MES_SUCCESS="$5"
local MES_FAILED="$6"

provide_dir_or_file d "$DIR" "$PROCESS_CMD" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"
}

provide_file () {

local FILE="$1"
local PROCESS_CMD="$2"
local MES_START_PROCESS="$3"
local MES_ALREADY="$4"
local MES_SUCCESS="$5"
local MES_FAILED="$6"
provide_dir_or_file f "$FILE" "$PROCESS_CMD" "$MES_START_PROCESS" "$MES_ALREADY" "$MES_SUCCESS" "$MES_FAILED"
}

get_extract_begin_cmd () {
local FILE="$1"

local TYPE=$(file --brief --mime-type $FILE)
case "$TYPE" in
    "application/x-gzip") 
	echo "tar -xzvf";
	;;
    "application/x-bzip2")
	echo "tar -xjvf";
	;;
esac
}

get_extract_cmd () {
echo "$(get_extract_begin_cmd $1) $1"
}

extract_archive () {

#### Parameters ####
local EXTRACT_CMD="$1"
local ARCHIVE="$2"
local RESULT_DIR="$3"
local MES_CHECK_ALREADY_FAIL="$4"
local MES_CHECK_AR_FAIL="$5"
local MES_START_EXTRACTED="$6"
local MES_CHECK_RES_FAIL="$7"
local MES_CHECK_RES_SUCC="$8"
local ARCHIVE_LOWERING_P=$9

#### Other variables ####
local RESULT

######### Checking archive extracted ####### 
if [ -d "$RESULT_DIR" ];
then echo "$MES_CHECK_ALREADY_FAIL"; return 1;
fi

######### Checking archive file ####### 
if ! [ -f "$ARCHIVE" ];
then echo "$MES_CHECK_AR_FAIL"; return 1;
fi

######### Extracted archive file ####### 
echo $MES_START_EXTRACTED
RESULT=1
local CURPATH="$PWD"

mkdir --parents "$RESULT_DIR"
cd "$RESULT_DIR"
$EXTRACT_CMD $ARCHIVE && RESULT=0
if [ $RESULT = 0 ] && [ "$(ls $RESULT_DIR)" != "" ]
then 
    echo "$MES_CHECK_RES_SUCC"; 
    if [ "$ARCHIVE_LOWERING_P" = "yes" ];
    then subdir_to_dir $RESULT_DIR; fi
else rm -rf "$RESULT_DIR"; echo "$MES_CHECK_RES_FAIL"; return 1;
fi
cd "$CURPATH"
}


remove_dir () {
local DIR="$1"
local MES_SUCC="$2"
local MES_FAIL="$3"
local MES_ABSENCE="$4"

local RESULT

RESULT=1
if [ -d "$DIR" ];
then 
    rm -rf "$DIR" && RESULT=0;
    if ( ! [ -d $DIR ] ) && [ $RESULT = 0 ];
    then echo "$MES_SUCC";
    else echo "$MES_FAIL"; return 1;
    fi
else echo "$MES_ABSENCE";
fi

}

file_is_exist_p () {
local FILE_LINK_NAME="$1"
local UTILS_DIR="$2"

local FILE_REALPATH=$(readlink $UTILS_DIR/$FILE_LINK_NAME)

if [ "$FILE_REALPATH" != "" ] && [ $(abs_path_p "$FILE_REALPATH") = "no" ];
then FILE_REALPATH=$UTILS_DIR/$FILE_REALPATH
fi

if [ $FILE_REALPATH ] && ([ -d $FILE_REALPATH ] || [ -f $FILE_REALPATH ]); 
then echo "yes"; 
else echo "no";
fi
}

links_is_exist_p () {
local LINKS="$1"
local DIR="$2"
for link in $LINKS
do 
    if ! [ "$(file_is_exist_p $link $DIR)" = "yes" ];
    then echo "no"; return 0;
    fi
done
echo "yes"
}

build_if_no () {
###### Parameters ######
local FILE_LINK_NAMES="$1"
local UTILS_DIR="$2"
local BUILD_CMD="$3"
local BUILDED_FILES="$4"
local MES_ALREADY="$5"
local MES_BUILDED_FAIL="$6"
local MES_BUILDED_SUCC="$7"
########################

local ALL_FILES_EXIST_P=$(links_is_exist_p "$FILE_LINK_NAMES" "$UTILS_DIR")

########## Building if does not exist #######
if [ "$ALL_FILES_EXIST_P" = "yes" ];
  then echo "$MES_ALREADY";
  else
    RESULT=1;
    eval "$BUILD_CMD && RESULT=0";

    if [ $RESULT = 0 ];
    then
	local N=0;
	for link in $FILE_LINK_NAMES;
	do
	    echo ln -s $(get_n_arg "$BUILDED_FILES" $N) $UTILS_DIR/$link;

	    N=$(($N + 1));
	    rm -f $UTILS_DIR/$link && ln -s $(get_n_arg "$BUILDED_FILES" $N) $UTILS_DIR/$link;
	done
	echo "$MES_BUILDED_SUCC";
    else echo "$MES_BUILDED_FAIL"; return 1;
    fi
fi
}

build () {

######## Parameters #########
local SOURCES_DIR="$1"
local RESULT_DIR="$2"
local PROCESS_CMD="$3"

local INSTALL_CMD="$4"
local BIN_BUILD_RESULT="$5"
local MES_ALREADY="$6"
local MES_NOT_EXIST_SRC_FAIL="$7"
local MES_START_BUILDING="$8"
local MES_BUILDING_SUCC="$9"
local MES_BUILDING_FAIL="$10"
local MES_COPING_RESULT_SUCC="$11"
local MES_COPING_RESULT_FAIL="$12"

local CURPATH="$PWD"
########## Checking not builded ###########
#if [ -d "$RESULT_DIR" ];
#then echo "$MES_ALREADY"; return 0;
#fi

########## Checking sources directory #####
if ! [ -d "$SOURCES_DIR" ];
then echo "$MES_NOT_EXIST_SRC_FAIL"; return 1;
fi

######### Building sbcl sources ###########
echo "$MES_START_BUILDING"
cd "$SOURCES_DIR"
RESULT=1
eval "$PROCESS_CMD && RESULT=0"

#echo "$PROCESS_CMD && RESULT=0"
#echo $(pwd)
#echo "$BIN_BUILD_RESULT"
#exit 1;
#RESULT=0


######### Checking building sources ###########
if [ $RESULT = 0 ] && [ -f "$BIN_BUILD_RESULT" ];
then echo "$MES_BUILDING_SUCC";
else echo "$MES_BUILDING_FAIL"; return 1;
fi

######## Coping results #######################
echo "\nCoping results into $RESULT_DIR ..."
mkdir --parents "$RESULT_DIR"
RESULT=1
eval "$INSTALL_CMD && RESULT=0" 

######### Checking coping building result #####
if [ $RESULT = 0 ] && [ -d "$RESULT_DIR" ];
then echo "$MES_COPING_RESULT_SUCC";
else echo "$MES_COPING_RESULT_FAIL"; remove -rf "$RESULT_DIR"; exit 1;
fi
cd "$CURPATH"
}

change_param () {
local PARAM="$1"
local FILE="$2"
local OLD_VAL="$3"
local NEW_VAL="$4"

local CHANGE_REGEX="s/$PARAM=$OLD_VAL/$PARAM=$NEW_VAL/g"
sed -i $CHANGE_REGEX $FILE
}

extract_build_install () {
#### Parameters ####
local ARCHIVE_PATH="$1"
local TMP_TOOL_DIR="$2"
local EXTRACT_SCRIPT="$3"
local RESULT_DIR="$4"
local COMPILING_EXTRA_PARAMS="$5"
local MES_ARCHIVE_CHECK_FAIL="$6"
local MES_BUILD_FAIL="$7"
#### Optional parameters ####
local PRE_BUILD_CMD="$8"
local PRE_MAKE_CMD="$9"
local PRE_INSTALL_CMD="$10"
local REQUIRED_COMPILE_P="$11"

local START_DIR=$PWD
local RESULT
##### Checking archive #########
if ! [ -f "$ARCHIVE_PATH" ] || [ "$ARCHIVE_PATH" = "" ];
then echo "$MES_ARCHIVE_CHECK_FAIL"; return 1;
fi

################################
rm -rf $TMP_TOOL_DIR
mkdir --parents $TMP_TOOL_DIR
cd $TMP_TOOL_DIR
RESULT=1
$EXTRACT_SCRIPT $ARCHIVE_PATH && RESULT=0;
if [ $RESULT = 1 ]; then
    echo "$MES_BUILD_FAIL"; rm -rf $TMP_TOOL_DIR; exit 1;
fi

if [ "$REQUIRED_COMPILE_P" = "yes" ]; then
    cd $TMP_TOOL_DIR/$(ls $TMP_TOOL_DIR);

    if ! [ "$PRE_BUILD_CMD" = "" ];
    then PRE_BUILD_CMD="$PRE_BUILD_CMD && ";fi

    if ! [ "$PRE_MAKE_CMD" = "" ];
    then PRE_MAKE_CMD="$PRE_MAKE_CMD && ";fi 

    if ! [ "$PRE_INSTALL_CMD" = "" ];
    then PRE_INSTALL_CMD="$PRE_INSTALL_CMD && ";fi

    mkdir --parents $RESULT_DIR
    local RESULT=1
    eval "$PRE_BUILD_CMD./configure --prefix $RESULT_DIR $COMPILING_EXTRA_PARAMS && ${PRE_MAKE_CMD}make && ${PRE_INSTALL_CMD}make install && RESULT=0"

    if [ $RESULT = 1 ]; then
	echo "$MES_BUILD_FAIL";  rm -rf $RESULT_DIR; exit 1;
    fi
else 
    RESULT=1;
    cp -r $(ls $TMP_TOOL_DIR) $RESULT_DIR && RESULT=0;

    if [ $RESULT = 1 ] || [ ! -d $RESULT_DIR ]; then
	echo "$MES_BUILD_FAIL"; rm -rf $TMP_TOOL_DIR; exit 1;
    fi
fi

cd $START_DIR
rm -rf $TMP_TOOL_DIR
}

