#!/bin/sh
cd "$(dirname "$0")"

######## Main variables ########
TESTS_DIR="$(pwd)"
TMP_WORK_FILES_DIR="$TESTS_DIR/tmp-tests-work-files"

cd ../sh
NO_COPY_LINKS_P=yes ### variableused by copy-links.sh
FORCE_UNLOCKED_P=no
for arg in $@
do
    if test "$arg" = "--zap"
    then 
	FORCE_UNLOCKED_P=yes
    fi
done
. ./includes.sh

cd "$TESTS_DIR"

######## Configurable variables ########
TESTS_RESULTS=${TESTS_RESULTS:-"$TESTS_DIR/tests-results"}
SHOW_DIRS_P=${SHOW_DIRS_P:-yes}
SHOW_DIRS_SIZES_P=${SHOW_DIRS_SIZES_P:-yes}
SHOW_DIRS_EXACT_SIZES_P=${SHOW_DIRS_EXACT_SIZES_P:-yes}

############# Pathnames variables #############
FILE_FOR_LOAD="$TESTS_DIR/for-tests.lisp"
TESTS_LOG="$TESTS_RESULTS/tests-log.txt"
OPERATIONS_LOG="$TESTS_RESULTS/operations-log.txt"

######## Inner variables #########
TESTS_COMPLETE_P=no
RESULT_MESSAGE="Tests aborted.

FAILED."

BEFORE_SIZE=

############ Defining vars with files contained old files and dirs. Remove these files #########
OLD_ARCHIVE_FILES="$TMP_WORK_FILES_DIR/old_archive_files"
OLD_LISP_DIRS="$TMP_WORK_FILES_DIR/old_lisp_dirs"
OLD_LISP_COMPILERS_DIRS="$TMP_WORK_FILES_DIR/old_lisp_compilers_dirs"
OLD_LISP_SOURCES_DIRS="$TMP_WORK_FILES_DIR/old_lisp_sources_dirs"
OLD_TOOLS_DIRS="$TMP_WORK_FILES_DIR/old_tools_dirs"

OLD_EMACS_LIBS_FILES="$TMP_WORK_FILES_DIR/old_emacs_libs_files"
OLD_EMACS_LIBS_DIRS="$TMP_WORK_FILES_DIR/old_emacs_libs_dirs"
OLD_LISP_LIBS_FILES="$TMP_WORK_FILES_DIR/old_lisp_libs_files"
OLD_LISP_LIBS_DIRS="$TMP_WORK_FILES_DIR/old_lisp_libs_dirs"

OLD_DIRS="$TMP_WORK_FILES_DIR/old_dirs"
##########################################################################3

TESTS_AMOUNT=0
PASS=0
ALREADY=0
FAIL=0

CONST_ALREADY=10

REBUILD_FOR_LISPS="SBCL"

ONLY=
EXCLUDE=
EXCLUDE_WGET=
EXCLUDE_EMACS=
EXCLUDE_MODERN_LISPS=
EXCLUDE_YOUNG_LISPS=
EXCLUDE_OBSOLETE_LISPS=
EXCLUDE_REBUILD=

FAILED_TESTS=
PROVIDE_LISP_RES=

RESERV_COPY_PREFIX="reserv-for-restore-after-tests_"
TMP_SYMLINKS_DIR="$TESTS/tmp-tests-work-files/tmp-for-tests-cur-symlinks"
EMACS_NOT_ALREADY_P=
######################################

############# Includes #################
. ./get-new-files.sh
. ./functions-for-tests.sh
cd ..

#################### #####################
if test "$FORCE_UNLOCKED_P" = "yes"
then
    if test -f "$TESTS_LOCK_FILE"
    then
	full_restore_state
	printf "Removed "$TESTS_LOCK_FILE" ... "
	rm "$TESTS_LOCK_FILE"
	echo "OK."
	echo "Unlocked - success."
    else
	echo "Not locked."
    fi
    exit 0
fi
##########################################

