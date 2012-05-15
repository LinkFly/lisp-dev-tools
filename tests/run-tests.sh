#!/bin/sh
cd "$(dirname "$0")"
. ./get-new-files.sh

SHOW_DIRS_SIZES_P=${SHOW_DIRS_SIZES_P:-yes}
SHOW_DIRS_EXACT_SIZES_P=${SHOW_DIRS_EXACT_SIZES_P:-yes}

RESULT_MESSAGE="Tests aborted.

FAILED."
trap "cleanup" EXIT INT

###################### Initialization #########################
if test -z "$TESTS_RESULTS"
then 
    TESTS_RESULTS="$(pwd)/tests-results"
fi
TESTS_LOG="$TESTS_RESULTS/tests-log.txt"
rm -rf "$TESTS_LOG"
OPERATIONS_LOG="$(pwd)/tests-results/operations-log.txt"
rm -rf "$OPERATIONS_LOG"
FILE_FOR_LOAD="$(pwd)/for-tests.lisp"
cd ../sh

. ./includes.sh

echo "Tests running ...

" | tee --append "$TESTS_LOG"

############# Directories sizes ####################
get_dirs_sizes () {
    local EXTRA_ARGS="$1"
    echo "$(du "$PREFIX" --max-depth=3 --exclude="$TESTS_RESULTS" $EXTRA_ARGS)"
}

show_dirs_sizes () {
    local EXTRA_MES="$1 running"
    if test "$SHOW_DIRS_SIZES_P" = "yes"
    then 
	echo "
---------------------- Directories sizes $EXTRA_MES tests ----------------------
$(get_dirs_sizes -h)
---------------------------------------------------------------
"
    fi

if test "$SHOW_DIRS_EXACT_SIZES_P" = "yes"
    then 
	echo "
---------------------- Directories exact sizes $EXTRA_MES tests ----------------------
$(get_dirs_sizes --bytes)
---------------------------------------------------------------
"
    fi
}
echo "$(show_dirs_sizes before)"  | tee --append "$TESTS_LOG"
####################################################

########################
get_all_size () {
    local tmp
    tmp=$(du "$PREFIX" --max-depth=0 --bytes --exclude="$TESTS_RESULTS")
    echo ${tmp%%"$PREFIX"}
}
BEFORE_SIZE=$(get_all_size)

########################
get_archive_files () { get_all_files "$ARCHIVES"; }
get_lisp_dirs () { get_all_dirs "$PREFIX/$LISPS" 2; }
get_lisp_compilers_dirs () { get_all_dirs "$COMPILERS/$LISP_COMPILERS" 2; } 
get_lisp_sources_dirs () { get_all_dirs "$SOURCES/$LISP_SOURCES" 2; }
get_tools_dirs () { get_all_dirs "$UTILS/$TOOLS_DIRNAME"; }

get_emacs_libs_files () { get_all_files "$EMACS_LIBS"; }
get_emacs_libs_dirs () { get_all_dirs "$EMACS_LIBS"; }
get_lisp_libs_files () { get_all_files "$LISP_LIBS"; }
get_lisp_libs_dirs () { get_all_dirs "$LISP_LIBS"; }

OLD_ARCHIVE_FILES="$(get_archive_files)"
OLD_LISP_DIRS="$(get_lisp_dirs)"
OLD_LISP_COMPILERS_DIRS="$(get_lisp_compilers_dirs)"
OLD_LISP_SOURCES_DIRS="$(get_lisp_sources_dirs)"
OLD_TOOLS_DIRS="$(get_tools_dirs)"

OLD_EMACS_LIBS_FILES="$(get_emacs_libs_files)"
OLD_EMACS_LIBS_DIRS="$(get_emacs_libs_dirs)"
OLD_LISP_LIBS_FILES="$(get_lisp_libs_files)"
OLD_LISP_LIBS_DIRS="$(get_lisp_libs_dirs)"

remove_new_dirs () {
OLD_DIRS="$1"
DIRS="$2"
for dir in $(get_new_files "$1" "$2")
do
    echo "Now running command: rm -rf "$dir"" | tee --append "$TESTS_LOG"
    rm -rf "$dir"
done
}

########################
#OLD_FILES="$(get_all_files "$PREFIX")"
OLD_FILES=empty
OLD_DIRS="$(get_all_dirs "$PREFIX" 5)"
FILES=
DIRS=
########################

####### Need cleanup ############
# !!!
### Need save links for cleanup ....
./remove-links.sh
export NO_COPY_LINKS_P=yes
#################################

