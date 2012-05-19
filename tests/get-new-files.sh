#!/bin/sh

get_all_files () {
find "$1" -mindepth 1 -maxdepth ${2:-1} -type f -o -type l ! -name .gitignore
}

get_all_symlinks () {
find "$1" -maxdepth 1 -type l
}

remove_all_symlinks () {
find "$1" -maxdepth 1 -type l -exec rm {} \;
}


get_all_dirs () {
find "$1" -mindepth 1 -maxdepth ${2:-1} ! -name ".git" -type d ! -path "$1/.git/*" 
}

get_new_files () {
local NEW_FILES=
local IS_FILE_P=

for f2 in $2
do
    IS_FILE_P=no
    for f1 in $1
    do

	if test "$f2" = "$f1" 
	then
	    IS_FILE_P=yes
	fi
    done

    if test "$IS_FILE_P" = "no"
    then 
	if test -z "$NEW_FILES"
	then 
	    NEW_FILES="$f2"
	else 
	    NEW_FILES="$NEW_FILES
$f2"
	fi
    fi
done
echo "$NEW_FILES"
}

describe_changed_dirs () {
echo "Removed directories:
-------------------------
$(get_new_files "$2" "$1")
-------------------------"

echo "New directories:
-------------------------
$(get_new_files "$1" "$2")
-------------------------"
}

################# Test #############################
#cd /home/linkfly/tmp
#
#FILE1=/home/linkfly/tmp/file1
#FILE2=/home/linkfly/tmp/file2
#D1=/home/linkfly/tmp/d1
#D2=/home/linkfly/tmp/d2
#
#cleanup () {
#rm -f $FILE1
#rm -f $FILE2
#rm -rf $D1
#rm -rf $D2
#}
#
#trap "cleanup" EXIT INT
#
#OLD_FILES="$(get_all_files "/home/linkfly/tmp")"
#OLD_DIRS="$(get_all_dirs "/home/linkfly/tmp")"
#
#touch $FILE1
#touch $FILE2
#mkdir $D1
#mkdir $D2
#
#FILES="$(get_all_files "/home/linkfly/tmp")"
#DIRS="$(get_all_dirs "/home/linkfly/tmp")"
#
#describe_changed_files_or_dirs "$OLD_FILES" "$FILES" "$OLD_DIRS" "$DIRS"
########################################