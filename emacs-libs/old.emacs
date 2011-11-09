(load (expand-file-name "~/quicklisp/slime-helper.el"))

;; Replace "sbcl" with the path to your implementation
(setq inferior-lisp-program "sbcl")

;;; My added utf-8
(setq slime-net-coding-system 'utf-8-unix)
(set-language-environment "utf-8")
;;;;;;;;;;;;;;;;;;    

;;; Some emacs tweaks
(add-to-list 'auto-mode-alist '("\\.sexp\\'" . lisp-mode))  
(set-default-font "10x20")
(setq default-frame-alist
        (cons '(font . "10x20")
	      default-frame-alist))

;;;;;;;;;;;; Input method (input for russian text) ;;;;;;;;;;;
(set-input-method "russian-computer")
(toggle-input-method)
;;;;;;;;;;;;;;

(put 'upcase-region 'disabled nil)

(put 'downcase-region 'disabled nil)
