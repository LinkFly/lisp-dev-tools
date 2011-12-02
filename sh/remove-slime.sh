#!/bin/sh
cd $(dirname $0)
. ./includes.sh

echo '(progn
        (ql-dist:uninstall (ql-dist:release "quicklisp-slime-helper"))
        (ql-dist:uninstall (ql-dist:release "slime"))
)' | ./run-lisp.sh

rm -f "$QUICKLISP/slime-helper.el"
echo "SLIME removed."
