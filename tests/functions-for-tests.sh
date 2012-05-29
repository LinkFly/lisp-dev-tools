#!/bin/sh

### Using vars: ###
# PREFIX LISPS COMPILERS LISP_COMPILERS SOURCES LISP_SOURCES UTILS TOOLS_DIRNAME EMACS_LIBS 
# TESTS_LOG OPERATIONS_LOG TMP_SYMLINKS_DIR TMP_WORK_FILES_DIR TESTS_RESULTS 
# OLD_ARCHIVE_FILES OLD_LISP_DIRS OLD_LISP_COMPILERS_DIRS OLD_LISP_SOURCES_DIRS OLD_TOOLS_DIRS
# OLD_EMACS_LIBS_FILES OLD_EMACS_LIBS_DIRS OLD_LISP_LIBS_FILES OLD_LISP_LIBS_DIRS
# OLD_DIRS
# SHOW_DIRS_SIZES_P SHOW_DIRS_EXACT_SIZES_P
# EXCLUDE ONLY
##############

#################################################################################
#################################### FUNCTIONS ##################################
usage () {
echo "Using: 
run-tests [ --exclude-wget | --exclude-emacs | --exclude-modern-lisps | --exclude-young-lisps | --exclude-obsolete-lisps | --exclude-rebuild | --exclude=\"...\" ]
Example:
run-tests --exclude-emacs --exclude-obsolete-lisps --exclude=\"WGET CCL\"
(into exclude maybe be all lisps, and also: WGET EMACS SLIME REBUILD)"
exit 0
}

printlog () { echo "$1" | tee --append "$TESTS_LOG"; }
printflog () { printf "$1" | tee --append "$TESTS_LOG"; }

remove_tests_results () { 
    rm -f "$TESTS_LOG"
    rm -f "$OPERATIONS_LOG"
}

get_archive_files () { get_all_files "$ARCHIVES"; }

get_lisp_dirs () { get_all_dirs "$PREFIX/$LISPS" 2; }
get_lisp_compilers_dirs () { get_all_dirs "$COMPILERS/$LISP_COMPILERS" 2; } 
get_lisp_sources_dirs () { get_all_dirs "$SOURCES/$LISP_SOURCES" 2; }
get_tools_dirs () { get_all_dirs "$UTILS/$TOOLS_DIRNAME"; }

get_emacs_libs_files () { get_all_files "$EMACS_LIBS"; }
get_emacs_libs_dirs () { get_all_dirs "$EMACS_LIBS"; }
get_lisp_libs_files () { get_all_files "$LISP_LIBS"; }
get_lisp_libs_dirs () { get_all_dirs "$LISP_LIBS"; }


####### Saving and restore symlinks ############
save_symlinks () {
    printlog "
Saving symbolic links ..."
    rm -rf "$TMP_SYMLINKS_DIR"
    mkdir "$TMP_SYMLINKS_DIR"
    for link in $(find "$UTILS" -maxdepth 1 -name "*" -type l)
    do
	mv "$link" "$TMP_SYMLINKS_DIR/$(basename "$link")"
    done
    printlog "... ok"
}
restore_symlinks () {
    if test -d "$TMP_SYMLINKS_DIR"
    then

	printflog "
Restoring symbolic links ... "
	remove_all_symlinks "$UTILS"
	for link in $(get_all_symlinks "$TMP_SYMLINKS_DIR")
	do
	    mv "$link" "$UTILS/$(basename "$link")"
	done
	rm -rf "$TMP_SYMLINKS_DIR"
	printlog "OK.
"
    fi
}

full_restore_state () {
printlog "
Restoring state ...
-----------------------------------------------"

##### Restore symlinks #####
restore_symlinks

remove_new_files "$(cat "$OLD_ARCHIVE_FILES")" "$(get_archive_files)"
remove_new_dirs "$(cat "$OLD_LISP_DIRS")" "$(get_lisp_dirs)"
remove_new_dirs "$(cat "$OLD_LISP_COMPILERS_DIRS")" "$(get_lisp_compilers_dirs)"
remove_new_dirs "$(cat "$OLD_LISP_SOURCES_DIRS")" "$(get_lisp_sources_dirs)"
remove_new_dirs "$(cat "$OLD_TOOLS_DIRS")" "$(get_tools_dirs)"

remove_new_dirs "$(cat "$OLD_EMACS_LIBS_FILES")" "$(get_emacs_libs_files)"
remove_new_dirs "$(cat "$OLD_EMACS_LIBS_DIRS")" "$(get_emacs_libs_dirs)"
remove_new_dirs "$(cat "$OLD_LISP_LIBS_FILES")" "$(get_lisp_libs_files)"
remove_new_dirs "$(cat "$OLD_LISP_LIBS_DIRS")" "$(get_lisp_libs_dirs)"
printlog "-----------------------------------------------
... end restoring state - OK."
}

######## Checking is exist into --exclude parameter #########
is_into_p () {
for elt in $2
do
    if test "$elt" = "$1"
    then
	echo yes
	return
    fi    
done
echo no
}

is_into_exclude_p () { is_into_p "$(uppercase "$1")" "$EXCLUDE"; }
is_into_only_p () {
    if ! test -z "$ONLY"
    then
	is_into_p "$(uppercase "$1")" "$ONLY"
    else
	echo yes
    fi
}


############# Directories sizes ####################
get_dirs_sizes () {
    local EXTRA_ARGS="$2"
    echo "$(du "$1" --max-depth=3 --exclude="$TESTS_RESULTS" --exclude="$TMP_WORK_FILES_DIR" --exclude="$1/.git" $EXTRA_ARGS)"
}

get_git_dir_size () {
    local EXTRA_ARGS="$2"
    echo "$(du "$1/.git" --max-depth=0 $EXTRA_ARGS)"
}

show_dirs_sizes () {
    local EXTRA_MES="$1 running"
    if test "$SHOW_DIRS_SIZES_P" = "yes"
    then 
	echo "
---------------------- Directories sizes $EXTRA_MES tests ----------------------
$(get_dirs_sizes "$PREFIX" -h)
----- Directory .git size -----
$(get_git_dir_size "$PREFIX" -h)
---------------------------------------------------------------
"
    fi

if test "$SHOW_DIRS_EXACT_SIZES_P" = "yes"
    then 
	echo "
---------------------- Directories exact sizes $EXTRA_MES tests ----------------------
(Exclude dirs: "$TESTS_RESULTS" and "$TMP_WORK_FILES_DIR")
-------------------------------
$(get_dirs_sizes "$PREFIX" -b)
----- Directory .git size -----
$(get_git_dir_size "$PREFIX" -b)
---------------------------------------------------------------
"
    fi
}
####################################################

########################
get_all_size () {
    local tmp
    tmp=$(du "$PREFIX" --max-depth=0 --bytes --exclude="$TESTS_RESULTS" --exclude="$TMP_WORK_FILES_DIR")
    echo ${tmp%%"$PREFIX"}
}

remove_files_and_dirs () {
local NOT_DIRS_P=$3
if test "$NOT_DIRS_P" = "yes"
then
    local RM_ARGS="-f"
else 
    local RM_ARGS="-rf"
fi

for dir_or_file in $(get_new_files "$1" "$2")
do
    if test -e "$dir_or_file" 
    then
	printlog "Now running command: rm $RM_ARGS "$dir_or_file""
	rm $RM_ARGS "$dir_or_file"
    fi
done
}

remove_new_files () { remove_files_and_dirs "$1" "$2" yes; }
remove_new_dirs () { remove_files_and_dirs "$1" "$2"; }

####### Show changed dirs before restore ######
show_changed_dirs () {
    local TITLE="$1"
    printlog "
------- $TITLE ----------
$(describe_changed_dirs "$(cat "$OLD_DIRS")" "$(get_all_dirs "$PREFIX" 3)")
-----------------------------------------------------------"
}



################### Functions for provide and rebuild test #################
copy_dir_for_tests_if_exists () {
printlog "Copy temporary dir for tests (directory: $1):"
if test -d "$1"
then 
    local DIRNAME="$(dirname "$1")"
    local FILENAME="$(basename "$1")"
    local NEWNAME="$DIRNAME/${RESERV_COPY_PREFIX}$FILENAME"
    printlog "Create reserv command: rm -rf \"$NEWNAME\";mv \"$1\" \"$NEWNAME\""
    rm -rf "$NEWNAME";cp -r "$1" "$DIRNAME/${RESERV_COPY_PREFIX}$FILENAME"
fi
}

is_prefix_p () {
if test "${1#$RESERV_COPY_PREFIX}" = "$1"
then echo no;else echo yes;fi
}

remove_prefix_if_exists () {
local DIRNAME="$(dirname "$1")"
local FILENAME="$(basename "$1")"
if test "$(is_prefix_p "$FILENAME")" = "yes"
then 
    printlog "Rename command: mv \"$1\" \"$DIRNAME/${FILENAME#$RESERV_COPY_PREFIX}\""
    mv "$1" "$DIRNAME/${FILENAME#$RESERV_COPY_PREFIX}"
fi
}

remove_all_prefixes () {
printlog "Restore directories into: $1"
local DIRECTORY="$1"
for d in $(get_all_dirs "$DIRECTORY" 1)
do
    remove_prefix_if_exists "$d"
done
}
#remove_all_prefixes "/home/linkfly/Downloads/lisp-dev-tools/lisp/sbcl"

D=\$
get_lisp_compiler_dir () {
local CUR_LISP=$(uppercase $1)
local LISPS_COMPILERS="$(eval echo "$D${CUR_LISP}_LISPS_COMPILERS")"
local COMPILER_DIRNAME="$(eval echo "$D${CUR_LISP}_COMPILER_DIRNAME")"
if test -n "$LISPS_COMPILERS" && test -n "$COMPILER_DIRNAME"
then echo "$COMPILERS/$LISPS_COMPILERS/$COMPILER_DIRNAME"
fi
}

get_lisp_sources_dir () {
local CUR_LISP=$(uppercase $1)
local LISPS_SOURCES="$(eval echo "$D${CUR_LISP}_LISPS_SOURCES")"
local SOURCES_DIRNAME="$(eval echo "$D${CUR_LISP}_SOURCES_DIRNAME")"
if test -n "$LISPS_SOURCES" && test -n "$SOURCES_DIRNAME"
then 
    echo "$COMPILERS/$LISPS_SOURCES/$SOURCES_DIRNAME"
fi
}

get_lisp_dir () {
local CUR_LISP="$(uppercase $1)"
local LISP_DIR="$(eval echo "$D${CUR_LISP}_DIR")"
if test -n "$LISP_DIR"
then 
    echo "$PREFIX/$LISP_DIR"
fi
}

prepare_for_build () {
local CUR_LISP=$(uppercase $1)
local D=\$
printlog "Preparing before build lisp-system $CUR_LISP:"
copy_dir_for_tests_if_exists "$(get_lisp_compiler_dir $CUR_LISP)"
copy_dir_for_tests_if_exists "$(get_lisp_sources_dir $CUR_LISP)"
copy_dir_for_tests_if_exists "$(get_lisp_dir $CUR_LISP)"
}

clean_after_build () {
local CUR_LISP=$1
printlog "
Cleaning after builded lisp-system $CUR_LISP:"
local LISP_COMPILER_DIR="$(get_lisp_compiler_dir $CUR_LISP)"
local LISP_SOURCES_DIR="$(get_lisp_sources_dir $CUR_LISP)"
local LISP_DIR="$(get_lisp_dir $CUR_LISP)"
rm -rf "$LISP_COMPILER_DIR"
rm -rf "$LISP_SOURCES_DIR"
rm -rf "$LISP_DIR"
remove_all_prefixes "$(dirname "$LISP_COMPILER_DIR")"
remove_all_prefixes "$(dirname "$LISP_SOURCES_DIR")"
remove_all_prefixes "$(dirname "$LISP_DIR")"
printlog "Cleaning OK."
}
################## End functions for provide and rebuild test #################



##################### Tests functions #########################
general_test () {
# Using(and changing): PROVIDE_LISP_RES
local PROVIDE="$1"
local IF_OK="$2"
local DATETIME="
DATETIME: $(date)
"
printf "$DATETIME" >> "$OPERATIONS_LOG"
printflog "$DATETIME"

printlog "Test:
$PROVIDE
    ... "
local RESULT="$(eval "$PROVIDE" 2>&1 | tee --append "$OPERATIONS_LOG" | tail -n1)"

TESTS_AMOUNT=$((TESTS_AMOUNT + 1))

if test "ALREADY." = "$RESULT";then
ALREADY=$(($ALREADY + 1))
printflog "PASS(ALREADY)"
printlog
PROVIDE_LISP_RES=$CONST_ALREADY
return 0
fi

if test "OK." = "$RESULT";then
    PASS=$(($PASS + 1))
    printflog "PASS";printlog

    if test "$IF_OK" != "";then 
	general_test "$IF_OK";
    fi 	

PROVIDE_LISP_RES=0
return 0;
fi

FAIL=$(($FAIL + 1))
FAILED_TESTS="$FAILED_TESTS
$PROVIDE"
printlog FAIL
PROVIDE_LISP_RES=1
return 1
}

# Test running lisp-system:
test_run_lisp () {
local CUR_LISP=$1
if test -z "$CUR_LISP";then CUR_LISP=sbcl;fi
CUR_LISP=$(uppercase $CUR_LISP)
local RUN_SCRIPT="./run-lisp"
local RESULT=
if test "$CUR_LISP" = "WCL" || test "$CUR_LISP" = "XCL"
then
######### Specific test for WCL or XCL ###########
    local TEST_CODE=
    local TAIL_ARG="-n5"
    if test "$CUR_LISP" = "WCL";then TAIL_ARG="-n5";fi
    if test "$CUR_LISP" = "XCL";then TAIL_ARG="-n4";fi
    local TEST_CODE='echo "(progn (terpri) (princ 100) (terpri) (princ (quote some)))" | LISP='"$CUR_LISP"' ./run-lisp | tail '"$TAIL_ARG"' | head -n2'
    printflog "Test run-lisp:
${TEST_CODE}\n\n"
    printlog "Evaluated command line: none"
    printflog "Tests into running lisp-system:\n"
    RESULT="$(eval $TEST_CODE)"    
##################################################
else
    local TEST_PARAMS="--common-load $FILE_FOR_LOAD --common-eval '(progn (princ (quote some)) (terpri))' --common-quit"
    local TEST_CODE="LISP=$CUR_LISP $RUN_SCRIPT $TEST_PARAMS"
    printflog "Test run-lisp:
${TEST_CODE}\n\n"
    printlog "Evaluated command line: 
----------------------------------------------
$(eval GET_CMD_P=yes $TEST_CODE)
----------------------------------------------\n"

    printflog "Tests into running lisp-system:\n"
    if test "$CUR_LISP" = "CLISP"
    then
######### Specific getting result for CLISP ###########
	local TMPLINES="$(eval $TEST_CODE | tail -n7)"
	RESULT=$(echo "$TMPLINES" | head -n1)
	RESULT="$RESULT
$(echo "$TMPLINES" | head -n4 | tail -n1)"
##################################################
    else
	RESULT="$(eval $TEST_CODE | tail -n2)"
    fi
fi

TESTS_AMOUNT=$((TESTS_AMOUNT + 1))

if test "$RESULT" = "100
SOME"
then
    PASS=$((PASS + 1))
    printflog PASS
else 
    FAIL=$((FAIL + 1))
    printlog FAIL
    return 1
fi
echo | tee --append "$TESTS_LOG"
}

concrete_lisp_test () {
# Using(and changing by general_test): PROVIDE_LISP_RES
local CUR_LISP="$(uppercase $1)"
printlog "Testing lisp-system $CUR_LISP:"

prepare_for_build $CUR_LISP		

### !!! Function general_test changed PROVIDE_LISP_RES
general_test "LISP=$CUR_LISP ./provide-lisp"
### !!! PROVIDE_LISP_RES - changed

test_run_lisp $CUR_LISP
if test "$PROVIDE_LISP_RES" != "$CONST_ALREADY"
then general_test "LISP=$CUR_LISP ./remove-lisp"
fi

clean_after_build $CUR_LISP	

#(reserved for future)general_test ./provide-swank ./remove-swank
}
###################### End test functions #########################


rebuild_lisp_test () {
# Using(and changing by general_test): PROVIDE_LISP_RES
local CUR_LISP="$(uppercase $1)"
printlog "Testing rebuild lisp-system $CUR_LISP:"

prepare_for_build $CUR_LISP		

### !!! Function general_test changed PROVIDE_LISP_RES
general_test "LISP=$CUR_LISP ./rebuild-lisp"
### !!! PROVIDE_LISP_RES - changed
test_run_lisp $CUR_LISP

clean_after_build $CUR_LISP	
}



#################################################################################
################################# END FUNCTIONS #################################