
;;;
;;; The order of the forms must not change, as the order is checked in
;;; `test-driver.lisp'. Thus do not alter this file unless you edit
;;; test-driver.lisp to match.
;;;

(declaim (optimize (debug 3)))
(in-package :cl-user)

(defun one (a b c) (+ a b c))

(defgeneric two (a b))
(defmethod two ((a number) b)
  (* 2 a))

(defstruct three four five)

(with-compilation-unit (:source-plist (list :test-inner "IN"))
  (eval '(defun four () 4)))

"oops-off-by-one"

(defparameter *a* 1)

(defvar *b* 2)

(defclass a ()
  (a))

(define-condition b (warning) (a))

(defstruct c e f)

(defstruct (d (:type list)) e f)

(defpackage e (:use :cl))

(define-symbol-macro f 'e)

(deftype g () 'fixnum)

(defconstant +h+ 1)

(defmethod j ((a t))
  2)

(defmethod j ((b null))
  2)

(defmacro l (a)
  a)

(define-compiler-macro m (a)
  (declare (ignore a))
  'b)

(defsetf n (a) (store)
  (format t "~a ~a~%" a store))

(defun (setf o) (x)
  (print x))

(defmethod (setf p) (x y)
  (format t "~a ~a~%" x y))

(define-modify-macro q (x) logand)

(define-method-combination r nil)

(define-setf-expander s (a b)
  (format t "~a ~a~%" a b))

(eval-when (:compile-toplevel)
  (defun compile-time-too-fun ()
    :foo))
