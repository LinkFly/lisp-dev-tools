#!/bin/sh
CURPATH="$(pwd)"
cd "$(dirname "$0")"
. ./includes.sh
# TODO get decision - logging or not calling extract.sh script
# log_scr_run "extract.sh $1" "Extracting from archive"

cd "$CURPATH"

### Note: script sh/includes.sh must be included
# for setted variables: SCRIPTS_DIR
# for defined functions: is_symlink_p
################

# TODO Share log function and testing their correct working
log_extract_cmd () {
    echo "
[extract.sh] CMD: "$1""
}

log_extract_vars () {
    echo "
[extract.sh] VARS: "$1""
}

FILE="$1"
if test "$(is_symlink_p $FILE)" = "yes";then    
    #    "$SCRIPTS_DIR/$(basename "$0")" "$("$SCRIPTS_DIR/realpath" "$FILE")"
    log_extract_cmd ""$SCRIPTS_DIR/$(basename "$0")" "$(readlink -f "$FILE")""
    "$SCRIPTS_DIR/$(basename "$0")" "$(readlink -f "$FILE")"
else
    TYPE=$(file --brief --mime-type "$FILE")
    log_extract_vars "TYPE=$TYPE"
    case "$TYPE" in
	"application/x-gzip") 
	    tar -xzvf "$FILE";
	    ;;
	"application/gzip") 
	    tar -xzvf "$FILE";
	    ;;
	"application/x-bzip2")
	    tar -xjvf "$FILE";
	    ;;
	"application/x-xz")
	    xz -dvc "$FILE" | tar -x
	    ;;
	*)
	    tar -xvf "$FILE";
    esac
fi