cd ..
###############################################################

################### Defining cleanup ##############################
ALREADY_CLEANUP_P=
cleanup () {
### Singleton ###
if test "$ALREADY_CLEANUP_P" = "yes";then exit;fi
#########################

#################### Show changed dirs before restore #####################
echo "---------------------------- Changed directories before restore state -----------------------------------" | tee --append "$TESTS_LOG"
FILES=empty
DIRS="$(get_all_dirs "$PREFIX" 5)"
echo "$(describe_changed_files_or_dirs "$OLD_FILES" "$FILES" "$OLD_DIRS" "$DIRS")
---------------------------------------------------------------------------------------------------------------
" | tee --append "$TESTS_LOG"
##############################################################
echo "Restoring state ...
-----------------------------------------------" | tee --append "$TESTS_LOG"
remove_new_dirs "$OLD_ARCHIVE_FILES" "$(get_archive_files)"
remove_new_dirs "$OLD_LISP_DIRS" "$(get_lisp_dirs)"
remove_new_dirs "$OLD_LISP_COMPILERS_DIRS" "$(get_lisp_compilers_dirs)"
remove_new_dirs "$OLD_LISP_SOURCES_DIRS" "$(get_lisp_sources_dirs)"
remove_new_dirs "$OLD_TOOLS_DIRS" "$(get_tools_dirs)"

remove_new_dirs "$OLD_EMACS_LIBS_FILES" "$(get_emacs_libs_files)"
remove_new_dirs "$OLD_EMACS_LIBS_DIRS" "$(get_emacs_libs_dirs)"
remove_new_dirs "$OLD_LISP_LIBS_FILES" "$(get_lisp_libs_files)"
remove_new_dirs "$OLD_LISP_LIBS_DIRS" "$(get_lisp_libs_dirs)"
echo "-----------------------------------------------
... end restoring state." | tee --append "$TESTS_LOG"
#################### Show changed dirs after restore #####################
echo "---------------------------- Changed directories after restore state -----------------------------------" | tee --append "$TESTS_LOG"
FILES=empty
DIRS="$(get_all_dirs "$PREFIX" 5)"
echo "$(describe_changed_files "$OLD_FILES" "$FILES" "$OLD_DIRS" "$DIRS")
--------------------------------------------------------------------------------------------------------------
" | tee --append "$TESTS_LOG"
###########################################################################

######################################################### Checking size #########################################

############# Directories sizes ####################
echo "$(show_dirs_sizes after)"  | tee --append "$TESTS_LOG"
####################################################

BEFORE_RESULT_MESSAGE="
---------------------------- Checking size -----------------------------------"
AFTER_SIZE=$(get_all_size)
if [ $AFTER_SIZE = $BEFORE_SIZE ]
then
    BEFORE_RESULT_MESSAGE="$BEFORE_RESULT_MESSAGE
Checking size - OK."
else 
    BEFORE_RESULT_MESSAGE="$BEFORE_RESULT_MESSAGE
ERROR: size lisp-dev-tools after runned tests more than before run tests.
BEFORE_SIZE: $BEFORE_SIZE
AFTER_SIZE: $AFTER_SIZE 
DIFFERENCE: $(( $AFTER_SIZE - $BEFORE_SIZE ))

Checking size - FAILED."
fi
#################################################################################################################

######### Construct and output RESULT_MESSAGE here ##########
RESULT_MESSAGE="$BEFORE_RESULT_MESSAGE
------------------------------------------------------------------------------

$RESULT_MESSAGE"

echo "$RESULT_MESSAGE" | tee --append "$TESTS_LOG"
######################################################

ALREADY_CLEANUP_P=yes
exit
}
################### End defining cleanup ##############################

