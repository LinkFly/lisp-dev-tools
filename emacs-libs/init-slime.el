(let ((slime-helper (concat (getenv "QUICKLISP") "/slime-helper.el")))
  (when (and slime-helper
	     (not (boundp 'init-slime.el-loaded)))
    (load slime-helper)
    (if (string-equal (getenv "CUR_LISP") "clisp")
	(load (concat (genenv "LISP_DIR") 
		      "/share/emacs/site-lisp/clisp-coding.el")))
    (setq slime-net-coding-system (quote utf-8-unix))
    (set-language-environment "utf-8")
    (setq inferior-lisp-program "run-lisp")
    (setq init-slime.el-loaded t)))
