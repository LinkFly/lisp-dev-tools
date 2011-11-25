#!/bin/sh
cd $(dirname $0)

for lisp in $(./get-all-lisps.sh); do
    LISP=$lisp ./provide-lisp.sh
done
