#!/bin/sh
cd $(dirname $0)
. ./includes.sh

echo '(progn
        (ql-dist:uninstall (ql-dist:release "quicklisp-slime-helper"))
        (ql-dist:uninstall (ql-dist:release "slime"))
)' | LISP_BEGIN_OPTIONS='--noinform --noprint' ./run-lisp.sh

rm -f "$QUICKLISP/slime-helper.el"
rm -f "$EMACS_LIBS/init-slime.el"
echo "SLIME removed."
