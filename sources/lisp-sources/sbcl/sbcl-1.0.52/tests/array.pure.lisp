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

;;; Array initialization has complicated defaulting for :ELEMENT-TYPE,
;;; and both compile-time and run-time logic takes a whack at it.
(let ((testcases '(;; Bug 126, confusion between high-level default string
                   ;; initial element #\SPACE and low-level default array
                   ;; element #\NULL, is gone.
                   (#\null (make-array 11 :element-type 'character) simple-string)
                   (#\space (make-string 11 :initial-element #\space) string)
                   (#\* (make-string 11 :initial-element #\*))
                   (#\null (make-string 11))
                   (#\null (make-string 11 :initial-element #\null))
                   (#\x (make-string 11 :initial-element #\x))
                   ;; And the other tweaks made when fixing bug 126 didn't
                   ;; mess things up too badly either.
                   (0 (make-array 11) simple-vector)
                   (nil (make-array 11 :initial-element nil))
                   (12 (make-array 11 :initial-element 12))
                   (0 (make-array 11 :element-type '(unsigned-byte 4)) (simple-array (unsigned-byte 4) (*)))
                   (12 (make-array 11
                                   :element-type '(unsigned-byte 4)
                                   :initial-element 12)))))
  (dolist (testcase testcases)
    (destructuring-bind (expected-result form &optional type) testcase
      (unless (eql expected-result (aref (eval form) 3))
        (error "expected ~S in EVAL ~S" expected-result form))
      (unless (eql expected-result
                   (aref (funcall (compile nil `(lambda () ,form))) 3))
        (error "expected ~S in FUNCALL COMPILE ~S" expected-result form))
      ;; also do some testing of compilation and verification that
      ;; errors are thrown appropriately.
      (unless (eql expected-result
                   (funcall (compile nil `(lambda () (aref ,form 3)))))
        (error "expected ~S in COMPILED-AREF ~S" expected-result form))
      (when type
        (unless (eql expected-result
                     (funcall (compile nil `(lambda () (let ((x ,form))
                                                         (declare (type ,type x))
                                                         (aref x 3))))))
          (error "expected ~S in COMPILED-DECLARED-AREF ~S" expected-result form)))
      (when (ignore-errors (aref (eval form) 12))
        (error "error not thrown in EVAL ~S" form))
      (when (ignore-errors (aref (funcall (compile nil `(lambda () ,form))) 12))
        (error "error not thrown in FUNCALL COMPILE ~S"))
      (when (ignore-errors (funcall (compile nil `(lambda () (aref ,form 12)))))
        (error "error not thrown in COMPILED-AREF ~S" form))
      (when type
        (when (ignore-errors (funcall
                              (compile nil `(lambda () (let ((x ,form))
                                                         (declare (type ,type x))
                                                         (aref x 12))))))
          (error "error not thrown in COMPILED-DECLARED-AREF ~S" form))))))

;;; On the SPARC, until sbcl-0.7.7.20, there was a bug in array
;;; references for small vector elements (spotted by Raymond Toy); the
;;; bug persisted on the PPC until sbcl-0.7.8.20.
(let (vector)
  (loop for i below 64
        for list = (make-list 64 :initial-element 1)
        do (setf (nth i list) 0)
        do (setf vector (make-array 64 :element-type 'bit
                                       :initial-contents list))
        do (assert (= (funcall
                       (compile nil
                                `(lambda (rmdr)
                                  (declare (type (simple-array bit (*)) rmdr)
                                           (optimize (speed 3) (safety 0)))
                                  (aref rmdr ,i)))
                       vector)
                      0))))

;;; Following refactoring of sequence functions to detect bad type
;;; specifiers, REVERSE was left broken on vectors with fill pointers.
(let ((a (make-array 10
                     :fill-pointer 5
                     :element-type 'character
                     :initial-contents "abcdefghij")))
  (assert (string= (reverse a) "edcba")))

;;; ARRAY-IN-BOUNDS-P should work when given non-INDEXes as its
;;; subscripts (and return NIL, of course)
(let ((a (make-array 10 :fill-pointer 5)))
  (assert (not (array-in-bounds-p a -1)))
  (assert (array-in-bounds-p a 3))
  (assert (array-in-bounds-p a 7))
  (assert (not (array-in-bounds-p a 11)))
  (assert (not (array-in-bounds-p a (1+ most-positive-fixnum)))))

;;; arrays of bits should work:
(let ((a (make-array '(10 10) :element-type 'bit :adjustable t)))
  (setf (bit a 0 0) 1)
  (assert (= (bit a 0 0) 1)))
(let ((a (make-array '(10 10) :element-type 'bit)))
  (setf (sbit a 0 0) 1)
  (assert (= (sbit a 0 0) 1)))

(let ((x (copy-seq #*0011))
      (y (copy-seq #*0101)))
  (assert (equalp (bit-and x y nil) #*0001)))

;;; arrays of NIL should work, FSVO "work".
(let ((a (make-array '(10 10) :element-type 'nil)))
  (assert (= (array-total-size a) 100))
  (assert (equal (array-dimensions a) '(10 10)))
  (assert (eq (array-element-type a) 'nil)))

(assert (eq (upgraded-array-element-type 'nil) 'nil))

(multiple-value-bind (fun warn fail)
    (compile nil '(lambda () (aref (make-array 0) 0)))
  #+nil (assert fail) ; doesn't work, (maybe because ASSERTED-TYPE is NIL?)
  (assert (raises-error? (funcall fun) type-error)))

(multiple-value-bind (fun warn fail)
    (compile nil '(lambda () (aref (make-array 1) 1)))
  (assert fail)
  (assert (raises-error? (funcall fun) type-error)))

(multiple-value-bind (fun warn fail)
    (compile nil '(lambda () (make-array 5 :element-type 'undefined-type)))
  (assert warn))

(flet ((opaque-identity (x) x))
  (declare (notinline opaque-identity))
  ;; we used to have leakage from cross-compilation hosts of the INDEX
  ;; type, which prevented us from actually using all the large array
  ;; dimensions that we promised.  Let's make sure that we can create
  ;; an array with more than 2^24 elements, since that was a symptom
  ;; from the CLISP and OpenMCL hosts.
  (let ((big-array (opaque-identity
                    (make-array (expt 2 26) :element-type 'bit))))
    (assert (= (length big-array) (expt 2 26)))))

;;; Bug reported by Kalle Olavi Niemitalo for CMUCL through Debian BTS
(let ((array (make-array nil :initial-contents nil)))
  (assert (eql (aref array) nil)))

(let ((f (compile nil '(lambda ()
                        (let ((a (make-array '(4)
                                             :element-type 'base-char
                                             :initial-element #\z)))
                          (setf (aref a 0) #\a)
                          (setf (aref a 1) #\b)
                          (setf (aref a 2) #\c)
                          a)))))
  (assert (= (length (funcall f)) 4)))

(let ((x (make-array nil :initial-element 'foo)))
  (adjust-array x nil)
  (assert (eql (aref x) 'foo)))

;;; BUG 315: "no bounds check for access to displaced array"
;;;  reported by Bruno Haible sbcl-devel "various SBCL bugs" from CLISP
;;;  test suite.
(locally (declare (optimize (safety 3) (speed 0)))
  (let* ((x (make-array 10 :fill-pointer 4 :element-type 'character
                        :initial-element #\space :adjustable t))
         (y (make-array 10 :fill-pointer 4 :element-type 'character
                        :displaced-to x)))
    (assert (eq x (adjust-array x '(5))))
    (assert (eq :error (handler-case
                           (char y 0)
                         (sb-int:invalid-array-error (e)
                           (assert (eq y (type-error-datum e)))
                           (assert (equal `(vector character 10)
                                          (type-error-expected-type e)))
                           :error))))))

;;; MISC.527: bit-vector bitwise operations used LENGTH to get a size
;;; of a vector
(flet ((bit-vector-equal (v1 v2)
         (and (bit-vector-p v1) (bit-vector-p v2)
              (equal (array-dimension v1 0) (array-dimension v2 0))
              (loop for i below (array-dimension v1 0)
                    always (eql (aref v1 i) (aref v2 i))))))
  (let* ((length 1024)
         (v1 (make-array length :element-type 'bit :fill-pointer 0))
         (v2 (make-array length :element-type 'bit :fill-pointer 1)))
    (loop for i from 0 below length
          for x1 in '#1=(0 0 1 1 . #1#)
          and x2 in '#2=(0 1 0 1 . #2#)
          do (setf (aref v1 i) x1)
          do (setf (aref v2 i) x2))
    (loop for (bf lf) in '((bit-and logand)
                           (bit-andc1 logandc1)
                           (bit-andc2 logandc2)
                           (bit-eqv logeqv)
                           (bit-ior logior)
                           (bit-nand lognand)
                           (bit-nor lognor)
                           (bit-orc1 logorc1)
                           (bit-orc2 logorc2)
                           (bit-xor logxor)
                           ((lambda (x y) (bit-not x)) #.(lambda (x y) (lognot x))))
          for fun = (compile nil `(lambda (v)
                                    (declare (type (array bit (*)) v))
                                    (declare (optimize (speed 3) (safety 0)))
                                    (,bf v ,v2)))
          for r1 = (funcall fun v1)
          and r2 = (coerce (loop for i below length
                                 collect (logand 1 (funcall lf (aref v1 i) (aref v2 i))))
                           'bit-vector)
          do (assert (bit-vector-equal r1 r2)))))

(with-test (:name (adjust-array fill-pointer))
  ;; CLHS, ADJUST-ARRAY: An error of type error is signaled if
  ;; fill-pointer is supplied and non-nil but array has no fill pointer.
  (assert (eq :good
              (handler-case
                  (let ((array (make-array 12)))
                    (assert (not (array-has-fill-pointer-p array)))
                    (adjust-array array 12 :fill-pointer t)
                    array)
                (type-error ()
                  :good)))))

(with-test (:name (adjust-array multidimensional))
  (let ((ary (make-array '(2 2))))
    ;; SBCL used to give multidimensional arrays a bogus fill-pointer
    (assert (not (array-has-fill-pointer-p (adjust-array ary '(2 2)))))))

(with-test (:name %set-fill-pointer/error)
  (let ((v (make-array 3 :fill-pointer 0)))
    (handler-case
        (progn
          (setf (fill-pointer v) 12)
          (error "WTF"))
      (error (e)
        (assert (eql 12 (type-error-datum e)))
        (assert (equal '(integer 0 3) (type-error-expected-type e)))))))

(with-test (:name array-storage-vector)
  (let ((vec (vector 1 2 3)))
    (assert (eq vec (sb-ext:array-storage-vector vec)))
    (assert (equalp (vector 1 2 3 4)
                    (sb-ext:array-storage-vector
                     (make-array '(2 2) :initial-contents '((1 2) (3 4))))))
    (assert (eq 'fixnum (array-element-type
                         (sb-ext:array-storage-vector (make-array '(3 4 5)
                                                                 :element-type 'fixnum)))))
    (assert (not (array-has-fill-pointer-p
                  (sb-ext::array-storage-vector
                   (make-array 5 :fill-pointer 4)))))))

(with-test (:name invalid-array-index-error)
  (let ((array (make-array '(3 3 3))))
    (assert
     (eq :right
         (handler-case
             (eval `(aref ,array 0 1 3))
           (sb-int:invalid-array-index-error (e)
             (when (and (eq array (sb-kernel::invalid-array-index-error-array e))
                        (= 3 (type-error-datum e))
                        (equal '(integer 0 (3)) (type-error-expected-type e)))
               :right)))))))

(with-test (:name :out-of-bounds-error-details)
  (assert (eq :good
              (handler-case
                  (flet ((test (array i)
                           (aref array i)))
                    (test (eval '(vector 0 1 2 3)) 6))
                (sb-int:invalid-array-index-error (e)
                  (when (and (equal '(integer 0 (4))
                                    (type-error-expected-type e))
                             (eql 6 (type-error-datum e)))
                    :good))))))

(with-test (:name :odd-keys-for-make-array)
  (assert (eq :good
              (handler-case
                  (compile nil '(lambda (m) (make-array m 1)))
                (simple-warning () :good)))))