usage () {
echo "Using: 
run-tests [ --exclude-wget | --exclude-emacs | --exclude-modern-lisps | --exclude-young-lisps | --exclude-obsolete-lisps | --exclude-rebuild | --exclude=\"...\" ]
Example:
run-tests --exclude-emacs --exclude-obsolete-lisps --exclude=\"WGET CCL\"
(into exclude maybe be all lisps, and also: WGET EMACS SLIME REBUILD)"
exit 0
}

TESTS_AMOUNT=0
PASS=0
ALREADY=0
FAIL=0

CONST_ALREADY=10

REBUILD_FOR_LISPS="SBCL"

EXCLUDE=
EXCLUDE_WGET=
EXCLUDE_EMACS=
EXCLUDE_MODERN_LISPS=
EXCLUDE_YOUNG_LISPS=
EXCLUDE_OBSOLETE_LISPS=
EXCLUDE_REBUILD=

FAILED_TESTS=
PROVIDE_LISP_RES=

general_test () {
# Using(and changing): PROVIDE_LISP_RES
local PROVIDE="$1"
local IF_OK="$2"
local DATETIME="
DATETIME: $(date)
"
printf "$DATETIME" >> "$OPERATIONS_LOG"
printf "$DATETIME" >> "$TESTS_LOG"
printf "$DATETIME"

printf "Test:
$PROVIDE
    ... " | tee --append "$TESTS_LOG"
local RESULT="$(eval "$PROVIDE" 2>&1 | tee --append "$OPERATIONS_LOG" | tail -n1)"

TESTS_AMOUNT=$((TESTS_AMOUNT + 1))

if test "ALREADY." = "$RESULT";then
ALREADY=$(($ALREADY + 1))
printf "PASS(ALREADY)" | tee --append "$TESTS_LOG"
echo | tee --append "$TESTS_LOG"
PROVIDE_LISP_RES=$CONST_ALREADY
return 0
fi

if test "OK." = "$RESULT";then
    PASS=$(($PASS + 1))
    printf "PASS" | tee --append "$TESTS_LOG";echo | tee --append "$TESTS_LOG";

    if test "$IF_OK" != "";then 
	general_test "$IF_OK";
    fi 	

PROVIDE_LISP_RES=0
return 0;
fi

FAIL=$(($FAIL + 1))
FAILED_TESTS="$FAILED_TESTS
$PROVIDE"
echo FAIL | tee --append "$TESTS_LOG"
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
    local TEST_CODE='echo "(progn (terpri) (princ 100) (terpri) (princ (quote some)))" | LISP=$CUR_LISP ./run-lisp | tail $TAIL_ARG | head -n2'
    printf "Test run-lisp:
${TEST_CODE}\n\n" | tee --append "$TESTS_LOG"
    echo "Evaluated command line: none" | tee --append "$TESTS_LOG"
    printf "Tests into running lisp-system:\n" | tee --append "$TESTS_LOG"
    RESULT="$(eval $TEST_CODE)"    
##################################################
else
    local TEST_PARAMS="--common-load $FILE_FOR_LOAD --common-eval '(progn (princ (quote some)) (terpri))' --common-quit"
    local TEST_CODE="LISP=$CUR_LISP $RUN_SCRIPT $TEST_PARAMS"
    printf "Test run-lisp:
${TEST_CODE}\n\n" | tee --append "$TESTS_LOG"
    echo "Evaluated command line: 
----------------------------------------------
$(eval GET_CMD_P=yes $TEST_CODE)
----------------------------------------------\n" | tee --append "$TESTS_LOG"

    printf "Tests into running lisp-system:\n" | tee --append "$TESTS_LOG"
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
    printf PASS | tee --append "$TESTS_LOG"
else 
    FAIL=$((FAIL + 1))
    echo FAIL | tee --append "$TESTS_LOG"
    return 1
fi
echo | tee --append "$TESTS_LOG"
}

concrete_lisp_test () {
# Using(and changing by general_test): PROVIDE_LISP_RES
local CUR_LISP="$(uppercase $1)"
echo "Testing lisp-system $CUR_LISP:" | tee --append "$TESTS_LOG"
### !!! Function general_test changed PROVIDE_LISP_RES
general_test "LISP=$CUR_LISP ./provide-lisp"
### !!! PROVIDE_LISP_RES - changed

test_run_lisp $CUR_LISP
if test "$PROVIDE_LISP_RES" != "$CONST_ALREADY"
then general_test "LISP=$CUR_LISP ./remove-lisp"
fi

#(reserved for future)general_test ./provide-swank ./remove-swank
}

dirs_into_dir () {
local DIRECTORY="$1"
for d in $(ls -1 "$DIRECTORY")
do
    if test "$(file -b "$DIRECTORY/$d")" = "directory"
    then
	echo "$DIRECTORY/$d"
    fi
done
}


RENAME_PREFIX="rename_for_tests_"

rename_dir_for_tests_if_exists () {
echo "Rename temporary for tests (directory: $1):" | tee --append "$TESTS_LOG"
if test -d "$1"
then 
    local DIRNAME="$(dirname "$1")"
    local FILENAME="$(basename "$1")"
    local NEWNAME="$DIRNAME/${RENAME_PREFIX}$FILENAME"
    echo "Rename command: rm -rf \"$NEWNAME\";mv \"$1\" \"$NEWNAME\"" | tee --append "$TESTS_LOG"
    rm -rf "$NEWNAME";mv "$1" "$DIRNAME/${RENAME_PREFIX}$FILENAME"
fi
}

is_prefix_p () {
local CUR="$1"
if test "${1#$RENAME_PREFIX}" = "$1"
then echo no;else echo yes;fi
}

remove_prefix_if_exists () {
local DIRNAME="$(dirname "$1")"
local FILENAME="$(basename "$1")"
if test "$(is_prefix_p "$FILENAME")" = "yes"
then 
    echo "Rename command: mv \"$1\" \"$DIRNAME/${FILENAME#$RENAME_PREFIX}\"" | tee --append "$TESTS_LOG"
    mv "$1" "$DIRNAME/${FILENAME#$RENAME_PREFIX}"
fi
}

remove_all_prefixes () {
echo "Restore directories into: $1" | tee --append "$TESTS_LOG"
local DIRECTORY="$1"
for d in $(dirs_into_dir "$DIRECTORY")
do
    remove_prefix_if_exists "$d"
done
}
#remove_all_prefixes "/home/linkfly/Downloads/lisp-dev-tools/lisp/sbcl"

D=\$
get_lisp_compiler_dir () {
local CUR_LISP=$(uppercase $1)
echo "$COMPILERS/$(eval echo "$D${CUR_LISP}_LISPS_COMPILERS")/$(eval echo "$D${CUR_LISP}_COMPILER_DIRNAME")"
}

get_lisp_sources_dir () {
local CUR_LISP=$(uppercase $1)
echo "$SOURCES/$(eval echo "$D${CUR_LISP}_LISPS_SOURCES")/$(eval echo "$D${CUR_LISP}_SOURCES_DIRNAME")"
}

get_lisp_dir () {
local CUR_LISP=$(uppercase $1)
echo "$PREFIX/$(eval echo "$D${CUR_LISP}_DIR")"
}

prepare_for_rebuild () {
local CUR_LISP=$(uppercase $1)
local D=\$
echo "Preparing before rebuild lisp-system $CUR_LISP:" | tee --append "$TESTS_LOG"
rename_dir_for_tests_if_exists $(get_lisp_compiler_dir $CUR_LISP)
rename_dir_for_tests_if_exists $(get_lisp_sources_dir $CUR_LISP)
rename_dir_for_tests_if_exists $(get_lisp_dir $CUR_LISP)
}

clean_after_rebuild () {
local CUR_LISP=$1
echo "
Cleaning after rebuilded lisp-system $CUR_LISP:" | tee --append "$TESTS_LOG"
local LISP_COMPILER_DIR="$(get_lisp_compiler_dir $CUR_LISP)"
local LISP_SOURCES_DIR="$(get_lisp_sources_dir $CUR_LISP)"
local LISP_DIR="$(get_lisp_dir $CUR_LISP)"
rm -rf "$LISP_COMPILER_DIR"
rm -rf "$LISP_SOURCES_DIR"
rm -rf "$LISP_DIR"
remove_all_prefixes "$(dirname "$LISP_COMPILER_DIR")"
remove_all_prefixes "$(dirname "$LISP_SOURCES_DIR")"
remove_all_prefixes "$(dirname "$LISP_DIR")"
echo "Cleaning OK." | tee --append "$TESTS_LOG"
}

rebuild_lisp_test () {
# Using(and changing by general_test): PROVIDE_LISP_RES
local CUR_LISP="$(uppercase $1)"
echo "Testing rebuild lisp-system $CUR_LISP:" | tee --append "$TESTS_LOG"

prepare_for_rebuild $CUR_LISP		

### !!! Function general_test changed PROVIDE_LISP_RES
general_test "LISP=$CUR_LISP ./rebuild-lisp"
### !!! PROVIDE_LISP_RES - changed
test_run_lisp $CUR_LISP

clean_after_rebuild $CUR_LISP	
}

is_into_exclude_p () {
local LISP_OR_TOOL="$(uppercase "$1")"
for elt in $EXCLUDE
do
    if test "$elt" = "$LISP_OR_TOOL"
    then
	echo yes
	return
    fi    
done
echo no
}

# Filled exclude logical variables
while test "$1" != ""
do
    case "$1" in
	--exclude-wget)
	    EXCLUDE_WGET=yes
	    ;;
	--exclude-emacs)
	    EXCLUDE_EMACS=yes
	    ;;
	--exclude-modern-lisps)
	    EXCLUDE_MODERN_LISPS=yes
	    ;;
	--exclude-young-lisps)
	    EXCLUDE_YOUNG_LISPS=yes
	    ;;
	--exclude-obsolete-lisps)
	    EXCLUDE_OBSOLETE_LISPS=yes
	    ;;
	--exclude-rebuild)
	    EXCLUDE_REBUILD=yes
	    ;;
	--exclude*)
	    EXCLUDE="$(uppercase "${1#--exclude=}")"
	    ;;
    esac
    shift
done

# Testing base tools
echo | tee --append "$TESTS_LOG"
echo "Testing base tools:" | tee --append "$TESTS_LOG"
if test -z "$EXCLUDE_WGET" && test "$(is_into_exclude_p WGET)" = "no"
then
    general_test "./sh/provide-tool.sh wget" "./sh/remove-tool.sh wget"
fi

# Testing SBCL lisp
if test -z "$EXCLUDE_MODERN_LISPS"
then
    if test "$(is_into_exclude_p SBCL)" = "no"
    then
	echo | tee --append "$TESTS_LOG"
	concrete_lisp_test SBCL
    fi
fi

if test -z "$EXCLUDE_EMACS"
then
# Testing Emacs and Slime 
    echo | tee --append "$TESTS_LOG"
    echo "Testing Emacs and Slime:" | tee --append "$TESTS_LOG"

    if test "$(is_into_exclude_p SLIME)" = "no"
    then
	general_test ./provide-emacs
    else
	echo "EMACS into excludes - SKIP" | tee --append "$TESTS_LOG"
    fi

    if test "$(is_into_exclude_p SLIME)" = "no"
    then
	general_test ./provide-slime ./remove-slime
    else
	echo "SLIME into excludes - SKIP" | tee --append "$TESTS_LOG"
    fi
fi

# Testing modern lisps (exclude SBCL)
if test -z "$EXCLUDE_MODERN_LISPS"
then
    echo | tee --append "$TESTS_LOG"
    echo "Testing modern lisps:" | tee --append "$TESTS_LOG"
    for lisp in $(./get-all-lisps --exclude="SBCL")
    do
	if test "$(is_into_exclude_p $lisp)" = "no"
	then
	    concrete_lisp_test $lisp
	fi
    done
fi

#Testing ./rebuild-lisp
if test -z "$EXCLUDE_REBUILD"
then
    echo | tee --append "$TESTS_LOG"
    echo "Testing rebuild lisps (for: $REBUILD_FOR_LISPS):" | tee --append "$TESTS_LOG"
    for lisp in "$REBUILD_FOR_LISPS"
    do
	if test "$(is_into_exclude_p $lisp)" = "no" && test "$(is_into_exclude_p REBUILD)" = "no"
	then
	    rebuild_lisp_test $lisp
	fi
    done

fi

# Testing young lisps (exclude SBCL)
if test -z "$EXCLUDE_YOUNG_LISPS"
then
    echo | tee --append "$TESTS_LOG"
    echo "Testing young lisps:" | tee --append "$TESTS_LOG"
    for lisp in $(./get-all-lisps --exclude-modern --include-young)
    do
	if test "$(is_into_exclude_p $lisp)" = "no"
	then
	    concrete_lisp_test $lisp
	fi
    done
fi

# Testing obsolete lisps (exclude SBCL)
if test -z "$EXCLUDE_OBSOLETE_LISPS"
then
    echo | tee --append "$TESTS_LOG"
    echo "Testing obsolete lisps:" | tee --append "$TESTS_LOG"
    for lisp in $(./get-all-lisps --exclude-modern --include-obsolete)
    do
	if test "$(is_into_exclude_p $lisp)" = "no"
	then
	    concrete_lisp_test $lisp
	fi
    done
fi

RESULT_MESSAGE="------------------------------------------------------------------------------

tests amount = $TESTS_AMOUNT
tests passed = $PASS
tests already = $ALREADY
tests failed = $FAIL

------------------------------------------------------------------------------
"

if test "$(($PASS + $ALREADY))" = "$TESTS_AMOUNT"
then RESULT_MESSAGE="$RESULT_MESSAGE
All tests passed.

OK."
else RESULT_MESSAGE="$RESULT_MESSAGE
Not all tests passed.
Failed tests:
$FAILED_TESTS

FAILED."
exit 1
fi

