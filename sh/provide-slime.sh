#!/bin/sh
cd $(dirname $0)
. ./includes.sh

./provide-lisp.sh
./provide-emacs.sh
./provide-quicklisp.sh
echo '(ql:quickload "quicklisp-slime-helper")' | ./run-lisp.sh
echo '
(load (concat (getenv "QUICKLISP") "/slime-helper.el"))
(setq inferior-lisp-program "run-lisp")' \
> $EMACS_LIBS/init-slime.el && echo "Line to run the SLIME copied into $EMACS_LIBS/init-slime.el"