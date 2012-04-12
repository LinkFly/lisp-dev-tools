#!/bin/sh
cd "$(dirname "$0")"
. ./includes.sh

for lisp in $(./get-all-lisps.sh "$@"); do
    LISP=$(downcase $lisp) ./provide-lisp.sh || exit 1;
done
