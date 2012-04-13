#!/bin/sh
cd "$(dirname "$0")"
cd ../sh
. ./includes.sh
cd ..

FILE_FOR_LOAD="$(pwd)/tests/for-tests.lisp"

usage () {
echo "Using: 
run-tests [ --exclude-wget | --exclude-emacs | --exclude-modern-lisps | --exclude-young-lisps | --exclude-obsolete-lisps ]*
Example:
run-tests --exclude-emacs --exclude-obsolete-lisps"
exit 0
}

TESTS_AMOUNT=0
PASS=0
ALREADY=0
FAIL=0

CONST_ALREADY=10

EXCLUDE_WGET=
EXCLUDE_EMACS=
EXCLUDE_MODERN_LISPS=
EXCLUDE_YOUNG_LISPS=
EXCLUDE_OBSOLETE_LISPS=

PROVIDE_LISP_RES=

general_test () {
# Using(and changing): PROVIDE_LISP_RES
local PROVIDE="$1"
local IF_OK="$2"
printf "test $PROVIDE ... "
local RESULT="$(eval "$PROVIDE" 2>/dev/null | tail -n1)"
TESTS_AMOUNT=$((TESTS_AMOUNT + 1))

if test "ALREADY." = "$RESULT";then
ALREADY=$(($ALREADY + 1))
printf "PASS(ALREADY)"
echo
PROVIDE_LISP_RES=$CONST_ALREADY
return 0
fi

if test "OK." = "$RESULT";then
    PASS=$(($PASS + 1))
    printf "PASS";echo;

    if test "$IF_OK" != "";then 
	general_test "$IF_OK";
    fi 	

PROVIDE_LISP_RES=0
return 0;
fi

FAIL=$(($FAIL + 1))
echo FAIL
PROVIDE_LISP_RES=1
return 1
}

# Test running lisp-system:
test_run_lisp () {
local CUR_LISP=$1
if test -z "$CUR_LISP";then CUR_LISP=sbcl;fi
local RUN_SCRIPT="./run-lisp"
local TEST_PARAMS="--common-load $FILE_FOR_LOAD --common-eval '(progn (princ (quote some)) (terpri))' --common-quit"
local TEST_CODE="LISP=$CUR_LISP $RUN_SCRIPT $TEST_PARAMS"
printf "Test run-lisp:
${TEST_CODE}\n\n"
echo "Evaluated command line: 
----------------------------------------------
$(eval GET_CMD_P=yes $TEST_CODE)
----------------------------------------------\n"

printf "Tests into running lisp-system:\n"
local RESULT="$(eval $TEST_CODE | tail -n2)"

TESTS_AMOUNT=$((TESTS_AMOUNT + 1))

if test "$RESULT" = "100
SOME"
then
    PASS=$((PASS + 1))
    printf PASS
else 
    FAIL=$((FAIL + 1))
    echo FAIL
    return 1
fi
echo
}

concrete_lisp_test () {
# Using(and changing by general_test): PROVIDE_LISP_RES
echo "Testing lisp-system $1:"
### !!! Function general_test changed PROVIDE_LISP_RES
general_test "LISP=$1 ./provide-lisp"
### !!! PROVIDE_LISP_RES - changed

test_run_lisp $1
if test "$PROVIDE_LISP_RES" != "$CONST_ALREADY"
then general_test "LISP=$1 ./remove-lisp"
fi

general_test "LISP=$1 ./sh/provide-quicklisp.sh" "LISP=$1 ./remove-quicklisp.sh"
#(reserved for future)general_test ./provide-swank ./remove-swank
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
    esac
done

# Testing base tools
echo
echo "Testing base tools:"
if test -z "$EXCLUDE_WGET"
then
    general_test "./sh/provide-tool.sh wget" "./sh/remove-tool wget"
fi

# Testing SBCL lisp
if test -z "$EXCLUDE_MODERN_LISPS"
then
echo
concrete_lisp_test SBCL
fi

if test -z "$EXCLUDE_EMACS"
then
# Testing Emacs and Slime 
echo
echo "Testing Emacs and Slime:"
general_test ./provide-emacs
general_test ./provide-slime ./remove-slime
fi

# Testing modern lisps (exclude SBCL)
if test -z "$EXCLUDE_MODERN_LISPS"
then
    echo
    echo "Testing modern lisps:"
    for lisp in $(./get-all-lisps --exclude="SBCL")
    do
	concrete_lisp_test $lisp
    done
fi

# Testing young lisps (exclude SBCL)
if test -z "$EXCLUDE_YOUNG_LISPS"
then
    echo
    echo "Testing young lisps:"
    for lisp in $(./get-all-lisps --exclude-modern --include-young)
    do
	concrete_lisp_test $lisp
    done
fi

# Testing obsolete lisps (exclude SBCL)
if test -z "$EXCLUDE_OBSOLETE_LISPS"
then
    echo
    echo "Testing obsolete lisps:"
    for lisp in $(./get-all-lisps --exclude-modern --include-obsolete)
    do
	concrete_lisp_test $lisp
    done
fi

echo "
tests amount = $TESTS_AMOUNT
tests passed = $PASS
tests already = $ALREADY
tests failed = $FAIL"

if test "$(($PASS + $ALREADY))" = "$TESTS_AMOUNT"
then echo "All tests passed.

OK."
else echo "Not all tests passed.

FAILED."
exit 1
fi

