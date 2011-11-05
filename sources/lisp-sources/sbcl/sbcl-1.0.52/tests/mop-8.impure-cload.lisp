;;;; miscellaneous side-effectful tests of the MOP

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

;;; This file contains tests of UPDATE-DEPENDENT.

(defpackage "MOP-8"
  (:use "CL" "SB-MOP" "TEST-UTIL"))

(in-package "MOP-8")

(defclass dependent-history ()
  ((history :initarg :history :accessor history)))

(defmethod update-dependent ((generic-function generic-function)
                             (history dependent-history)
                             &rest args)
  (push args (history history)))
(defmethod update-dependent ((class class)
                             (history dependent-history)
                             &rest args)
  (push (cons class args) (history history)))

(defvar *history* (make-instance 'dependent-history :history nil))

(defgeneric upd1 (x))
(add-dependent #'upd1 *history*)
(defmethod upd1 ((x integer)) x)
(let ((last (car (history *history*))))
  (assert (eq (car last) 'add-method))
  (assert (typep (cadr last) 'standard-method)))

(defclass foo ()
  ())
(add-dependent (find-class 'foo) *history*)
(defclass foo ()
  ((a :initarg :a)))
(let ((last (car (history *history*))))
  (assert (eq (car last) (find-class 'foo))))
