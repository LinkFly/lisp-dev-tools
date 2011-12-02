
(load (concat (getenv "QUICKLISP") "/slime-helper.el"))
(if (string-equal (getenv "CUR_LISP") "clisp")
  (load (concat (genenv "LISP_DIR") "/share/emacs/site-lisp/clisp-coding.el")))
(setq slime-net-coding-system (quote utf-8-unix))
(set-language-environment "utf-8")
(setq inferior-lisp-program "run-lisp")
