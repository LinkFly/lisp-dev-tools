#!/bin/sh
cd "$(dirname "$0")"

######## Main variables ########
TESTS_DIR="$(pwd)"
cd ../sh
NO_COPY_LINKS_P=yes ### variableused by copy-links.sh
. ./includes.sh
cd "$TESTS_DIR"

######## Configurable variables ########
TESTS_RESULTS=${TESTS_RESULTS:-"$(pwd)/tests-results"}
SHOW_DIRS_P=${SHOW_DIRS_P:-yes}
SHOW_DIRS_SIZES_P=${SHOW_DIRS_SIZES_P:-yes}
SHOW_DIRS_EXACT_SIZES_P=${SHOW_DIRS_EXACT_SIZES_P:-yes}

############# Pathnames variables #############
FILE_FOR_LOAD="$(pwd)/for-tests.lisp"
TESTS_LOG="$TESTS_RESULTS/tests-log.txt"
OPERATIONS_LOG="$TESTS_RESULTS/operations-log.txt"

######## Inner variables #########
TESTS_COMPLETE_P=no
RESULT_MESSAGE="Tests aborted.

FAILED."

BEFORE_SIZE=

OLD_ARCHIVE_FILES=
OLD_LISP_DIRS=
OLD_LISP_COMPILERS_DIRS=
OLD_LISP_SOURCES_DIRS=
OLD_TOOLS_DIRS=

OLD_EMACS_LIBS_FILES=
OLD_EMACS_LIBS_DIRS=
OLD_LISP_LIBS_FILES=
OLD_LISP_LIBS_DIRS=

OLD_FILES=
OLD_DIRS=
FILES=
DIRS=

######################################

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

RENAME_PREFIX="rename_for_tests_"
TMP_SYMLINKS_DIR="$UTILS/tmp-for-tests-cur-symlinks"
EMACS_NOT_ALREADY_P=
######################################

############# Includes #################
. ./get-new-files.sh
. ./functions-for-tests.sh
cd ..




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

##### Restore symlinks #####
restore_symlinks

######################## Restoring state ############################
printlog "
Restoring state ...
-----------------------------------------------"
remove_new_dirs "$OLD_ARCHIVE_FILES" "$(get_archive_files)"
remove_new_dirs "$OLD_LISP_DIRS" "$(get_lisp_dirs)"
remove_new_dirs "$OLD_LISP_COMPILERS_DIRS" "$(get_lisp_compilers_dirs)"
remove_new_dirs "$OLD_LISP_SOURCES_DIRS" "$(get_lisp_sources_dirs)"
remove_new_dirs "$OLD_TOOLS_DIRS" "$(get_tools_dirs)"

remove_new_dirs "$OLD_EMACS_LIBS_FILES" "$(get_emacs_libs_files)"
remove_new_dirs "$OLD_EMACS_LIBS_DIRS" "$(get_emacs_libs_dirs)"
remove_new_dirs "$OLD_LISP_LIBS_FILES" "$(get_lisp_libs_files)"
remove_new_dirs "$OLD_LISP_LIBS_DIRS" "$(get_lisp_libs_dirs)"
printlog "-----------------------------------------------
... end restoring state."

#################### Show changed dirs after restore #####################
show_changed_dirs "Changed directories after restore state"

########################## Checking size #################################
if test "$TESTS_COMPLETE_P" = "yes"
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
exit
}
trap "cleanup" EXIT INT
#################################################################################
############################# END DEFINING CLEANUP ##############################



###################### Initialization #########################
remove_tests_results
printlog "Tests running ..."

BEFORE_SIZE=$(get_all_size)

OLD_ARCHIVE_FILES="$(get_archive_files)"
OLD_LISP_DIRS="$(get_lisp_dirs)"
OLD_LISP_COMPILERS_DIRS="$(get_lisp_compilers_dirs)"
OLD_LISP_SOURCES_DIRS="$(get_lisp_sources_dirs)"
OLD_TOOLS_DIRS="$(get_tools_dirs)"

OLD_EMACS_LIBS_FILES="$(get_emacs_libs_files)"
OLD_EMACS_LIBS_DIRS="$(get_emacs_libs_dirs)"
OLD_LISP_LIBS_FILES="$(get_lisp_libs_files)"
OLD_LISP_LIBS_DIRS="$(get_lisp_libs_dirs)"

OLD_DIRS="$(get_all_dirs "$PREFIX" 3)"

########### Show total size ##########
printlog "
------- Total size -------
$BEFORE_SIZE
--------------------------"

####### Show all directories #########
if test "$SHOW_DIRS_P" = "yes"
then 
    printlog "
--------------------------
Directories before tests (depth = 3):
----------------
$OLD_DIRS
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
    printlog "
Testing Emacs and Slime:"

    if test "$(is_into_exclude_p EMACS)" = "no"
    then
	general_test ./provide-emacs
	if test "$PROVIDE_LISP_RES" != "$CONST_ALREADY"
	then
	    EMACS_NOT_ALREADY_P=yes
	fi
    else
	printlog "EMACS into excludes - SKIP"
    fi

    if test "$(is_into_exclude_p SLIME)" = "no"
    then
	general_test ./provide-slime ./remove-slime
    else
	printlog "SLIME into excludes - SKIP"
    fi

    if test "$(is_into_exclude_p EMACS)" = "no" && "$EMACS_NOT_ALREADY_P" = "yes"
    then
	general_test ./remove-emacs
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
	    concrete_lisp_test $lisp
	fi
    done
fi

#Testing ./rebuild-lisp
if test -z "$EXCLUDE_REBUILD"
then
    printlog "
Testing rebuild lisps (for: $REBUILD_FOR_LISPS):"
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
    printlog "
Testing young lisps:"
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
    printlog "
Testing obsolete lisps:"
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
TESTS_COMPLETE_P=yes
else RESULT_MESSAGE="$RESULT_MESSAGE
Not all tests passed.
Failed tests:
$FAILED_TESTS

FAILED."
TESTS_COMPLETE_P=yes
exit 1
fi

