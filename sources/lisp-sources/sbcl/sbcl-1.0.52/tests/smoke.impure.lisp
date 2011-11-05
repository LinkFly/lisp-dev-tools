;;;; rudimentary tests ("smoke tests") for miscellaneous stuff which
;;;; doesn't seem to deserve specialized files at the moment

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; While most of SBCL is derived from the CMU CL system, the test
;;;; files (like this one) were written from scratch after the fork
;;;; from CMU CL.
;;;;
;;;; This software is in the public domain and is provided with
;;;; absolutely no warranty. See the COPYING and CREDITS files for
;;;; more information.

(cl:in-package :cl-user)

;;; ROOM should run without signalling an error. (bug 247)
(room)
(room t)
(room nil)

;;; COPY-SYMBOL should work without signalling an error, even if the
;;; symbol is unbound.
(copy-symbol 'foo)
(copy-symbol 'bar t)
(defvar *baz* nil)
(copy-symbol '*baz* t)

;;; SETQ should return its value.
(assert (typep (setq *baz* 1) 'integer))
(assert (typep (in-package :cl-user) 'package))

;;; PROFILE should run without obvious breakage
(progn
  (defun profiled-fun ()
    (random 1d0))
  (profile profiled-fun)
  (loop repeat 100000 do (profiled-fun))
  (report))

;;; Defconstant should behave as the documentation specifies,
;;; including documented condition type.
(defun oidentity (x) x)
(defconstant +const+ 1)
(assert (= (oidentity +const+) 1))
(let ((error (nth-value 1 (ignore-errors (defconstant +const+ 2)))))
  (assert (typep error 'sb-ext:defconstant-uneql))
  (assert (= (sb-ext:defconstant-uneql-old-value error) 1))
  (assert (= (sb-ext:defconstant-uneql-new-value error) 2))
  (assert (eql (sb-ext:defconstant-uneql-name error) '+const+)))
(assert (= (oidentity +const+) 1))
(handler-bind
    ((sb-ext:defconstant-uneql
         (lambda (c) (abort c))))
  (defconstant +const+ 3))
(assert (= (oidentity +const+) 1))
(handler-bind
    ((sb-ext:defconstant-uneql
         (lambda (c) (continue c))))
  (defconstant +const+ 3))
(assert (= (oidentity +const+) 3))

;;; MULTIPLE-VALUE-BIND and lambda list keywords
(multiple-value-bind (&rest &optional &key &allow-other-keys)
    (values 1 2 3)
  (assert (= &rest 1))
  (assert (= &optional 2))
  (assert (= &key 3))
  (assert (null &allow-other-keys)))

(let ((fn (lambda (&foo &rest &bar) (cons &foo &bar))))
  (assert (equal (funcall fn 1) '(1)))
  (assert (equal (funcall fn 1 2 3) '(1 2 3))))

;;; Failure to save a core is an error
(with-test (:name :save-lisp-and-die-error)
  (assert (eq :oops
              (handler-case (save-lisp-and-die "/")
                (error () :oops)))))

;;; success
