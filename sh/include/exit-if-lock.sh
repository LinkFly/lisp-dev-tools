#!/bin/sh

TESTS_LOCK_FILE="$PREFIX/run-tests.lock"

if test -f "$TESTS_LOCK_FILE" && test "$FORCE_UNLOCKED_P" != "yes"
then
    echo "ERROR: run tests (and any actions) locked - tests already running ...
Hint: if you sure what tests not running then (for unlocking) to run ./run-tests.sh --zap

FAILED."
    exit 1
fi