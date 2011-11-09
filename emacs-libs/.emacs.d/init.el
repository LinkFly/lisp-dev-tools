(setq default-theme 'solarized-light)
;(setq default-theme 'solarized-dark)

(defun set-color-theme-solarized ()
  (add-to-list 'load-path "~/.emacs.d/emacs-color-theme-solarized/")
  (require 'color-theme-solarized)
  (enable-theme default-theme))

(set-color-theme-solarized)

(defun set-color-theme ()
  (require 'color-theme)
  (eval-after-load "color-theme"
    '(progn 
       (color-theme-initialize)
       (color-theme-hober))))

;(set-color-theme)


