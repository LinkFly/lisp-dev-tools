#!/bin/sh
CURPATH="$(pwd)"
cd "$(dirname "$0")"
. ./includes.sh
cd "$CURPATH"

### Note: script sh/includes.sh must be included
# for setted variables: SCRIPTS_DIR
# for defined functions: is_symlink_p
################

FILE="$1"

if test "$(is_symlink_p $FILE)" = "yes";then
    $("$SCRIPTS_DIR/$(basename "$0")" "$("$SCRIPTS_DIR/realpath" "$FILE")")
else
    TYPE=$(file --brief --mime-type "$FILE")
    case "$TYPE" in
	"application/x-gzip") 
	    tar -xzvf "$FILE";
	    ;;
	"application/x-bzip2")
	    tar -xjvf "$FILE";
	    ;;
	"application/x-xz")
	    xz -dvc "$FILE" | tar -x
	    ;;
    esac
fi