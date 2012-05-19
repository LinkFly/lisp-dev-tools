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
    printlog "
Restoring symbolic links ..."
    remove_all_symlinks "$UTILS"
    for link in $(get_all_symlinks "$TMP_SYMLINKS_DIR")
    do
	mv "$link" "$UTILS/$(basename "$link")"
    done
    rm -rf "$TMP_SYMLINKS_DIR"
    printlog "... ok"
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
    echo "$(du "$1" --max-depth=3 --exclude="$TESTS_RESULTS" --exclude="$1/.git" $EXTRA_ARGS)"
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
    tmp=$(du "$PREFIX" --max-depth=0 --bytes --exclude="$TESTS_RESULTS")
    echo ${tmp%%"$PREFIX"}
}

remove_new_dirs () {
for dir in $(get_new_files "$1" "$2")
do
    printlog "Now running command: rm -rf "$dir"" | tee --append "$TESTS_LOG"
    rm -rf "$dir"
done
}

####### Show changed dirs before restore ######
show_changed_dirs () {
    local TITLE="$1"
    printlog "
------- $TITLE ----------
$(describe_changed_dirs "$OLD_DIRS" "$(get_all_dirs "$PREFIX" 3)")
-----------------------------------------------------------"
}

##################### Tests functions #########################
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

printlog "Test:
$PROVIDE
    ... "
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
    printlog "Evaluated command line: 
----------------------------------------------
$(eval GET_CMD_P=yes $TEST_CODE)
----------------------------------------------\n"

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
    printlog FAIL
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
###################### End test functions #########################


################### Functions for rebuild test #################
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
for d in $(get_all_dirs "$DIRECTORY" 1)
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
################## End functions for rebuild test #################


#################################################################################
################################# END FUNCTIONS #################################