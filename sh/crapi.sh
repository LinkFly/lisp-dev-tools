#!/bin/sh
cd $(dirname $0)/..

crapi () {
resapi=${1%.*}
printf '#!' > $resapi;
printf "/bin/sh\n" >> $resapi;
printf 'cd $(dirname $0)\n' >> $resapi;
local args='$@';
printf "sh/$1 \"$args\"" >> $resapi; 
printf "" >> $resapi; 
chmod u+x $resapi;
}

crapi $1