#!/bin/sh

get_all_files () {
find "$1" -type f
}

get_all_dirs () {
find "$1" -type d
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

describe_changed_files () {
#echo "Removed files:"
#echo "-------------------------"
#echo "$(get_new_files "$2" "$1")"
#echo "-------------------------"
#echo 
echo "Removed directories:"
echo "-------------------------"
echo "$(get_new_files "$4" "$3")"
echo "-------------------------"

#echo "New files:"
#echo "-------------------------"
#echo "$(get_new_files "$1" "$2")"
#echo "-------------------------"
#echo
echo "New directories:"
echo "-------------------------"
echo "$(get_new_files "$3" "$4")"
echo "-------------------------"
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
#describe_changed_files "$OLD_FILES" "$FILES" "$OLD_DIRS" "$DIRS"
########################################