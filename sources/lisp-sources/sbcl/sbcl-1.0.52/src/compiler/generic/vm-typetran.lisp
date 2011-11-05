;;;; This file contains the implementation specific type
;;;; transformation magic. Basically, the various non-standard
;;;; predicates that can be used in TYPEP transformations.

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; This software is derived from the CMU CL system, which was
;;;; written at Carnegie Mellon University and released into the
;;;; public domain. The software is in the public domain and is
;;;; provided with absolutely no warranty. See the COPYING and CREDITS
;;;; files for more information.

(in-package "SB!C")

;;;; internal predicates

;;; These type predicates are used to implement simple cases of TYPEP.
;;; They shouldn't be used explicitly.
(define-type-predicate base-string-p base-string)
(define-type-predicate bignump bignum)
#!+sb-unicode (define-type-predicate character-string-p (vector character))
(define-type-predicate complex-double-float-p (complex double-float))
(define-type-predicate complex-single-float-p (complex single-float))
#!+long-float
(define-type-predicate complex-long-float-p (complex long-float))
;;; (COMPLEX-VECTOR-P isn't here because it's not so much a Lisp-level
;;; type predicate as just a hack to get at the type code so that we
;;; can implement some primitive stuff in Lisp.)
(define-type-predicate double-float-p double-float)
(define-type-predicate fixnump fixnum)
(define-type-predicate long-float-p long-float)
(define-type-predicate ratiop ratio)
(define-type-predicate short-float-p short-float)
(define-type-predicate single-float-p single-float)
(define-type-predicate simple-array-p simple-array)
(define-type-predicate simple-array-nil-p (simple-array nil (*)))
(define-type-predicate simple-array-unsigned-byte-2-p
                       (simple-array (unsigned-byte 2) (*)))
(define-type-predicate simple-array-unsigned-byte-4-p
                       (simple-array (unsigned-byte 4) (*)))
(define-type-predicate simple-array-unsigned-byte-7-p
                       (simple-array (unsigned-byte 7) (*)))
(define-type-predicate simple-array-unsigned-byte-8-p
                       (simple-array (unsigned-byte 8) (*)))
(define-type-predicate simple-array-unsigned-byte-15-p
                       (simple-array (unsigned-byte 15) (*)))
(define-type-predicate simple-array-unsigned-byte-16-p
                       (simple-array (unsigned-byte 16) (*)))
#!+#.(cl:if (cl:= 32 sb!vm:n-word-bits) '(and) '(or))
(define-type-predicate simple-array-unsigned-byte-29-p
                       (simple-array (unsigned-byte 29) (*)))
(define-type-predicate simple-array-unsigned-byte-31-p
                       (simple-array (unsigned-byte 31) (*)))
(define-type-predicate simple-array-unsigned-byte-32-p
                       (simple-array (unsigned-byte 32) (*)))
#!+#.(cl:if (cl:= 64 sb!vm:n-word-bits) '(and) '(or))
(define-type-predicate simple-array-unsigned-byte-60-p
                       (simple-array (unsigned-byte 60) (*)))
#!+#.(cl:if (cl:= 64 sb!vm:n-word-bits) '(and) '(or))
(define-type-predicate simple-array-unsigned-byte-63-p
                       (simple-array (unsigned-byte 63) (*)))
#!+#.(cl:if (cl:= 64 sb!vm:n-word-bits) '(and) '(or))
(define-type-predicate simple-array-unsigned-byte-64-p
                       (simple-array (unsigned-byte 64) (*)))
(define-type-predicate simple-array-signed-byte-8-p
                       (simple-array (signed-byte 8) (*)))
(define-type-predicate simple-array-signed-byte-16-p
                       (simple-array (signed-byte 16) (*)))
#!+#.(cl:if (cl:= 32 sb!vm:n-word-bits) '(and) '(or))
(define-type-predicate simple-array-signed-byte-30-p
                       (simple-array (signed-byte 30) (*)))
(define-type-predicate simple-array-signed-byte-32-p
                       (simple-array (signed-byte 32) (*)))
#!+#.(cl:if (cl:= 64 sb!vm:n-word-bits) '(and) '(or))
(define-type-predicate simple-array-signed-byte-61-p
                       (simple-array (signed-byte 61) (*)))
#!+#.(cl:if (cl:= 64 sb!vm:n-word-bits) '(and) '(or))
(define-type-predicate simple-array-signed-byte-64-p
                       (simple-array (signed-byte 64) (*)))
(define-type-predicate simple-array-single-float-p
                       (simple-array single-float (*)))
(define-type-predicate simple-array-double-float-p
                       (simple-array double-float (*)))
#!+long-float
(define-type-predicate simple-array-long-float-p
                       (simple-array long-float (*)))
(define-type-predicate simple-array-complex-single-float-p
                       (simple-array (complex single-float) (*)))
(define-type-predicate simple-array-complex-double-float-p
                       (simple-array (complex double-float) (*)))
#!+long-float
(define-type-predicate simple-array-complex-long-float-p
                       (simple-array (complex long-float) (*)))
(define-type-predicate simple-base-string-p simple-base-string)
#!+sb-unicode (define-type-predicate simple-character-string-p
                  (simple-array character (*)))
(define-type-predicate system-area-pointer-p system-area-pointer)
#!+#.(cl:if (cl:= 32 sb!vm:n-word-bits) '(and) '(or))
(define-type-predicate unsigned-byte-32-p (unsigned-byte 32))
#!+#.(cl:if (cl:= 32 sb!vm:n-word-bits) '(and) '(or))
(define-type-predicate signed-byte-32-p (signed-byte 32))
#!+#.(cl:if (cl:= 64 sb!vm:n-word-bits) '(and) '(or))
(define-type-predicate unsigned-byte-64-p (unsigned-byte 64))
#!+#.(cl:if (cl:= 64 sb!vm:n-word-bits) '(and) '(or))
(define-type-predicate signed-byte-64-p (signed-byte 64))
(define-type-predicate vector-nil-p (vector nil))
(define-type-predicate weak-pointer-p weak-pointer)
(define-type-predicate code-component-p code-component)
(define-type-predicate lra-p lra)
(define-type-predicate fdefn-p fdefn)
(macrolet
    ((def ()
       `(progn ,@(loop for (name spec) in *vector-without-complex-typecode-infos*
                       collect `(define-type-predicate ,name (vector ,spec))))))
  (def))
;;; Unlike the un-%'ed versions, these are true type predicates,
;;; accepting any type object.
(define-type-predicate %standard-char-p standard-char)