####### Experiments (need delete) #####
# CMPDIRS="/home/linkfly/tmp/exp"
# echo "$(get_lisp_compilers_dirs)" > "$CMPDIRS"
# echo "$(cat "$CMPDIRS")"
# 
# mkdir --parents "$COMPILERS/$LISP_COMPILERS/newnext1"
# mkdir --parents "$COMPILERS/$LISP_COMPILERS/newnext2"
# 
# echo now
# echo "$(get_lisp_compilers_dirs)"
# 
# echo changed
# echo "$(get_new_files "$(cat "$CMPDIRS")" "$(get_lisp_compilers_dirs)")"
# 
# echo "remove..."
# remove_new_dirs "$(cat "$CMPDIRS")" "$(get_lisp_compilers_dirs)"
# 
# echo after-remove
# echo "$(get_lisp_compilers_dirs)"
# 
# rm "$TESTS_LOCK_FILE"
# exit 1
#########################

############################## DEFINING CLEANUP #################################
#################################################################################
ALREADY_CLEANUP_P=
cleanup () {
### Singleton ###
if test "$ALREADY_CLEANUP_P" = "yes";then exit;fi
#################

if test "$TESTS_COMPLETE_P" != "yes"
then
    printlog "|Aborted..."
fi

######## Show dirs after tests ##########
if test "$SHOW_DIRS_P" = "yes"
then 
    printlog "
--------------------------
Directories after tests (depth = 3):
----------------
$(get_all_dirs "$PREFIX" 3)
--------------------------
"
fi

#################### Show changed dirs before restore #####################
show_changed_dirs "Changed directories before restore state"

######################## Restoring state ############################
full_restore_state

#################### Show changed dirs after restore #####################
show_changed_dirs "Changed directories after restore state"

########################## Checking size #################################
if test -n "$BEFORE_SIZE"
then
    printlog "$(show_dirs_sizes after)"
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

######### Construct and output RESULT_MESSAGE here ##########
    RESULT_MESSAGE="$BEFORE_RESULT_MESSAGE
------------------------------------------------------------------------------

$RESULT_MESSAGE"
fi
########################## End checking size #############################

printlog "$RESULT_MESSAGE"
ALREADY_CLEANUP_P=yes

######### For unlock ##########
rm "$TESTS_LOCK_FILE"

######### Delete not required files ########
rm -rf "$TMP_WORK_FILES_DIR/*"

exit
}
trap "cleanup" EXIT INT
#################################################################################
############################# END DEFINING CLEANUP ##############################



###################### Initialization #########################
remove_tests_results
rm -rf "$TMP_WORK_FILES_DIR/*"

########### For locking any actions while tests running ############
touch "$TESTS_LOCK_FILE"
export FORCE_UNLOCKED_P=yes

printlog "Tests running ..."

BEFORE_SIZE=$(get_all_size)

####################### Create new files contained info about older files and dirs ###############
echo "$(get_archive_files)" > "$OLD_ARCHIVE_FILES"
echo "$(get_lisp_dirs)" > "$OLD_LISP_DIRS" 
echo "$(get_lisp_compilers_dirs)" > "$OLD_LISP_COMPILERS_DIRS" 
echo "$(get_lisp_sources_dirs)" > "$OLD_LISP_SOURCES_DIRS" 
echo "$(get_tools_dirs)" > "$OLD_TOOLS_DIRS" 

echo "$(get_emacs_libs_files)" > "$OLD_EMACS_LIBS_FILES" 
echo "$(get_emacs_libs_dirs)" > "$OLD_EMACS_LIBS_DIRS" 
echo "$(get_lisp_libs_files)" > "$OLD_LISP_LIBS_FILES" 
echo "$(get_lisp_libs_dirs)" > "$OLD_LISP_LIBS_DIRS" 

echo "$(get_all_dirs "$PREFIX" 3)" > "$OLD_DIRS"
#################################################################################################

########### Show total size ##########
printlog "
----------------------------------- Total size -----------------------------------
(Exclude dirs: "$TESTS_RESULTS" and "$TMP_WORK_FILES_DIR")
-----------------------
$BEFORE_SIZE
----------------------------------------------------------------------------------"

####### Show all directories #########
if test "$SHOW_DIRS_P" = "yes"
then 
    printlog "
--------------------------
Directories before tests (depth = 3):
----------------
$(cat "$OLD_DIRS")
--------------------------
"
fi

###### Show directories sizes #######
printlog "$(show_dirs_sizes before)"


