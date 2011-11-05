;;;; cross-compiler-only versions of conditions

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; This software is derived from the CMU CL system, which was
;;;; written at Carnegie Mellon University and released into the
;;;; public domain. The software is in the public domain and is
;;;; provided with absolutely no warranty. See the COPYING and CREDITS
;;;; files for more information.

(in-package "SB!KERNEL")

(define-condition simple-style-warning (simple-condition style-warning) ())
(define-condition format-too-few-args-warning (simple-warning) ())
;;; in the cross-compiler, this is a full warning.  In the target
;;; compiler, it will only be a style-warning.
(define-condition format-too-many-args-warning (simple-warning) ())

;;; KLUDGE: OAOOM warning: see condition.lisp -- we want a full
;;; definition in the cross-compiler as well, in order to have nice
;;; error messages instead of complaints of undefined-function
;;; ENCAPSULATED-CONDITION.
(define-condition encapsulated-condition (condition)
  ((condition :initarg :condition :reader encapsulated-condition)))

;;; KLUDGE: another OAOOM problem, this time to allow conditions with
;;; REFERENCE-CONDITION in their supercondition list on the host.
;;; (This doesn't feel like the entirely right solution, it has to be
;;; said.)  -- CSR, 2004-09-15
(define-condition reference-condition ()
  ((references :initarg :references :reader reference-condition-references)))

;;; KLUDGE: yet another OAOOM.
;;;
;;; FIXME: This is clearly one OAOOM KLUDGE too many in a row. When tempted
;;; to add another one invent DEF!CONDITION or whatever seems necessary,
;;; and replace these.
(define-condition type-warning (reference-condition simple-warning)
  ()
  (:default-initargs :references (list '(:sbcl :node "Handling of Types"))))
(define-condition type-style-warning (reference-condition simple-style-warning)
  ()
  (:default-initargs :references (list '(:sbcl :node "Handling of Types"))))

(define-condition bug (simple-error)
  ()
  (:report
   (lambda (condition stream)
     (format stream
             "~@<  ~? ~:@_~?~:>"
             (simple-condition-format-control condition)
             (simple-condition-format-arguments condition)
             "~@<If you see this and are an SBCL ~
developer, then it is probable that you have made a change to the ~
system that has broken the ability for SBCL to compile, usually by ~
removing an assumed invariant of the system, but sometimes by making ~
an averrance that is violated (check your code!). If you are a user, ~
please submit a bug report to the developers' mailing list, details of ~
which can be found at <http://sbcl.sourceforge.net/>.~:@>"
             ()))))

;;; These are should never be instantiated before the real definitions
;;; come in.
(deftype package-lock-violation () nil)
(deftype package-locked-error () nil)
(deftype symbol-package-locked-error () nil)
