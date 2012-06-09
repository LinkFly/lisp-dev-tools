#!/bin/sh
cd "$(dirname "$0")"
. ./includes.sh

rm_param () {
    local PARAM="$1"
    remove_param "$PARAM" "$LDT_CUSTOM_CONF_DIR/custom-lisp-and-version.conf"
}

usage () { echo "$USAGE"; exit 0; }

if test "$1" = "";then usage;fi

case "$1" in 
    --help) usage	
	;;
    --all) rm -f "$LDT_CUSTOM_CONF_DIR/custom-lisp-and-version.conf"
	. "$LDT_CUSTOM_CONF_DIR/lisp-and-version.conf"
	if test -f "$LDT_CUSTOM_CONF_DIR/custom-lisp-and-version.conf"
	then 
	    echo "ERROR: bad reset to default parameters (not deleted "$LDT_CUSTOM_CONF_DIR/custom-lisp-and-version.conf")"
	    exit 1
	fi
	echo "Current lisp: $(./get-lisp.sh)
Current version: $(./get-version.sh)"
	;;
    --lisp) 
	rm_param "CUR_LISP"
	. "$LDT_CUSTOM_CONF_DIR/lisp-and-version.conf"
	. "$LDT_CUSTOM_CONF_DIR/custom-lisp-and-version.conf"
	echo "Current lisp: $(./get-lisp.sh)"	
	;;
    --lisp-version) 
	rm_param "$(uppercase $CUR_LISP)_VERSION"
	. "$LDT_CUSTOM_CONF_DIR/lisp-and-version.conf"
	. "$LDT_CUSTOM_CONF_DIR/custom-lisp-and-version.conf"
	echo "Current version: $(./get-version.sh)"
	;;
    --all-versions) LISPS_VERSIONS_PARAMS="
SBCL_VERSION
CMUCL_VERSION
XCL_VERSION
ECL_VERSION
CLISP_VERSION
MKCL_VERSION
ABCL_VERSION
WCL_VERSION
GCL_VERSION
CCL_VERSION"
	for param in $LISPS_VERSIONS_PARAMS
	do
	    remove_param $param "$LDT_CUSTOM_CONF_DIR/custom-lisp-and-version.conf"
	done
	. "$LDT_CUSTOM_CONF_DIR/lisp-and-version.conf"
	. "$LDT_CUSTOM_CONF_DIR/custom-lisp-and-version.conf"
	echo "Current lisp: $(./get-lisp.sh)
Current version: $(./get-version.sh)"
	;;
    *) echo "ERROR: bad parameter $1 (for show help to run with --help parameter)" ;exit 1
	;;
esac