########################################## Starting tests ############################################

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
	    EXCLUDE="$(echo "${1#--exclude=}" | tr 'a-z' 'A-Z')"
	    ;;
	--only*)
	    ONLY="$(echo "${1#--only=}" | tr 'a-z' 'A-Z')"
	    ;;
    esac
    shift
done

###### Saving symlinks ######
save_symlinks

# Testing base tools
printlog "
Testing base tools:"
if test -z "$EXCLUDE_WGET" && test "$(is_into_exclude_p WGET)" = "no"
then
    if test "$(is_into_only_p WGET)" = "yes"
    then
	general_test "./sh/provide-tool.sh wget" "./sh/remove-tool.sh wget"
    fi
fi

# Testing SBCL lisp
if test -z "$EXCLUDE_MODERN_LISPS"
then
    if test "$(is_into_exclude_p SBCL)" = "no"
    then
	if test "$(is_into_only_p SBCL)" = "yes"
	then
	    echo | tee --append "$TESTS_LOG"
	    concrete_lisp_test SBCL
	fi
    fi
fi

if test -z "$EXCLUDE_EMACS"
then
# Testing Emacs and Slime 
    printlog "
Testing Emacs and Slime:"

    if test "$(is_into_exclude_p EMACS)" = "no"
    then
	if test "$(is_into_only_p EMACS)" = "yes"
	then
	    general_test ./provide-emacs
	    if test "$PROVIDE_LISP_RES" != "$CONST_ALREADY"
	    then
		EMACS_NOT_ALREADY_P=yes
	    fi
	else
	    printlog "EMACS not into ONLY (only mode on)"
	fi
    else
	printlog "EMACS into excludes - SKIP"
    fi

    if test "$(is_into_exclude_p SLIME)" = "no"
    then
	if test "$(is_into_only_p SLIME)" = "yes"
	then
	    general_test ./provide-slime ./remove-slime
	else
	    printlog "SLIME not into ONLY (only mode on)"
	fi
    else
	printlog "SLIME into excludes - SKIP"
    fi

    if test "$(is_into_exclude_p EMACS)" = "no" && test "$EMACS_NOT_ALREADY_P" = "yes"
    then
	if test "$(is_into_only_p EMACS)" = "yes"
	then
	    general_test ./remove-emacs
	fi
    fi
fi

# Testing modern lisps (exclude SBCL)
if test -z "$EXCLUDE_MODERN_LISPS"
then
    printlog "
Testing modern lisps:"
    for lisp in $(./get-all-lisps --exclude="SBCL")
    do
	if test "$(is_into_exclude_p $lisp)" = "no"
	then
	    if test "$(is_into_only_p $(uppercase $lisp))" = "yes"
	    then
		concrete_lisp_test $lisp
	    fi
	fi
    done
fi

#Testing ./rebuild-lisp
if test -z "$EXCLUDE_REBUILD" && test "$(is_into_exclude_p REBUILD)" = "yes"
then
    printlog "
Testing rebuild lisps (for: $REBUILD_FOR_LISPS):"
    for lisp in "$REBUILD_FOR_LISPS"
    do
	if test "$(is_into_exclude_p $lisp)" = "no" && test "$(is_into_exclude_p REBUILD)" = "no"
	then
	    if test "$(is_into_only_p $(uppercase $lisp))" = "yes"
	    then
		rebuild_lisp_test $lisp
	    fi
	fi
    done

fi

# Testing young lisps (exclude SBCL)
if test -z "$EXCLUDE_YOUNG_LISPS"
then
    printlog "
Testing young lisps:"
    for lisp in $(./get-all-lisps --exclude-modern --include-young)
    do
	if test "$(is_into_exclude_p $lisp)" = "no"
	then
	    if test "$(is_into_only_p $(uppercase $lisp))" = "yes"
	    then
		concrete_lisp_test $lisp
	    fi
	fi
    done
fi

# Testing obsolete lisps (exclude SBCL)
if test -z "$EXCLUDE_OBSOLETE_LISPS"
then
    printlog "
Testing obsolete lisps:"
    for lisp in $(./get-all-lisps --exclude-modern --include-obsolete)
    do
	if test "$(is_into_exclude_p $lisp)" = "no"
	then
	    if test "$(is_into_only_p $(uppercase $lisp))" = "yes"
	    then
		concrete_lisp_test $lisp
	    fi
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
TESTS_COMPLETE_P=yes
else RESULT_MESSAGE="$RESULT_MESSAGE
Not all tests passed.
Failed tests:
$FAILED_TESTS

FAILED."
TESTS_COMPLETE_P=yes
exit 1
fi

