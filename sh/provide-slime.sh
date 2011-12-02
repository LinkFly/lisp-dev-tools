#!/bin/sh
cd $(dirname $0)
. ./includes.sh

./provide-lisp.sh
./provide-emacs.sh
./provide-quicklisp.sh

echo '(ql:quickload "quicklisp-slime-helper")' | ./run-lisp.sh
echo '
(load (concat (getenv "QUICKLISP") "/slime-helper.el"))
(if (string-equal (getenv "CUR_LISP") "clisp")
  (load (concat (genenv "LISP_DIR") "/share/emacs/site-lisp/clisp-coding.el")))
(setq slime-net-coding-system (quote utf-8-unix))
(set-language-environment "utf-8")
(setq inferior-lisp-program "run-lisp")' \
> $EMACS_LIBS/init-slime.el && echo "Line to run the SLIME copied into $EMACS_LIBS/init-slime.el"