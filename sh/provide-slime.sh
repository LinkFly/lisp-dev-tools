#!/bin/sh
cd "$(dirname "$0")"
. ./includes.sh

if test -f "$EMACS_LIBS/init-slime.el";then
echo "
Slime already providing.
Initialization file: $EMACS_LIBS/init-slime.el

ALREADY."; exit 0;
fi

./provide-lisp.sh && ./provide-emacs.sh && ./provide-quicklisp.sh || exit 1

echo '(ql:quickload "quicklisp-slime-helper")' | ./run-lisp.sh
echo '
(let ((slime-helper (concat (getenv "QUICKLISP") "/slime-helper.el")))
  (when (and (file-exists-p slime-helper)
	     (not (boundp (quote init-slime.el-loaded))))
    (load slime-helper)
    (if (string-equal (getenv "CUR_LISP") "clisp")
	(load (concat (genenv "LISP_DIR") 
		      "/share/emacs/site-lisp/clisp-coding.el")))
    (setq slime-net-coding-system (quote utf-8-unix))
    (set-language-environment "utf-8")
    (setq inferior-lisp-program "run-lisp")
    (setq init-slime.el-loaded t)))' \
> "$EMACS_LIBS/init-slime.el" && echo;echo "ELisp code lines for run the SLIME - copied into $EMACS_LIBS/init-slime.el

OK."