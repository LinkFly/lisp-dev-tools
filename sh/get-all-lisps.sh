#!/bin/sh

if test -z "$RUNNED_SCRIPT"
then
    RUNNED_SCRIPT="get-all-lisps.sh"
fi

usage () {
echo "Using: 
$RUNNED_SCRIPT [ --exclude-modern | --include-young | --include-obsolete | --include-all | --exclude=\"LISP1 LISP2 ...\" ]*
Example:
$RUNNED_SCRIPT --include-young --exclude=\"SBCL CLISP\""
}

MODERN_LISPS="SBCL
CCL
ECL
ABCL
CLISP"
FOR_MODERN_LISPS="$MODERN_LISPS"

YOUNG_LISPS=
FOR_YOUNG_LISPS="XCL
MKCL"

OBSOLETE_LISPS=
FOR_OBSOLETE_LISPS="CMUCL
GCL
WCL"

EXCLUDE_LISPS=

while test "$1" != ""
do
    case "$1" in 
	-h)
	    usage
	    ;;
	--help)
	    usage
	    ;;
	--exclude-modern)
	    MODERN_LISPS=
	    ;;
	--include-all)
	    MODERN_LISPS="$FOR_MODERN_LISPS"
	    YOUNG_LISPS="$FOR_YOUNG_LISPS"
	    OBSOLETE_LISPS="$FOR_OBSOLETE_LISPS"
	    ;;
	--include-young)
	    YOUNG_LISPS="$FOR_YOUNG_LISPS"
	    ;;
	--include-obsolete)
	    OBSOLETE_LISPS="$FOR_OBSOLETE_LISPS"
	    echo "obsolete: $OBSOLETE_LISPS"
	    ;;
	*)
	    arg="$1"
	    param=${arg%=*}
	    value=${arg#*=}    
	    if test "$value" != "" && \
		test "$value" != "--exclude" && \
		test "$param" = "--exclude"
	    then
		EXCLUDE_LISPS="$value"
	    fi
	    ;;
    esac
shift
done

output_lisps () {
EXCLUDE_P=
for lisp in $1
do
    EXCLUDE_P=no
    for exc_lisp in $EXCLUDE_LISPS
    do
	if test "$lisp" = "$exc_lisp"
	then 	    
	    EXCLUDE_P=yes
	    break
	fi
    done

    if test "$EXCLUDE_P" != "yes"
    then
	echo $lisp
    fi
done
}

output_lisps "$MODERN_LISPS"
output_lisps "$YOUNG_LISPS"
output_lisps "$OBSOLETE_LISPS"
