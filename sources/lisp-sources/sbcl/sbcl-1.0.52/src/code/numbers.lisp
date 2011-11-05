;;;; This file contains the definitions of most number functions.

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; This software is derived from the CMU CL system, which was
;;;; written at Carnegie Mellon University and released into the
;;;; public domain. The software is in the public domain and is
;;;; provided with absolutely no warranty. See the COPYING and CREDITS
;;;; files for more information.

(in-package "SB!KERNEL")

;;;; the NUMBER-DISPATCH macro

(eval-when (:compile-toplevel :load-toplevel :execute)

;;; Grovel an individual case to NUMBER-DISPATCH, augmenting RESULT
;;; with the type dispatches and bodies. Result is a tree built of
;;; alists representing the dispatching off each arg (in order). The
;;; leaf is the body to be executed in that case.
(defun parse-number-dispatch (vars result types var-types body)
  (cond ((null vars)
         (unless (null types) (error "More types than vars."))
         (when (cdr result)
           (error "Duplicate case: ~S." body))
         (setf (cdr result)
               (sublis var-types body :test #'equal)))
        ((null types)
         (error "More vars than types."))
        (t
         (flet ((frob (var type)
                  (parse-number-dispatch
                   (rest vars)
                   (or (assoc type (cdr result) :test #'equal)
                       (car (setf (cdr result)
                                  (acons type nil (cdr result)))))
                   (rest types)
                   (acons `(dispatch-type ,var) type var-types)
                   body)))
           (let ((type (first types))
                 (var (first vars)))
             (if (and (consp type) (eq (first type) 'foreach))
                 (dolist (type (rest type))
                   (frob var type))
                 (frob var type)))))))

;;; our guess for the preferred order in which to do type tests
;;; (cheaper and/or more probable first.)
(defparameter *type-test-ordering*
  '(fixnum single-float double-float integer #!+long-float long-float bignum
    complex ratio))

;;; Should TYPE1 be tested before TYPE2?
(defun type-test-order (type1 type2)
  (let ((o1 (position type1 *type-test-ordering*))
        (o2 (position type2 *type-test-ordering*)))
    (cond ((not o1) nil)
          ((not o2) t)
          (t
           (< o1 o2)))))

;;; Return an ETYPECASE form that does the type dispatch, ordering the
;;; cases for efficiency.
(defun generate-number-dispatch (vars error-tags cases)
  (if vars
      (let ((var (first vars))
            (cases (sort cases #'type-test-order :key #'car)))
        `((typecase ,var
            ,@(mapcar (lambda (case)
                        `(,(first case)
                          ,@(generate-number-dispatch (rest vars)
                                                      (rest error-tags)
                                                      (cdr case))))
                      cases)
            (t (go ,(first error-tags))))))
      cases))

) ; EVAL-WHEN

;;; This is a vaguely case-like macro that does number cross-product
;;; dispatches. The Vars are the variables we are dispatching off of.
;;; The Type paired with each Var is used in the error message when no
;;; case matches. Each case specifies a Type for each var, and is
;;; executed when that signature holds. A type may be a list
;;; (FOREACH Each-Type*), causing that case to be repeatedly
;;; instantiated for every Each-Type. In the body of each case, any
;;; list of the form (DISPATCH-TYPE Var-Name) is substituted with the
;;; type of that var in that instance of the case.
;;;
;;; As an alternate to a case spec, there may be a form whose CAR is a
;;; symbol. In this case, we apply the CAR of the form to the CDR and
;;; treat the result of the call as a list of cases. This process is
;;; not applied recursively.
(defmacro number-dispatch (var-specs &body cases)
  (let ((res (list nil))
        (vars (mapcar #'car var-specs))
        (block (gensym)))
    (dolist (case cases)
      (if (symbolp (first case))
          (let ((cases (apply (symbol-function (first case)) (rest case))))
            (dolist (case cases)
              (parse-number-dispatch vars res (first case) nil (rest case))))
          (parse-number-dispatch vars res (first case) nil (rest case))))

    (collect ((errors)
              (error-tags))
      (dolist (spec var-specs)
        (let ((var (first spec))
              (type (second spec))
              (tag (gensym)))
          (error-tags tag)
          (errors tag)
          (errors `(return-from
                    ,block
                    (error 'simple-type-error :datum ,var
                           :expected-type ',type
                           :format-control
                           "~@<Argument ~A is not a ~S: ~2I~_~S~:>"
                           :format-arguments
                           (list ',var ',type ,var))))))

      `(block ,block
         (tagbody
           (return-from ,block
                        ,@(generate-number-dispatch vars (error-tags)
                                                    (cdr res)))
           ,@(errors))))))

;;;; binary operation dispatching utilities

(eval-when (:compile-toplevel :execute)

;;; Return NUMBER-DISPATCH forms for rational X float.
(defun float-contagion (op x y &optional (rat-types '(fixnum bignum ratio)))
  `(((single-float single-float) (,op ,x ,y))
    (((foreach ,@rat-types)
      (foreach single-float double-float #!+long-float long-float))
     (,op (coerce ,x '(dispatch-type ,y)) ,y))
    (((foreach single-float double-float #!+long-float long-float)
      (foreach ,@rat-types))
     (,op ,x (coerce ,y '(dispatch-type ,x))))
    #!+long-float
    (((foreach single-float double-float long-float) long-float)
     (,op (coerce ,x 'long-float) ,y))
    #!+long-float
    ((long-float (foreach single-float double-float))
     (,op ,x (coerce ,y 'long-float)))
    (((foreach single-float double-float) double-float)
     (,op (coerce ,x 'double-float) ,y))
    ((double-float single-float)
     (,op ,x (coerce ,y 'double-float)))))

;;; Return NUMBER-DISPATCH forms for bignum X fixnum.
(defun bignum-cross-fixnum (fix-op big-op)
  `(((fixnum fixnum) (,fix-op x y))
    ((fixnum bignum)
     (,big-op (make-small-bignum x) y))
    ((bignum fixnum)
     (,big-op x (make-small-bignum y)))
    ((bignum bignum)
     (,big-op x y))))

) ; EVAL-WHEN

;;;; canonicalization utilities

;;; If IMAGPART is 0, return REALPART, otherwise make a complex. This is
;;; used when we know that REALPART and IMAGPART are the same type, but
;;; rational canonicalization might still need to be done.
#!-sb-fluid (declaim (inline canonical-complex))
(defun canonical-complex (realpart imagpart)
  (if (eql imagpart 0)
      realpart
      (cond #!+long-float
            ((and (typep realpart 'long-float)
                  (typep imagpart 'long-float))
             (truly-the (complex long-float) (complex realpart imagpart)))
            ((and (typep realpart 'double-float)
                  (typep imagpart 'double-float))
             (truly-the (complex double-float) (complex realpart imagpart)))
            ((and (typep realpart 'single-float)
                  (typep imagpart 'single-float))
             (truly-the (complex single-float) (complex realpart imagpart)))
            (t
             (%make-complex realpart imagpart)))))

;;; Given a numerator and denominator with the GCD already divided
;;; out, make a canonical rational. We make the denominator positive,
;;; and check whether it is 1.
#!-sb-fluid (declaim (inline build-ratio))
(defun build-ratio (num den)
  (multiple-value-bind (num den)
      (if (minusp den)
          (values (- num) (- den))
          (values num den))
    (cond
      ((eql den 0)
       (error 'division-by-zero
              :operands (list num den)
              :operation 'build-ratio))
      ((eql den 1) num)
      (t (%make-ratio num den)))))

;;; Truncate X and Y, but bum the case where Y is 1.
#!-sb-fluid (declaim (inline maybe-truncate))
(defun maybe-truncate (x y)
  (if (eql y 1)
      x
      (truncate x y)))

;;;; COMPLEXes

(defun complex (realpart &optional (imagpart 0))
  #!+sb-doc
  "Return a complex number with the specified real and imaginary components."
  (flet ((%%make-complex (realpart imagpart)
           (cond #!+long-float
                 ((and (typep realpart 'long-float)
                       (typep imagpart 'long-float))
                  (truly-the (complex long-float)
                             (complex realpart imagpart)))
                 ((and (typep realpart 'double-float)
                       (typep imagpart 'double-float))
                  (truly-the (complex double-float)
                             (complex realpart imagpart)))
                 ((and (typep realpart 'single-float)
                       (typep imagpart 'single-float))
                  (truly-the (complex single-float)
                             (complex realpart imagpart)))
                 (t
                  (%make-complex realpart imagpart)))))
  (number-dispatch ((realpart real) (imagpart real))
    ((rational rational)
     (canonical-complex realpart imagpart))
    (float-contagion %%make-complex realpart imagpart (rational)))))

(defun realpart (number)
  #!+sb-doc
  "Extract the real part of a number."
  (etypecase number
    #!+long-float
    ((complex long-float)
     (truly-the long-float (realpart number)))
    ((complex double-float)
     (truly-the double-float (realpart number)))
    ((complex single-float)
     (truly-the single-float (realpart number)))
    ((complex rational)
     (sb!kernel:%realpart number))
    (number
     number)))

(defun imagpart (number)
  #!+sb-doc
  "Extract the imaginary part of a number."
  (etypecase number
    #!+long-float
    ((complex long-float)
     (truly-the long-float (imagpart number)))
    ((complex double-float)
     (truly-the double-float (imagpart number)))
    ((complex single-float)
     (truly-the single-float (imagpart number)))
    ((complex rational)
     (sb!kernel:%imagpart number))
    (float
     (* 0 number))
    (number
     0)))

(defun conjugate (number)
  #!+sb-doc
  "Return the complex conjugate of NUMBER. For non-complex numbers, this is
  an identity."
  (declare (type number number))
  (if (complexp number)
      (complex (realpart number) (- (imagpart number)))
      number))

(defun signum (number)
  #!+sb-doc
  "If NUMBER is zero, return NUMBER, else return (/ NUMBER (ABS NUMBER))."
  (if (zerop number)
      number
      (if (rationalp number)
          (if (plusp number) 1 -1)
          (/ number (abs number)))))

;;;; ratios

(defun numerator (number)
  #!+sb-doc
  "Return the numerator of NUMBER, which must be rational."
  (numerator number))

(defun denominator (number)
  #!+sb-doc
  "Return the denominator of NUMBER, which must be rational."
  (denominator number))

;;;; arithmetic operations

(macrolet ((define-arith (op init doc)
             #!-sb-doc (declare (ignore doc))
             `(defun ,op (&rest args)
                #!+sb-doc ,doc
                (if (null args) ,init
                    (do ((args (cdr args) (cdr args))
                         (result (car args) (,op result (car args))))
                        ((null args) result)
                      ;; to signal TYPE-ERROR when exactly 1 arg of wrong type:
                      (declare (type number result)))))))
  (define-arith + 0
    "Return the sum of its arguments. With no args, returns 0.")
  (define-arith * 1
    "Return the product of its arguments. With no args, returns 1."))

(defun - (number &rest more-numbers)
  #!+sb-doc
  "Subtract the second and all subsequent arguments from the first;
  or with one argument, negate the first argument."
  (if more-numbers
      (do ((nlist more-numbers (cdr nlist))
           (result number))
          ((atom nlist) result)
         (declare (list nlist))
         (setq result (- result (car nlist))))
      (- number)))

(defun / (number &rest more-numbers)
  #!+sb-doc
  "Divide the first argument by each of the following arguments, in turn.
  With one argument, return reciprocal."
  (if more-numbers
      (do ((nlist more-numbers (cdr nlist))
           (result number))
          ((atom nlist) result)
         (declare (list nlist))
         (setq result (/ result (car nlist))))
      (/ number)))

(defun 1+ (number)
  #!+sb-doc
  "Return NUMBER + 1."
  (1+ number))

(defun 1- (number)
  #!+sb-doc
  "Return NUMBER - 1."
  (1- number))

(eval-when (:compile-toplevel)

(sb!xc:defmacro two-arg-+/- (name op big-op)
  `(defun ,name (x y)
     (number-dispatch ((x number) (y number))
       (bignum-cross-fixnum ,op ,big-op)
       (float-contagion ,op x y)

       ((complex complex)
        (canonical-complex (,op (realpart x) (realpart y))
                           (,op (imagpart x) (imagpart y))))
       (((foreach bignum fixnum ratio single-float double-float
                  #!+long-float long-float) complex)
        (complex (,op x (realpart y)) (,op 0 (imagpart y))))
       ((complex (or rational float))
        (complex (,op (realpart x) y) (,op (imagpart x) 0)))

       (((foreach fixnum bignum) ratio)
        (let* ((dy (denominator y))
               (n (,op (* x dy) (numerator y))))
          (%make-ratio n dy)))
       ((ratio integer)
        (let* ((dx (denominator x))
               (n (,op (numerator x) (* y dx))))
          (%make-ratio n dx)))
       ((ratio ratio)
        (let* ((nx (numerator x))
               (dx (denominator x))
               (ny (numerator y))
               (dy (denominator y))
               (g1 (gcd dx dy)))
          (if (eql g1 1)
              (%make-ratio (,op (* nx dy) (* dx ny)) (* dx dy))
              (let* ((t1 (,op (* nx (truncate dy g1)) (* (truncate dx g1) ny)))
                     (g2 (gcd t1 g1))
                     (t2 (truncate dx g1)))
                (cond ((eql t1 0) 0)
                      ((eql g2 1)
                       (%make-ratio t1 (* t2 dy)))
                      (t (let* ((nn (truncate t1 g2))
                                (t3 (truncate dy g2))
                                (nd (if (eql t2 1) t3 (* t2 t3))))
                           (if (eql nd 1) nn (%make-ratio nn nd))))))))))))

) ; EVAL-WHEN

(two-arg-+/- two-arg-+ + add-bignums)
(two-arg-+/- two-arg-- - subtract-bignum)

(defun two-arg-* (x y)
  (flet ((integer*ratio (x y)
           (if (eql x 0) 0
               (let* ((ny (numerator y))
                      (dy (denominator y))
                      (gcd (gcd x dy)))
                 (if (eql gcd 1)
                     (%make-ratio (* x ny) dy)
                     (let ((nn (* (truncate x gcd) ny))
                           (nd (truncate dy gcd)))
                       (if (eql nd 1)
                           nn
                           (%make-ratio nn nd)))))))
         (complex*real (x y)
           (canonical-complex (* (realpart x) y) (* (imagpart x) y))))
    (number-dispatch ((x number) (y number))
      (float-contagion * x y)

      ((fixnum fixnum) (multiply-fixnums x y))
      ((bignum fixnum) (multiply-bignum-and-fixnum x y))
      ((fixnum bignum) (multiply-bignum-and-fixnum y x))
      ((bignum bignum) (multiply-bignums x y))

      ((complex complex)
       (let* ((rx (realpart x))
              (ix (imagpart x))
              (ry (realpart y))
              (iy (imagpart y)))
         (canonical-complex (- (* rx ry) (* ix iy)) (+ (* rx iy) (* ix ry)))))
      (((foreach bignum fixnum ratio single-float double-float
                 #!+long-float long-float)
        complex)
       (complex*real y x))
      ((complex (or rational float))
       (complex*real x y))

      (((foreach bignum fixnum) ratio) (integer*ratio x y))
      ((ratio integer) (integer*ratio y x))
      ((ratio ratio)
       (let* ((nx (numerator x))
              (dx (denominator x))
              (ny (numerator y))
              (dy (denominator y))
              (g1 (gcd nx dy))
              (g2 (gcd dx ny)))
         (build-ratio (* (maybe-truncate nx g1)
                         (maybe-truncate ny g2))
                      (* (maybe-truncate dx g2)
                         (maybe-truncate dy g1))))))))

;;; Divide two integers, producing a canonical rational. If a fixnum,
;;; we see whether they divide evenly before trying the GCD. In the
;;; bignum case, we don't bother, since bignum division is expensive,
;;; and the test is not very likely to succeed.
(defun integer-/-integer (x y)
  (if (and (typep x 'fixnum) (typep y 'fixnum))
      (multiple-value-bind (quo rem) (truncate x y)
        (if (zerop rem)
            quo
            (let ((gcd (gcd x y)))
              (declare (fixnum gcd))
              (if (eql gcd 1)
                  (build-ratio x y)
                  (build-ratio (truncate x gcd) (truncate y gcd))))))
      (let ((gcd (gcd x y)))
        (if (eql gcd 1)
            (build-ratio x y)
            (build-ratio (truncate x gcd) (truncate y gcd))))))

(defun two-arg-/ (x y)
  (number-dispatch ((x number) (y number))
    (float-contagion / x y (ratio integer))

    ((complex complex)
     (let* ((rx (realpart x))
            (ix (imagpart x))
            (ry (realpart y))
            (iy (imagpart y)))
       (if (> (abs ry) (abs iy))
           (let* ((r (/ iy ry))
                  (dn (* ry (+ 1 (* r r)))))
             (canonical-complex (/ (+ rx (* ix r)) dn)
                                (/ (- ix (* rx r)) dn)))
           (let* ((r (/ ry iy))
                  (dn (* iy (+ 1 (* r r)))))
             (canonical-complex (/ (+ (* rx r) ix) dn)
                                (/ (- (* ix r) rx) dn))))))
    (((foreach integer ratio single-float double-float) complex)
     (let* ((ry (realpart y))
            (iy (imagpart y)))
       (if (> (abs ry) (abs iy))
           (let* ((r (/ iy ry))
                  (dn (* ry (+ 1 (* r r)))))
             (canonical-complex (/ x dn)
                                (/ (- (* x r)) dn)))
           (let* ((r (/ ry iy))
                  (dn (* iy (+ 1 (* r r)))))
             (canonical-complex (/ (* x r) dn)
                                (/ (- x) dn))))))
    ((complex (or rational float))
     (canonical-complex (/ (realpart x) y)
                        (/ (imagpart x) y)))

    ((ratio ratio)
     (let* ((nx (numerator x))
            (dx (denominator x))
            (ny (numerator y))
            (dy (denominator y))
            (g1 (gcd nx ny))
            (g2 (gcd dx dy)))
       (build-ratio (* (maybe-truncate nx g1) (maybe-truncate dy g2))
                    (* (maybe-truncate dx g2) (maybe-truncate ny g1)))))

    ((integer integer)
     (integer-/-integer x y))

    ((integer ratio)
     (if (zerop x)
         0
         (let* ((ny (numerator y))
                (dy (denominator y))
                (gcd (gcd x ny)))
           (build-ratio (* (maybe-truncate x gcd) dy)
                        (maybe-truncate ny gcd)))))

    ((ratio integer)
     (let* ((nx (numerator x))
            (gcd (gcd nx y)))
       (build-ratio (maybe-truncate nx gcd)
                    (* (maybe-truncate y gcd) (denominator x)))))))

(defun %negate (n)
  (number-dispatch ((n number))
    (((foreach fixnum single-float double-float #!+long-float long-float))
     (%negate n))
    ((bignum)
     (negate-bignum n))
    ((ratio)
     (%make-ratio (- (numerator n)) (denominator n)))
    ((complex)
     (complex (- (realpart n)) (- (imagpart n))))))

;;;; TRUNCATE and friends

(defun truncate (number &optional (divisor 1))
  #!+sb-doc
  "Return number (or number/divisor) as an integer, rounded toward 0.
  The second returned value is the remainder."
  (macrolet ((truncate-float (rtype)
               `(let* ((float-div (coerce divisor ',rtype))
                       (res (%unary-truncate (/ number float-div))))
                  (values res
                          (- number
                             (* (coerce res ',rtype) float-div))))))
    (number-dispatch ((number real) (divisor real))
      ((fixnum fixnum) (truncate number divisor))
      (((foreach fixnum bignum) ratio)
       (let ((q (truncate (* number (denominator divisor))
                          (numerator divisor))))
         (values q (- number (* q divisor)))))
      ((fixnum bignum)
       (bignum-truncate (make-small-bignum number) divisor))
      ((ratio (or float rational))
       (let ((q (truncate (numerator number)
                          (* (denominator number) divisor))))
         (values q (- number (* q divisor)))))
      ((bignum fixnum)
       (bignum-truncate number (make-small-bignum divisor)))
      ((bignum bignum)
       (bignum-truncate number divisor))

      (((foreach single-float double-float #!+long-float long-float)
        (or rational single-float))
       (if (eql divisor 1)
           (let ((res (%unary-truncate number)))
             (values res (- number (coerce res '(dispatch-type number)))))
           (truncate-float (dispatch-type number))))
      #!+long-float
      ((long-float (or single-float double-float long-float))
       (truncate-float long-float))
      #!+long-float
      (((foreach double-float single-float) long-float)
       (truncate-float long-float))
      ((double-float (or single-float double-float))
       (truncate-float double-float))
      ((single-float double-float)
       (truncate-float double-float))
      (((foreach fixnum bignum ratio)
        (foreach single-float double-float #!+long-float long-float))
       (truncate-float (dispatch-type divisor))))))

;; Only inline when no VOP exists
#!-multiply-high-vops (declaim (inline %multiply-high))
(defun %multiply-high (x y)
  (declare (type word x y))
  #!-multiply-high-vops
  (values (sb!bignum:%multiply x y))
  #!+multiply-high-vops
  (%multiply-high x y))

;;; Declare these guys inline to let them get optimized a little.
;;; ROUND and FROUND are not declared inline since they seem too
;;; obscure and too big to inline-expand by default. Also, this gives
;;; the compiler a chance to pick off the unary float case.
;;;
;;; CEILING and FLOOR are implemented in terms of %CEILING and %FLOOR
;;; if no better transform can be found: they aren't inline directly,
;;; since we want to try a transform specific to them before letting
;;; the transform for TRUNCATE pick up the slack.
#!-sb-fluid (declaim (inline rem mod fceiling ffloor ftruncate %floor %ceiling))
(defun %floor (number divisor)
  ;; If the numbers do not divide exactly and the result of
  ;; (/ NUMBER DIVISOR) would be negative then decrement the quotient
  ;; and augment the remainder by the divisor.
  (multiple-value-bind (tru rem) (truncate number divisor)
    (if (and (not (zerop rem))
             (if (minusp divisor)
                 (plusp number)
                 (minusp number)))
        (values (1- tru) (+ rem divisor))
        (values tru rem))))

(defun floor (number &optional (divisor 1))
  #!+sb-doc
  "Return the greatest integer not greater than number, or number/divisor.
  The second returned value is (mod number divisor)."
  (%floor number divisor))

(defun %ceiling (number divisor)
  ;; If the numbers do not divide exactly and the result of
  ;; (/ NUMBER DIVISOR) would be positive then increment the quotient
  ;; and decrement the remainder by the divisor.
  (multiple-value-bind (tru rem) (truncate number divisor)
    (if (and (not (zerop rem))
             (if (minusp divisor)
                 (minusp number)
                 (plusp number)))
        (values (+ tru 1) (- rem divisor))
        (values tru rem))))

(defun ceiling (number &optional (divisor 1))
  #!+sb-doc
  "Return the smallest integer not less than number, or number/divisor.
  The second returned value is the remainder."
  (%ceiling number divisor))

(defun round (number &optional (divisor 1))
  #!+sb-doc
  "Rounds number (or number/divisor) to nearest integer.
  The second returned value is the remainder."
  (if (eql divisor 1)
      (round number)
      (multiple-value-bind (tru rem) (truncate number divisor)
        (if (zerop rem)
            (values tru rem)
            (let ((thresh (/ (abs divisor) 2)))
              (cond ((or (> rem thresh)
                         (and (= rem thresh) (oddp tru)))
                     (if (minusp divisor)
                         (values (- tru 1) (+ rem divisor))
                         (values (+ tru 1) (- rem divisor))))
                    ((let ((-thresh (- thresh)))
                       (or (< rem -thresh)
                           (and (= rem -thresh) (oddp tru))))
                     (if (minusp divisor)
                         (values (+ tru 1) (- rem divisor))
                         (values (- tru 1) (+ rem divisor))))
                    (t (values tru rem))))))))

(defun rem (number divisor)
  #!+sb-doc
  "Return second result of TRUNCATE."
  (multiple-value-bind (tru rem) (truncate number divisor)
    (declare (ignore tru))
    rem))

(defun mod (number divisor)
  #!+sb-doc
  "Return second result of FLOOR."
  (let ((rem (rem number divisor)))
    (if (and (not (zerop rem))
             (if (minusp divisor)
                 (plusp number)
                 (minusp number)))
        (+ rem divisor)
        rem)))

(defmacro !define-float-rounding-function (name op doc)
  `(defun ,name (number &optional (divisor 1))
    ,doc
    (multiple-value-bind (res rem) (,op number divisor)
      (values (float res (if (floatp rem) rem 1.0)) rem))))

(defun ftruncate (number &optional (divisor 1))
  #!+sb-doc
  "Same as TRUNCATE, but returns first value as a float."
  (macrolet ((ftruncate-float (rtype)
               `(let* ((float-div (coerce divisor ',rtype))
                       (res (%unary-ftruncate (/ number float-div))))
                  (values res
                          (- number
                             (* (coerce res ',rtype) float-div))))))
    (number-dispatch ((number real) (divisor real))
      (((foreach fixnum bignum ratio) (or fixnum bignum ratio))
       (multiple-value-bind (q r)
           (truncate number divisor)
         (values (float q) r)))
      (((foreach single-float double-float #!+long-float long-float)
        (or rational single-float))
       (if (eql divisor 1)
           (let ((res (%unary-ftruncate number)))
             (values res (- number (coerce res '(dispatch-type number)))))
           (ftruncate-float (dispatch-type number))))
      #!+long-float
      ((long-float (or single-float double-float long-float))
       (ftruncate-float long-float))
      #!+long-float
      (((foreach double-float single-float) long-float)
       (ftruncate-float long-float))
      ((double-float (or single-float double-float))
       (ftruncate-float double-float))
      ((single-float double-float)
       (ftruncate-float double-float))
      (((foreach fixnum bignum ratio)
        (foreach single-float double-float #!+long-float long-float))
       (ftruncate-float (dispatch-type divisor))))))

(defun ffloor (number &optional (divisor 1))
  "Same as FLOOR, but returns first value as a float."
  (multiple-value-bind (tru rem) (ftruncate number divisor)
    (if (and (not (zerop rem))
             (if (minusp divisor)
                 (plusp number)
                 (minusp number)))
        (values (1- tru) (+ rem divisor))
        (values tru rem))))

(defun fceiling (number &optional (divisor 1))
  "Same as CEILING, but returns first value as a float."
  (multiple-value-bind (tru rem) (ftruncate number divisor)
    (if (and (not (zerop rem))
             (if (minusp divisor)
                 (minusp number)
                 (plusp number)))
        (values (+ tru 1) (- rem divisor))
        (values tru rem))))

;;; FIXME: this probably needs treatment similar to the use of
;;; %UNARY-FTRUNCATE for FTRUNCATE.
(defun fround (number &optional (divisor 1))
  "Same as ROUND, but returns first value as a float."
  (multiple-value-bind (res rem)
      (round number divisor)
    (values (float res (if (floatp rem) rem 1.0)) rem)))

;;;; comparisons

(defun = (number &rest more-numbers)
  #!+sb-doc
  "Return T if all of its arguments are numerically equal, NIL otherwise."
  (declare (truly-dynamic-extent more-numbers))
  (the number number)
  (do ((nlist more-numbers (cdr nlist)))
      ((atom nlist) t)
     (declare (list nlist))
     (if (not (= (car nlist) number)) (return nil))))

(defun /= (number &rest more-numbers)
  #!+sb-doc
  "Return T if no two of its arguments are numerically equal, NIL otherwise."
  (declare (truly-dynamic-extent more-numbers))
  (do* ((head (the number number) (car nlist))
        (nlist more-numbers (cdr nlist)))
       ((atom nlist) t)
     (declare (list nlist))
     (unless (do* ((nl nlist (cdr nl)))
                  ((atom nl) t)
               (declare (list nl))
               (if (= head (car nl)) (return nil)))
       (return nil))))

(defun < (number &rest more-numbers)
  #!+sb-doc
  "Return T if its arguments are in strictly increasing order, NIL otherwise."
  (declare (truly-dynamic-extent more-numbers))
  (do* ((n (the number number) (car nlist))
        (nlist more-numbers (cdr nlist)))
       ((atom nlist) t)
     (declare (list nlist))
     (if (not (< n (car nlist))) (return nil))))

(defun > (number &rest more-numbers)
  #!+sb-doc
  "Return T if its arguments are in strictly decreasing order, NIL otherwise."
  (declare (truly-dynamic-extent more-numbers))
  (do* ((n (the number number) (car nlist))
        (nlist more-numbers (cdr nlist)))
       ((atom nlist) t)
     (declare (list nlist))
     (if (not (> n (car nlist))) (return nil))))

(defun <= (number &rest more-numbers)
  #!+sb-doc
  "Return T if arguments are in strictly non-decreasing order, NIL otherwise."
  (declare (truly-dynamic-extent more-numbers))
  (do* ((n (the number number) (car nlist))
        (nlist more-numbers (cdr nlist)))
       ((atom nlist) t)
     (declare (list nlist))
     (if (not (<= n (car nlist))) (return nil))))

(defun >= (number &rest more-numbers)
  #!+sb-doc
  "Return T if arguments are in strictly non-increasing order, NIL otherwise."
  (declare (truly-dynamic-extent more-numbers))
  (do* ((n (the number number) (car nlist))
        (nlist more-numbers (cdr nlist)))
       ((atom nlist) t)
     (declare (list nlist))
     (if (not (>= n (car nlist))) (return nil))))

(defun max (number &rest more-numbers)
  #!+sb-doc
  "Return the greatest of its arguments; among EQUALP greatest, return
the first."
  (declare (truly-dynamic-extent more-numbers))
  (do ((nlist more-numbers (cdr nlist))
       (result number))
      ((null nlist) (return result))
     (declare (list nlist))
     (declare (type real number result))
     (if (> (car nlist) result) (setq result (car nlist)))))

(defun min (number &rest more-numbers)
  #!+sb-doc
  "Return the least of its arguments; among EQUALP least, return
the first."
  (declare (truly-dynamic-extent more-numbers))
  (do ((nlist more-numbers (cdr nlist))
       (result number))
      ((null nlist) (return result))
     (declare (list nlist))
     (declare (type real number result))
     (if (< (car nlist) result) (setq result (car nlist)))))

(eval-when (:compile-toplevel :execute)

;;; The INFINITE-X-FINITE-Y and INFINITE-Y-FINITE-X args tell us how
;;; to handle the case when X or Y is a floating-point infinity and
;;; the other arg is a rational. (Section 12.1.4.1 of the ANSI spec
;;; says that comparisons are done by converting the float to a
;;; rational when comparing with a rational, but infinities can't be
;;; converted to a rational, so we show some initiative and do it this
;;; way instead.)
(defun basic-compare (op &key infinite-x-finite-y infinite-y-finite-x)
  `(((fixnum fixnum) (,op x y))

    ((single-float single-float) (,op x y))
    #!+long-float
    (((foreach single-float double-float long-float) long-float)
     (,op (coerce x 'long-float) y))
    #!+long-float
    ((long-float (foreach single-float double-float))
     (,op x (coerce y 'long-float)))
    ((fixnum (foreach single-float double-float))
     (if (float-infinity-p y)
         ,infinite-y-finite-x
         ;; If the fixnum has an exact float representation, do a
         ;; float comparison. Otherwise do the slow float -> ratio
         ;; conversion.
         (multiple-value-bind (lo hi)
             (case '(dispatch-type y)
               (single-float
                (values most-negative-exactly-single-float-fixnum
                        most-positive-exactly-single-float-fixnum))
               (double-float
                (values most-negative-exactly-double-float-fixnum
                        most-positive-exactly-double-float-fixnum)))
           (if (<= lo y hi)
               (,op (coerce x '(dispatch-type y)) y)
               (,op x (rational y))))))
    (((foreach single-float double-float) fixnum)
     (if (eql y 0)
         (,op x (coerce 0 '(dispatch-type x)))
         (if (float-infinity-p x)
             ,infinite-x-finite-y
             ;; Likewise
             (multiple-value-bind (lo hi)
                 (case '(dispatch-type x)
                   (single-float
                    (values most-negative-exactly-single-float-fixnum
                            most-positive-exactly-single-float-fixnum))
                   (double-float
                    (values most-negative-exactly-double-float-fixnum
                            most-positive-exactly-double-float-fixnum)))
               (if (<= lo y hi)
                   (,op x (coerce y '(dispatch-type x)))
                   (,op (rational x) y))))))
    (((foreach single-float double-float) double-float)
     (,op (coerce x 'double-float) y))
    ((double-float single-float)
     (,op x (coerce y 'double-float)))
    (((foreach single-float double-float #!+long-float long-float) rational)
     (if (eql y 0)
         (,op x (coerce 0 '(dispatch-type x)))
         (if (float-infinity-p x)
             ,infinite-x-finite-y
             (,op (rational x) y))))
    (((foreach bignum fixnum ratio) float)
     (if (float-infinity-p y)
         ,infinite-y-finite-x
         (,op x (rational y))))))
) ; EVAL-WHEN

(macrolet ((def-two-arg-</> (name op ratio-arg1 ratio-arg2 &rest cases)
             `(defun ,name (x y)
                (number-dispatch ((x real) (y real))
                                 (basic-compare
                                  ,op
                                  :infinite-x-finite-y
                                  (,op x (coerce 0 '(dispatch-type x)))
                                  :infinite-y-finite-x
                                  (,op (coerce 0 '(dispatch-type y)) y))
                                 (((foreach fixnum bignum) ratio)
                                  (,op x (,ratio-arg2 (numerator y)
                                                      (denominator y))))
                                 ((ratio integer)
                                  (,op (,ratio-arg1 (numerator x)
                                                    (denominator x))
                                       y))
                                 ((ratio ratio)
                                  (,op (* (numerator   (truly-the ratio x))
                                          (denominator (truly-the ratio y)))
                                       (* (numerator   (truly-the ratio y))
                                          (denominator (truly-the ratio x)))))
                                 ,@cases))))
  (def-two-arg-</> two-arg-< < floor ceiling
    ((fixnum bignum)
     (bignum-plus-p y))
    ((bignum fixnum)
     (not (bignum-plus-p x)))
    ((bignum bignum)
     (minusp (bignum-compare x y))))
  (def-two-arg-</> two-arg-> > ceiling floor
    ((fixnum bignum)
     (not (bignum-plus-p y)))
    ((bignum fixnum)
     (bignum-plus-p x))
    ((bignum bignum)
     (plusp (bignum-compare x y)))))

(defun two-arg-= (x y)
  (number-dispatch ((x number) (y number))
    (basic-compare =
                   ;; An infinite value is never equal to a finite value.
                   :infinite-x-finite-y nil
                   :infinite-y-finite-x nil)
    ((fixnum (or bignum ratio)) nil)

    ((bignum (or fixnum ratio)) nil)
    ((bignum bignum)
     (zerop (bignum-compare x y)))

    ((ratio integer) nil)
    ((ratio ratio)
     (and (eql (numerator x) (numerator y))
          (eql (denominator x) (denominator y))))

    ((complex complex)
     (and (= (realpart x) (realpart y))
          (= (imagpart x) (imagpart y))))
    (((foreach fixnum bignum ratio single-float double-float
               #!+long-float long-float) complex)
     (and (= x (realpart y))
          (zerop (imagpart y))))
    ((complex (or float rational))
     (and (= (realpart x) y)
          (zerop (imagpart x))))))

;;;; logicals

(defun logior (&rest integers)
  #!+sb-doc
  "Return the bit-wise or of its arguments. Args must be integers."
  (declare (list integers))
  (if integers
      (do ((result (pop integers) (logior result (pop integers))))
          ((null integers) result)
        (declare (integer result)))
      0))

(defun logxor (&rest integers)
  #!+sb-doc
  "Return the bit-wise exclusive or of its arguments. Args must be integers."
  (declare (list integers))
  (if integers
      (do ((result (pop integers) (logxor result (pop integers))))
          ((null integers) result)
        (declare (integer result)))
      0))

(defun logand (&rest integers)
  #!+sb-doc
  "Return the bit-wise and of its arguments. Args must be integers."
  (declare (list integers))
  (if integers
      (do ((result (pop integers) (logand result (pop integers))))
          ((null integers) result)
        (declare (integer result)))
      -1))

(defun logeqv (&rest integers)
  #!+sb-doc
  "Return the bit-wise equivalence of its arguments. Args must be integers."
  (declare (list integers))
  (if integers
      (do ((result (pop integers) (logeqv result (pop integers))))
          ((null integers) result)
        (declare (integer result)))
      -1))

(defun lognot (number)
  #!+sb-doc
  "Return the bit-wise logical not of integer."
  (etypecase number
    (fixnum (lognot (truly-the fixnum number)))
    (bignum (bignum-logical-not number))))

(macrolet ((def (name op big-op &optional doc)
             `(defun ,name (integer1 integer2)
                ,@(when doc
                    (list doc))
                (let ((x integer1)
                      (y integer2))
                  (number-dispatch ((x integer) (y integer))
                    (bignum-cross-fixnum ,op ,big-op))))))
  (def two-arg-and logand bignum-logical-and)
  (def two-arg-ior logior bignum-logical-ior)
  (def two-arg-xor logxor bignum-logical-xor)
  ;; BIGNUM-LOGICAL-{AND,IOR,XOR} need not return a bignum, so must
  ;; call the generic LOGNOT...
  (def two-arg-eqv logeqv (lambda (x y) (lognot (bignum-logical-xor x y))))
  (def lognand lognand
       (lambda (x y) (lognot (bignum-logical-and x y)))
       #!+sb-doc "Complement the logical AND of INTEGER1 and INTEGER2.")
  (def lognor lognor
       (lambda (x y) (lognot (bignum-logical-ior x y)))
       #!+sb-doc "Complement the logical AND of INTEGER1 and INTEGER2.")
  ;; ... but BIGNUM-LOGICAL-NOT on a bignum will always return a bignum
  (def logandc1 logandc1
       (lambda (x y) (bignum-logical-and (bignum-logical-not x) y))
       #!+sb-doc "Bitwise AND (LOGNOT INTEGER1) with INTEGER2.")
  (def logandc2 logandc2
       (lambda (x y) (bignum-logical-and x (bignum-logical-not y)))
       #!+sb-doc "Bitwise AND INTEGER1 with (LOGNOT INTEGER2).")
  (def logorc1 logorc1
       (lambda (x y) (bignum-logical-ior (bignum-logical-not x) y))
       #!+sb-doc "Bitwise OR (LOGNOT INTEGER1) with INTEGER2.")
  (def logorc2 logorc2
       (lambda (x y) (bignum-logical-ior x (bignum-logical-not y)))
       #!+sb-doc "Bitwise OR INTEGER1 with (LOGNOT INTEGER2)."))

(defun logcount (integer)
  #!+sb-doc
  "Count the number of 1 bits if INTEGER is positive, and the number of 0 bits
  if INTEGER is negative."
  (etypecase integer
    (fixnum
     (logcount (truly-the (integer 0
                                   #.(max sb!xc:most-positive-fixnum
                                          (lognot sb!xc:most-negative-fixnum)))
                          (if (minusp (truly-the fixnum integer))
                              (lognot (truly-the fixnum integer))
                              integer))))
    (bignum
     (bignum-logcount integer))))

(defun logtest (integer1 integer2)
  #!+sb-doc
  "Predicate which returns T if logand of integer1 and integer2 is not zero."
  (logtest integer1 integer2))

(defun logbitp (index integer)
  #!+sb-doc
  "Predicate returns T if bit index of integer is a 1."
  (number-dispatch ((index integer) (integer integer))
    ((fixnum fixnum) (if (> index #.(- sb!vm:n-word-bits sb!vm:n-lowtag-bits))
                         (minusp integer)
                         (not (zerop (logand integer (ash 1 index))))))
    ((fixnum bignum) (bignum-logbitp index integer))
    ((bignum (foreach fixnum bignum)) (minusp integer))))

(defun ash (integer count)
  #!+sb-doc
  "Shifts integer left by count places preserving sign. - count shifts right."
  (declare (integer integer count))
  (etypecase integer
    (fixnum
     (cond ((zerop integer)
            0)
           ((fixnump count)
            (let ((length (integer-length (truly-the fixnum integer)))
                  (count (truly-the fixnum count)))
              (declare (fixnum length count))
              (cond ((and (plusp count)
                          (> (+ length count)
                             (integer-length most-positive-fixnum)))
                     (bignum-ashift-left (make-small-bignum integer) count))
                    (t
                     (truly-the fixnum
                                (ash (truly-the fixnum integer) count))))))
           ((minusp count)
            (if (minusp integer) -1 0))
           (t
            (bignum-ashift-left (make-small-bignum integer) count))))
    (bignum
     (if (plusp count)
         (bignum-ashift-left integer count)
         (bignum-ashift-right integer (- count))))))

(defun integer-length (integer)
  #!+sb-doc
  "Return the number of non-sign bits in the twos-complement representation
  of INTEGER."
  (etypecase integer
    (fixnum
     (integer-length (truly-the fixnum integer)))
    (bignum
     (bignum-integer-length integer))))

;;;; BYTE, bytespecs, and related operations

(defun byte (size position)
  #!+sb-doc
  "Return a byte specifier which may be used by other byte functions
  (e.g. LDB)."
  (byte size position))

(defun byte-size (bytespec)
  #!+sb-doc
  "Return the size part of the byte specifier bytespec."
  (byte-size bytespec))

(defun byte-position (bytespec)
  #!+sb-doc
  "Return the position part of the byte specifier bytespec."
  (byte-position bytespec))

(defun ldb (bytespec integer)
  #!+sb-doc
  "Extract the specified byte from integer, and right justify result."
  (ldb bytespec integer))

(defun ldb-test (bytespec integer)
  #!+sb-doc
  "Return T if any of the specified bits in integer are 1's."
  (ldb-test bytespec integer))

(defun mask-field (bytespec integer)
  #!+sb-doc
  "Extract the specified byte from integer,  but do not right justify result."
  (mask-field bytespec integer))

(defun dpb (newbyte bytespec integer)
  #!+sb-doc
  "Return new integer with newbyte in specified position, newbyte is right justified."
  (dpb newbyte bytespec integer))

(defun deposit-field (newbyte bytespec integer)
  #!+sb-doc
  "Return new integer with newbyte in specified position, newbyte is not right justified."
  (deposit-field newbyte bytespec integer))

(defun %ldb (size posn integer)
  (logand (ash integer (- posn))
          (1- (ash 1 size))))

(defun %mask-field (size posn integer)
  (logand integer (ash (1- (ash 1 size)) posn)))

(defun %dpb (newbyte size posn integer)
  (let ((mask (1- (ash 1 size))))
    (logior (logand integer (lognot (ash mask posn)))
            (ash (logand newbyte mask) posn))))

(defun %deposit-field (newbyte size posn integer)
  (let ((mask (ash (ldb (byte size 0) -1) posn)))
    (logior (logand newbyte mask)
            (logand integer (lognot mask)))))

(defun sb!c::mask-signed-field (size integer)
  #!+sb-doc
  "Extract SIZE lower bits from INTEGER, considering them as a
2-complement SIZE-bits representation of a signed integer."
  (cond ((zerop size)
         0)
        ((logbitp (1- size) integer)
         (dpb integer (byte size 0) -1))
        (t
         (ldb (byte size 0) integer))))


;;;; BOOLE

;;; The boole function dispaches to any logic operation depending on
;;;     the value of a variable. Presently, legal selector values are [0..15].
;;;     boole is open coded for calls with a constant selector. or with calls
;;;     using any of the constants declared below.

(defconstant boole-clr 0
  #!+sb-doc
  "Boole function op, makes BOOLE return 0.")

(defconstant boole-set 1
  #!+sb-doc
  "Boole function op, makes BOOLE return -1.")

(defconstant boole-1   2
  #!+sb-doc
  "Boole function op, makes BOOLE return integer1.")

(defconstant boole-2   3
  #!+sb-doc
  "Boole function op, makes BOOLE return integer2.")

(defconstant boole-c1  4
  #!+sb-doc
  "Boole function op, makes BOOLE return complement of integer1.")

(defconstant boole-c2  5
  #!+sb-doc
  "Boole function op, makes BOOLE return complement of integer2.")

(defconstant boole-and 6
  #!+sb-doc
  "Boole function op, makes BOOLE return logand of integer1 and integer2.")

(defconstant boole-ior 7
  #!+sb-doc
  "Boole function op, makes BOOLE return logior of integer1 and integer2.")

(defconstant boole-xor 8
  #!+sb-doc
  "Boole function op, makes BOOLE return logxor of integer1 and integer2.")

(defconstant boole-eqv 9
  #!+sb-doc
  "Boole function op, makes BOOLE return logeqv of integer1 and integer2.")

(defconstant boole-nand  10
  #!+sb-doc
  "Boole function op, makes BOOLE return log nand of integer1 and integer2.")

(defconstant boole-nor   11
  #!+sb-doc
  "Boole function op, makes BOOLE return lognor of integer1 and integer2.")

(defconstant boole-andc1 12
  #!+sb-doc
  "Boole function op, makes BOOLE return logandc1 of integer1 and integer2.")

(defconstant boole-andc2 13
  #!+sb-doc
  "Boole function op, makes BOOLE return logandc2 of integer1 and integer2.")

(defconstant boole-orc1  14
  #!+sb-doc
  "Boole function op, makes BOOLE return logorc1 of integer1 and integer2.")

(defconstant boole-orc2  15
  #!+sb-doc
  "Boole function op, makes BOOLE return logorc2 of integer1 and integer2.")

(defun boole (op integer1 integer2)
  #!+sb-doc
  "Bit-wise boolean function on two integers. Function chosen by OP:
        0       BOOLE-CLR
        1       BOOLE-SET
        2       BOOLE-1
        3       BOOLE-2
        4       BOOLE-C1
        5       BOOLE-C2
        6       BOOLE-AND
        7       BOOLE-IOR
        8       BOOLE-XOR
        9       BOOLE-EQV
        10      BOOLE-NAND
        11      BOOLE-NOR
        12      BOOLE-ANDC1
        13      BOOLE-ANDC2
        14      BOOLE-ORC1
        15      BOOLE-ORC2"
  (case op
    (0 (boole 0 integer1 integer2))
    (1 (boole 1 integer1 integer2))
    (2 (boole 2 integer1 integer2))
    (3 (boole 3 integer1 integer2))
    (4 (boole 4 integer1 integer2))
    (5 (boole 5 integer1 integer2))
    (6 (boole 6 integer1 integer2))
    (7 (boole 7 integer1 integer2))
    (8 (boole 8 integer1 integer2))
    (9 (boole 9 integer1 integer2))
    (10 (boole 10 integer1 integer2))
    (11 (boole 11 integer1 integer2))
    (12 (boole 12 integer1 integer2))
    (13 (boole 13 integer1 integer2))
    (14 (boole 14 integer1 integer2))
    (15 (boole 15 integer1 integer2))
    (t (error 'type-error :datum op :expected-type '(mod 16)))))

;;;; GCD and LCM

(defun gcd (&rest integers)
  #!+sb-doc
  "Return the greatest common divisor of the arguments, which must be
  integers. Gcd with no arguments is defined to be 0."
  (cond ((null integers) 0)
        ((null (cdr integers)) (abs (the integer (car integers))))
        (t
         (do ((gcd (the integer (car integers))
                   (gcd gcd (the integer (car rest))))
              (rest (cdr integers) (cdr rest)))
             ((null rest) gcd)
           (declare (integer gcd)
                    (list rest))))))

(defun lcm (&rest integers)
  #!+sb-doc
  "Return the least common multiple of one or more integers. LCM of no
  arguments is defined to be 1."
  (cond ((null integers) 1)
        ((null (cdr integers)) (abs (the integer (car integers))))
        (t
         (do ((lcm (the integer (car integers))
                   (lcm lcm (the integer (car rest))))
              (rest (cdr integers) (cdr rest)))
             ((null rest) lcm)
           (declare (integer lcm) (list rest))))))

(defun two-arg-lcm (n m)
  (declare (integer n m))
  (if (or (zerop n) (zerop m))
      0
      ;; KLUDGE: I'm going to assume that it was written this way
      ;; originally for a reason.  However, this is a somewhat
      ;; complicated way of writing the algorithm in the CLHS page for
      ;; LCM, and I don't know why.  To be investigated.  -- CSR,
      ;; 2003-09-11
      ;;
      ;;    It seems to me that this is written this way to avoid
      ;;    unnecessary bignumification of intermediate results.
      ;;        -- TCR, 2008-03-05
      (let ((m (abs m))
            (n (abs n)))
        (multiple-value-bind (max min)
            (if (> m n)
                (values m n)
                (values n m))
          (* (truncate max (gcd n m)) min)))))

;;; Do the GCD of two integer arguments. With fixnum arguments, we use the
;;; binary GCD algorithm from Knuth's seminumerical algorithms (slightly
;;; structurified), otherwise we call BIGNUM-GCD. We pick off the special case
;;; of 0 before the dispatch so that the bignum code doesn't have to worry
;;; about "small bignum" zeros.
(defun two-arg-gcd (u v)
  (cond ((eql u 0) (abs v))
        ((eql v 0) (abs u))
        (t
         (number-dispatch ((u integer) (v integer))
           ((fixnum fixnum)
            (locally
                (declare (optimize (speed 3) (safety 0)))
              (do ((k 0 (1+ k))
                   (u (abs u) (ash u -1))
                   (v (abs v) (ash v -1)))
                  ((oddp (logior u v))
                   (do ((temp (if (oddp u) (- v) (ash u -1))
                              (ash temp -1)))
                       (nil)
                     (declare (fixnum temp))
                     (when (oddp temp)
                       (if (plusp temp)
                           (setq u temp)
                           (setq v (- temp)))
                       (setq temp (- u v))
                       (when (zerop temp)
                         (let ((res (ash u k)))
                           (declare (type sb!vm:signed-word res)
                                    (optimize (inhibit-warnings 3)))
                           (return res))))))
                (declare (type (mod #.sb!vm:n-word-bits) k)
                         (type sb!vm:signed-word u v)))))
           ((bignum bignum)
            (bignum-gcd u v))
           ((bignum fixnum)
            (bignum-gcd u (make-small-bignum v)))
           ((fixnum bignum)
            (bignum-gcd (make-small-bignum u) v))))))

;;;; from Robert Smith
(defun isqrt (n)
  #!+sb-doc
  "Return the root of the nearest integer less than n which is a perfect
   square."
  (declare (type unsigned-byte n))
  (cond
    ((> n 24)
     (let* ((n-fourth-size (ash (1- (integer-length n)) -2))
            (n-significant-half (ash n (- (ash n-fourth-size 1))))
            (n-significant-half-isqrt (isqrt n-significant-half))
            (zeroth-iteration (ash n-significant-half-isqrt n-fourth-size))
            (qr (multiple-value-list (floor n zeroth-iteration)))
            (first-iteration (ash (+ zeroth-iteration (first qr)) -1)))
       (cond ((oddp (first qr))
              first-iteration)
             ((> (expt (- first-iteration zeroth-iteration) 2) (second qr))
              (1- first-iteration))
             (t
              first-iteration))))
    ((> n 15) 4)
    ((> n  8) 3)
    ((> n  3) 2)
    ((> n  0) 1)
    ((= n  0) 0)))

;;;; miscellaneous number predicates

(macrolet ((def (name doc)
             `(defun ,name (number) ,doc (,name number))))
  (def zerop "Is this number zero?")
  (def plusp "Is this real number strictly positive?")
  (def minusp "Is this real number strictly negative?")
  (def oddp "Is this integer odd?")
  (def evenp "Is this integer even?"))

;;;; modular functions
#.
(collect ((forms))
  (flet ((unsigned-definition (name lambda-list width)
           (let ((pattern (1- (ash 1 width))))
             `(defun ,name ,lambda-list
               (flet ((prepare-argument (x)
                        (declare (integer x))
                        (etypecase x
                          ((unsigned-byte ,width) x)
                          (fixnum (logand x ,pattern))
                          (bignum (logand x ,pattern)))))
                 (,name ,@(loop for arg in lambda-list
                                collect `(prepare-argument ,arg)))))))
         (signed-definition (name lambda-list width)
           `(defun ,name ,lambda-list
              (flet ((prepare-argument (x)
                       (declare (integer x))
                       (etypecase x
                         ((signed-byte ,width) x)
                         (fixnum (sb!c::mask-signed-field ,width x))
                         (bignum (sb!c::mask-signed-field ,width x)))))
                (,name ,@(loop for arg in lambda-list
                               collect `(prepare-argument ,arg)))))))
    (flet ((do-mfuns (class)
             (loop for infos being each hash-value of (sb!c::modular-class-funs class)
                   ;; FIXME: We need to process only "toplevel" functions
                   when (listp infos)
                   do (loop for info in infos
                            for name = (sb!c::modular-fun-info-name info)
                            and width = (sb!c::modular-fun-info-width info)
                            and signedp = (sb!c::modular-fun-info-signedp info)
                            and lambda-list = (sb!c::modular-fun-info-lambda-list info)
                            if signedp
                            do (forms (signed-definition name lambda-list width))
                            else
                            do (forms (unsigned-definition name lambda-list width))))))
      (do-mfuns sb!c::*untagged-unsigned-modular-class*)
      (do-mfuns sb!c::*untagged-signed-modular-class*)
      (do-mfuns sb!c::*tagged-modular-class*)))
  `(progn ,@(sort (forms) #'string< :key #'cadr)))

;;; KLUDGE: these out-of-line definitions can't use the modular
;;; arithmetic, as that is only (currently) defined for constant
;;; shifts.  See also the comment in (LOGAND OPTIMIZER) for more
;;; discussion of this hack.  -- CSR, 2003-10-09
#!+#.(cl:if (cl:= sb!vm:n-machine-word-bits 32) '(and) '(or))
(defun sb!vm::ash-left-mod32 (integer amount)
  (etypecase integer
    ((unsigned-byte 32) (ldb (byte 32 0) (ash integer amount)))
    (fixnum (ldb (byte 32 0) (ash (logand integer #xffffffff) amount)))
    (bignum (ldb (byte 32 0) (ash (logand integer #xffffffff) amount)))))
#!+#.(cl:if (cl:= sb!vm:n-machine-word-bits 64) '(and) '(or))
(defun sb!vm::ash-left-mod64 (integer amount)
  (etypecase integer
    ((unsigned-byte 64) (ldb (byte 64 0) (ash integer amount)))
    (fixnum (ldb (byte 64 0) (ash (logand integer #xffffffffffffffff) amount)))
    (bignum (ldb (byte 64 0)
                 (ash (logand integer #xffffffffffffffff) amount)))))

#!+x86
(defun sb!vm::ash-left-smod30 (integer amount)
  (etypecase integer
    ((signed-byte 30) (sb!c::mask-signed-field 30 (ash integer amount)))
    (integer (sb!c::mask-signed-field 30 (ash (sb!c::mask-signed-field 30 integer) amount)))))

#!+x86-64
(defun sb!vm::ash-left-smod61 (integer amount)
  (etypecase integer
    ((signed-byte 61) (sb!c::mask-signed-field 61 (ash integer amount)))
    (integer (sb!c::mask-signed-field 61 (ash (sb!c::mask-signed-field 61 integer) amount)))))
