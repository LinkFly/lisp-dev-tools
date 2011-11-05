;;;; callback tests with side effects

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

;;; callbacks only on a few platforms
#-alien-callbacks
(quit :unix-status 104)

;;; simple callback for a function

(defun thunk ()
  (write-string "hi"))

(defvar *thunk*
  (sb-alien::alien-callback (function c-string) #'thunk))

(assert (equal (with-output-to-string (*standard-output*)
                 (alien-funcall *thunk*))
               "hi"))

;;; simple callback for a symbol

(defun add-two-ints (arg1 arg2)
  (+ arg1 arg2))

(defvar *add-two-ints*
  (sb-alien::alien-callback (function int int int) 'add-two-ints))

(assert (= (alien-funcall *add-two-ints* 555 444444) 444999))

;;; actually using a callback with foreign code

#+win32 (sb-alien:load-shared-object "ntdll.dll")

(define-alien-routine qsort void
  (base (* t))
  (nmemb int)
  (size int)
  (compar (function int (* double) (* double))))

(sb-alien::define-alien-callback double*-cmp int ((arg1 (* double)) (arg2 (* double)))
  (let ((a1 (deref arg1))
        (a2 (deref arg2)))
    (cond ((= a1 a2) 0)
          ((< a1 a2) -1)
          (t 1))))

(let* ((vector (coerce '(0.1d0 0.5d0 0.2d0 1.2d0 1.5d0 2.5d0 0.0d0 0.1d0 0.2d0 0.3d0)
                       '(vector double-float)))
       (sorted (sort (copy-seq vector) #'<)))
  (gc :full t)
  (sb-sys:with-pinned-objects (vector)
    (qsort (sb-sys:vector-sap vector)
           (length vector)
           (alien-size double :bytes)
           double*-cmp))
  (assert (equalp vector sorted)))

;;; returning floats

(sb-alien::define-alien-callback redefined-fun int ()
    0)

(eval
 '(sb-alien::define-alien-callback redefined-fun int ()
   42))

(assert (= 42 (alien-funcall redefined-fun)))

(sb-alien::define-alien-callback return-single float ((x float))
  x)

(sb-alien::define-alien-callback return-double double ((x double))
  x)

(defconstant spi (coerce pi 'single-float))

(assert (= spi (alien-funcall return-single spi)))
(assert (= pi (alien-funcall return-double pi)))

;;; invalidation

(sb-alien::define-alien-callback to-be-invalidated int ()
  5)

(assert (= 5 (alien-funcall to-be-invalidated)))

(multiple-value-bind (p valid) (sb-alien::alien-callback-p to-be-invalidated)
  (assert p)
  (assert valid))

(sb-alien::invalidate-alien-callback to-be-invalidated)

(multiple-value-bind (p valid) (sb-alien::alien-callback-p to-be-invalidated)
  (assert p)
  (assert (not valid)))

(multiple-value-bind (res err)
    (ignore-errors (alien-funcall to-be-invalidated))
  (assert (and (not res) (typep err 'error))))

;;; getting and setting the underlying function

(sb-alien::define-alien-callback foo int ()
  13)

(defvar *foo* #'foo)

(assert (eq #'foo (sb-alien::alien-callback-function foo)))

(defun bar ()
  26)

(setf (sb-alien::alien-callback-function foo) #'bar)

(assert (eq #'bar (sb-alien::alien-callback-function foo)))

(assert (= 26 (alien-funcall foo)))

;;; callbacks with void return values

(with-test (:name void-return)
  (sb-alien::alien-lambda void ()
    (values)))

;;; tests for integer-width problems in callback result handling

(defvar *add-two-ints*
  (sb-alien::alien-callback (function int int int) #'+))
(defvar *add-two-shorts*
  (sb-alien::alien-callback (function short short short) #'+))

;;; The original test cases here were what are now (:int-result
;;; :sign-extension) and (:int-result :underflow-detection), the latter
;;; of which would fail on 64-bit platforms.  Upon further investigation,
;;; it turned out that the same tests with a SHORT return type instead of
;;; an INT return type would also fail on 32-bit platforms.

(with-test (:name (:short-result :sign-extension))
  (assert (= (alien-funcall *add-two-shorts* #x-8000 1) -32767)))

(with-test (:name (:short-result :underflow-detection))
  (assert (raises-error? (alien-funcall *add-two-shorts* #x-8000 -1))))

(with-test (:name (:int-result :sign-extension))
  (assert (= (alien-funcall *add-two-ints* #x-80000000 1) -2147483647)))

(with-test (:name (:int-result :underflow-detection))
  (assert (raises-error? (alien-funcall *add-two-ints* #x-80000000 -1))))

;;; tests for handling 64-bit arguments - this was causing problems on
;;; ppc - CLH, 2005-12-01

(defvar *add-two-long-longs*
  (sb-alien::alien-callback
   (function (integer 64) (integer 64) (integer 64)) 'add-two-ints))
(with-test (:name :long-long-callback-arg)
  (assert (= (alien-funcall *add-two-long-longs*
                            (ash 1 60)
                            (- (ash 1 59)))
             (ash 1 59))))

(defvar *add-two-unsigned-long-longs*
  (sb-alien::alien-callback
   (function (unsigned 64) (unsigned 64) (unsigned 64))
   'add-two-ints))
(with-test (:name :unsigned-long-long-callback-arg)
  (assert (= (alien-funcall *add-two-unsigned-long-longs*
                            (ash 1 62)
                            (ash 1 62))
             (ash 1 63))))

;;; test for callbacks of various arities
;;; CLH 2005-12-21

(defmacro alien-apply-form (f args)
  `(let ((a ,args))
     `(alien-funcall ,,f ,@a)))

(defmacro alien-apply (f &rest args)
  `(eval (alien-apply-form ,f ,@args)))

(defun iota (x) (if (equalp x 1) (list x) (cons x (iota (1- x)))))

(defparameter *type-abbreviations*
  '((sb-alien:char . "c")
    (sb-alien:unsigned-char . "uc")
    (sb-alien:short . "h")
    (sb-alien:unsigned-short . "uh")
    (sb-alien:int . "i")
    (sb-alien:unsigned-int . "ui")
    ((sb-alien:integer 64) . "l")
    ((sb-alien:unsigned 64) . "ul")
    (sb-alien:float . "f")
    (sb-alien:double . "d")))

(defun parse-callback-arg-spec (spec)
  (let ((l (coerce spec 'list)))
    (loop for g in l by #'cddr
       collect (car (rassoc (string-downcase g) *type-abbreviations* :test #'equal)))))

(defmacro define-callback-adder (&rest types)
  (let ((fname (format nil "*add-~{~A~^-~}*"
                       (mapcar
                        #'(lambda (x)
                            (cdr (assoc x *type-abbreviations*)))
                        (mapcar
                         #'(lambda (y) (find-symbol (string-upcase y) 'sb-alien))
                         (cdr types))))))
    `(progn
      (defparameter ,(intern
                      (string-upcase fname))
        (sb-alien::alien-callback (function ,@types) '+)))))

(with-test (:name :define-2-int-callback)
  (define-callback-adder int int int))
(with-test (:name :call-2-int-callback)
  (assert (= (alien-apply *add-i-i* (iota 2)) 3)))

(with-test (:name :define-3-int-callback)
  (define-callback-adder int int int int))
(with-test (:name :call-3-int-callback)
  (assert (= (alien-apply *add-i-i-i* (iota 3)) 6)))

(with-test (:name :define-4-int-callback)
  (define-callback-adder int int int int int))
(with-test (:name :call-4-int-callback)
  (assert (= (alien-apply *add-i-i-i-i* (iota 4)) 10)))

(with-test (:name :define-5-int-callback)
  (define-callback-adder int int int int int int))
(with-test (:name :call-5-int-callback)
  (assert (= (alien-apply *add-i-i-i-i-i* (iota 5)) 15)))

(with-test (:name :define-6-int-callback)
  (define-callback-adder int int int int int int int))
(with-test (:name :call-6-int-callback)
  (assert (= (alien-apply *add-i-i-i-i-i-i* (iota 6)) 21)))

(with-test (:name :define-7-int-callback)
  (define-callback-adder int int int int int int int int))
(with-test (:name :call-7-int-callback)
  (assert (= (alien-apply *add-i-i-i-i-i-i-i* (iota 7)) 28)))

(with-test (:name :define-8-int-callback)
  (define-callback-adder int int int int int int int int int))
(with-test (:name :call-8-int-callback)
  (assert (= (alien-apply *add-i-i-i-i-i-i-i-i* (iota 8)) 36)))

(with-test (:name :define-9-int-callback)
  (define-callback-adder int int int int int int int int int int))
(with-test (:name :call-9-int-callback)
  (assert (= (alien-apply *add-i-i-i-i-i-i-i-i-i* (iota 9)) 45)))

(with-test (:name :define-10-int-callback)
  (define-callback-adder int int int int int int int int int int int))
(with-test (:name :call-10-int-callback)
  (assert (= (alien-apply *add-i-i-i-i-i-i-i-i-i-i* (iota 10)) 55)))

(with-test (:name :define-11-int-callback)
  (define-callback-adder int int int int int int int int int int int int))
(with-test (:name :call-11-int-callback)
  (assert (= (alien-apply *add-i-i-i-i-i-i-i-i-i-i-i* (iota 11)) 66)))

(with-test (:name :define-12-int-callback)
  (define-callback-adder int int int int int int int int int int int int int))
(with-test (:name :call-12-int-callback)
  (assert (= (alien-apply *add-i-i-i-i-i-i-i-i-i-i-i-i* (iota 12)) 78)))

(with-test (:name :define-2-float-callback)
  (define-callback-adder float float float))
(with-test (:name :call-2-float-callback)
  (assert (= (alien-apply *add-f-f* (iota 2.0s0)) 3.0s0)))

(with-test (:name :define-3-float-callback)
  (define-callback-adder float float float float))
(with-test (:name :call-3-float-callback)
  (assert (= (alien-apply *add-f-f-f* (iota 3.0s0)) 6.0s0)))

(with-test (:name :define-4-float-callback)
  (define-callback-adder float float float float float))
(with-test (:name :call-4-float-callback)
  (assert (= (alien-apply *add-f-f-f-f* (iota 4.0s0)) 10.0s0)))

(with-test (:name :define-5-float-callback)
  (define-callback-adder float float float float float float))
(with-test (:name :call-5-float-callback)
  (assert (= (alien-apply *add-f-f-f-f-f* (iota 5.0s0)) 15.0s0)))

(with-test (:name :define-6-float-callback)
  (define-callback-adder float float float float float float float))
(with-test (:name :call-6-float-callback)
  (assert (= (alien-apply *add-f-f-f-f-f-f* (iota 6.0s0)) 21.0s0)))

(with-test (:name :define-7-float-callback)
  (define-callback-adder float float float float float float float float))
(with-test (:name :call-7-float-callback)
  (assert (= (alien-apply *add-f-f-f-f-f-f-f* (iota 7.0s0)) 28.0s0)))

(with-test (:name :define-8-float-callback)
  (define-callback-adder float float float float float float float float float))
(with-test (:name :call-8-float-callback)
  (assert (= (alien-apply *add-f-f-f-f-f-f-f-f* (iota 8.0s0)) 36.0s0)))

(with-test (:name :define-9-float-callback)
  (define-callback-adder float float float float float float float float float float))
(with-test (:name :call-9-float-callback)
  (assert (= (alien-apply *add-f-f-f-f-f-f-f-f-f* (iota 9.0s0)) 45.0s0)))

(with-test (:name :define-10-float-callback)
  (define-callback-adder float float float float float float float float float float float))
(with-test (:name :call-10-float-callback)
  (assert (= (alien-apply *add-f-f-f-f-f-f-f-f-f-f* (iota 10.0s0)) 55.0s0)))

(with-test (:name :define-11-float-callback)
  (define-callback-adder float float float float float float float float float float float float))
(with-test (:name :call-11-float-callback)
  (assert (= (alien-apply *add-f-f-f-f-f-f-f-f-f-f-f* (iota 11.0s0)) 66.0s0)))

(with-test (:name :define-12-float-callback)
  (define-callback-adder float float float float float float float float float float float float float))
(with-test (:name :call-12-float-callback)
  (assert (= (alien-apply *add-f-f-f-f-f-f-f-f-f-f-f-f* (iota 12.0s0)) 78.0s0)))

(with-test (:name :define-2-double-callback)
  (define-callback-adder double double double))
(with-test (:name :call-2-double-callback)
  (assert (= (alien-apply *add-d-d* (iota 2.0d0)) 3.0d0)))

(with-test (:name :define-3-double-callback)
  (define-callback-adder double double double double))
(with-test (:name :call-3-double-callback)
  (assert (= (alien-apply *add-d-d-d* (iota 3.0d0)) 6.0d0)))

(with-test (:name :define-4-double-callback)
  (define-callback-adder double double double double double))
(with-test (:name :call-4-double-callback)
  (assert (= (alien-apply *add-d-d-d-d* (iota 4.0d0)) 10.0d0)))

(with-test (:name :define-5-double-callback)
  (define-callback-adder double double double double double double))
(with-test (:name :call-5-double-callback)
  (assert (= (alien-apply *add-d-d-d-d-d* (iota 5.0d0)) 15.0d0)))

(with-test (:name :define-6-double-callback)
  (define-callback-adder double double double double double double double))
(with-test (:name :call-6-double-callback)
  (assert (= (alien-apply *add-d-d-d-d-d-d* (iota 6.0d0)) 21.0d0)))

(with-test (:name :define-7-double-callback)
  (define-callback-adder double double double double double double double double))
(with-test (:name :call-7-double-callback)
  (assert (= (alien-apply *add-d-d-d-d-d-d-d* (iota 7.0d0)) 28.0d0)))

(with-test (:name :define-8-double-callback)
  (define-callback-adder double double double double double double double double double))
(with-test (:name :call-8-double-callback)
  (assert (= (alien-apply *add-d-d-d-d-d-d-d-d* (iota 8.0d0)) 36.0d0)))

(with-test (:name :define-9-double-callback)
  (define-callback-adder double double double double double double double double double double))
(with-test (:name :call-9-double-callback)
  (assert (= (alien-apply *add-d-d-d-d-d-d-d-d-d* (iota 9.0d0)) 45.0d0)))

(with-test (:name :define-10-double-callback)
  (define-callback-adder double double double double double double double double double double double))
(with-test (:name :call-10-double-callback)
  (assert (= (alien-apply *add-d-d-d-d-d-d-d-d-d-d* (iota 10.0d0)) 55.0d0)))

(with-test (:name :define-11-double-callback)
  (define-callback-adder double double double double double double double double double double double double))
(with-test (:name :call-11-double-callback)
  (assert (= (alien-apply *add-d-d-d-d-d-d-d-d-d-d-d* (iota 11.0d0)) 66.0d0)))

(with-test (:name :define-12-double-callback)
  (define-callback-adder double double double double double double double double double double double double double))
(with-test (:name :call-12-double-callback)
  (assert (= (alien-apply *add-d-d-d-d-d-d-d-d-d-d-d-d* (iota 12.0d0)) 78.0d0)))

(with-test (:name :define-int-float-callback)
  (define-callback-adder float int float))
(with-test (:name :call-int-float-callback)
  (assert (= (alien-funcall *add-i-f* 1 2.0s0) 3.0s0)))

(with-test (:name :define-float-int-callback)
  (define-callback-adder float float int))
(with-test (:name :call-float-int-callback)
  (assert (= (alien-funcall *add-f-i* 2.0s0 1) 3.0s0)))

(with-test (:name :define-int-double-callback)
  (define-callback-adder double int double))
(with-test (:name :call-int-double-callback)
  (assert (= (alien-funcall *add-i-d* 1 2.0d0) 3.0d0)))

(with-test (:name :define-double-int-callback)
  (define-callback-adder double double int))
(with-test (:name :call-double-int-callback)
  (assert (= (alien-funcall *add-d-i* 2.0d0 1) 3.0d0)))

(with-test (:name :define-double-float-callback)
  (define-callback-adder double double float))
(with-test (:name :call-double-float-callback)
  (assert (= (alien-funcall *add-d-f* 2.0d0 1.0s0) 3.0d0)))

(with-test (:name :define-float-double-callback)
  (define-callback-adder double float double))
(with-test (:name :call-double-float-callback)
  (assert (= (alien-funcall *add-f-d* 1.0s0 2.0d0) 3.0d0)))

(with-test (:name :define-double-float-int-callback)
  (define-callback-adder double double float int))
(with-test (:name :call-double-float-int-callback)
  (assert (= (alien-funcall *add-d-f-i* 2.0d0 1.0s0 1) 4.0d0)))
