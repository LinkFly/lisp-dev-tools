;;;; miscellaneous tests of compiling toplevel forms

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

(in-package :cl-user)

;;; Exercise a compiler bug (by causing a call to ERROR).
;;;
;;; This bug was in sbcl-0.6.11.6.
(let ((a 1) (b 1))
  (declare (type (mod 1000) a b))
  (let ((tmp (= 10 (+ (incf a) (incf a) (incf b) (incf b)))))
    (or tmp (error "TMP not true"))))

;;; Exercise a (byte-)compiler bug by causing a call to ERROR, not
;;; because the symbol isn't defined as a variable, but because
;;;  TYPE-ERROR in SB-KERNEL::OBJECT-NOT-TYPE-ERROR-HANDLER:
;;;     0 is not of type (OR FUNCTION SB-KERNEL:FDEFN).
;;; Correct behavior is to warn at compile time because the symbol
;;; isn't declared as a variable, but to set its SYMBOL-VALUE anyway.
;;;
;;; This bug was in sbcl-0.6.11.13.
(print (setq improperly-declared-var '(1 2)))
(assert (equal (symbol-value 'improperly-declared-var) '(1 2)))
(makunbound 'improperly-declared-var)
;;; This is a slightly different way of getting the same symptoms out
;;; of the sbcl-0.6.11.13 byte compiler bug.
(print (setq *print-level* *print-level*))

;;; PROGV with different numbers of variables and values
(let ((a 1))
  (declare (special a))
  (assert (equal (list a (progv '(a b) '(:a :b :c)
                           (assert (eq (symbol-value 'nil) nil))
                           (list (symbol-value 'a) (symbol-value 'b)))
                       a)
                 '(1 (:a :b) 1)))
  (assert (equal (list a (progv '(a b) '(:a :b)
                           (assert (eq (symbol-value 'nil) nil))
                           (list (symbol-value 'a) (symbol-value 'b)))
                       a)
                 '(1 (:a :b) 1)))
  (assert (not (boundp 'b))))

(let ((a 1) (b 2))
  (declare (special a b))
  (assert (equal (list a b (progv '(a b) '(:a)
                             (assert (eq (symbol-value 'nil) nil))
                             (assert (not (boundp 'b)))
                             (symbol-value 'a))
                       a b)
                 '(1 2 :a 1 2))))

;;; bug in LOOP, reported by ??? on c.l.l
(flet ((foo (l)
         (loop for x in l
               when (symbolp x) return x
               while (numberp x)
               collect (list x))))
  (assert (equal (foo '(1 2 #\a 3)) '((1) (2))))
  (assert (equal (foo '(1 2 x 3)) 'x)))

;;; compiler failure found by Paul Dietz' randomized tortuter
(defun #:foo (a b c d)
  (declare (type (integer 240 100434465) a)
           (optimize (speed 3) (safety 1) (debug 1)))
  (logxor
   (if (ldb-test (byte 27 4) d)
       -1
       (max 55546856 -431))
   (logorc2
    (if (>= 0 b)
        (if (> b c) (logandc2 c d) (if (> d 224002) 0 d))
        (signum (logior c b)))
    (logior a -1))))

(defun #:foo (b c)
  (declare (type (integer -23228343 2) b)
           (type (integer -115581022 512244512) c)
           (optimize (speed 3) (safety 1) (debug 1)))
  (* (* (logorc2 3 (deposit-field 4667947 (byte 14 26) b))
        (deposit-field b (byte 25 27) -30424886))
     (dpb b (byte 23 29) c)))

(defun #:foo (x y)
  (declare (type (integer -1 1000000000000000000000000) x y)
           (optimize speed))
  (* x (* y x)))

(defun #:foo (b)
  (declare (type (integer -290488443 2) b)
           (optimize (speed 3) (safety 1) (debug 1)))
  (let ((v3 (min -1720 b))) (max v3 (logcount (if (= v3 b) b b)))))

(defun #:foo (d)
  (let ((v7 (flet ((%f16 () (labels ((%f3 () -8)) (%f3))))
              (labels ((%f7 () (%f16)))  d))))
    132887443))

;;; RESULT-FORM in DO is not contained in the implicit TAGBODY
(assert (eq (handler-case (eval `(do ((x '(1 2 3) (cdr x)))
                                     ((endp x) (go :loop))
                                  :loop
                                   (unless x (return :bad))))
              (error () :good))
            :good))
(assert (eq (handler-case (eval `(do* ((x '(1 2 3) (cdr x)))
                                      ((endp x) (go :loop))
                                  :loop
                                   (unless x (return :bad))))
              (error () :good))
            :good))

;;; bug 282
;;;
;;; Verify type checking policy in full calls: the callee is supposed
;;; to perform check, but the results should not be used before the
;;; check will be actually performed.
(locally
    (declare (optimize (safety 3)))
  (flet ((bar (f a)
           (declare (type (simple-array (unsigned-byte 32) (*)) a))
           (declare (type (function (fixnum)) f))
           (funcall f (aref a 0))))
    #-x86-64
    (assert
     (eval `(let ((n (1+ most-positive-fixnum)))
              (if (not (typep n '(unsigned-byte 32)))
                  (warn 'style-warning
                        "~@<This test is written for platforms with ~
                        ~@<(proper-subtypep 'fixnum '(unsigned-byte 32))~:@>.~:@>")
                  (block nil
                    (funcall ,#'bar
                             (lambda (x) (when (eql x n) (return t)))
                             (make-array 1 :element-type '(unsigned-byte 32)
                                         :initial-element n))
                    nil)))))))

;;; bug 261
(let ((x (list (the (values &optional fixnum) (eval '(values))))))
  (assert (equal x '(nil))))

;;; Bug 125, reported by Gabe Garza: Python did not preserve identity
;;; of closures.
(flet ((test-case (test-pred x)
         (let ((func (lambda () x)))
           (list (eq func func)
                 (funcall test-pred func func)
                 (delete func (list func))))))
  (assert (equal '(t t nil) (funcall (eval #'test-case) #'eq 3))))

;;; compiler failure reported by Alan Shields:
;;; MAYBE-INFER-ITERATION-VAR-TYPE did not deal with types (REAL * (n)).
(let ((s (loop for x from (- pi) below (floor (* 2 pi)) by (/ pi 75) count t)))
  (assert (= s 219)))
