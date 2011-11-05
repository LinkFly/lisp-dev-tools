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

;;; this file tests that it is not possible to add an
;;; optimization-invalidating method to #'(SETF
;;; SLOT-VALUE-USING-CLASS).  If a way is found to preserve the
;;; optimization, or if the optimization is deemed to be invalid, then
;;; this test can go away.

(defpackage "MOP-16"
  (:use "CL" "SB-MOP"))

(in-package "MOP-16")

(defclass foo-class (standard-class) ())

(defclass foo-effective-slot-definition (standard-effective-slot-definition)
  ())

(multiple-value-bind (value condition)
    (ignore-errors
      (defmethod (setf slot-value-using-class)
          ((new-value integer) (class foo-class)
           (object standard-object) (slotd foo-effective-slot-definition))
        "Haha"))
  (assert (null value))
  (assert (typep condition 'error)))
