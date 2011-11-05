;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; This software is derived from the CMU CL system, which was
;;;; written at Carnegie Mellon University and released into the
;;;; public domain. The software is in the public domain and is
;;;; provided with absolutely no warranty. See the COPYING and CREDITS
;;;; files for more information.

(in-package "SB!VM")

;;; The :full-call assembly-routines must use the same full-call
;;; unknown-values return convention as a normal call, as some
;;; of the routines will tail-chain to a static-function. The
;;; routines themselves, however, take all of their arguments
;;; in registers (this will typically be one or two arguments,
;;; and is one of the lower bounds on the number of argument-
;;; passing registers), and thus don't need a call frame, which
;;; simplifies things for the normal call/return case. When it
;;; is neccessary for one of the assembly-functions to call a
;;; static-function it will construct the required call frame.
;;; Also, none of the assembly-routines return other than one
;;; value, which again simplifies the return path.
;;;    -- AB, 2006/Feb/05.

(!def-vm-support-routine generate-call-sequence (name style vop)
  (ecase style
    ((:raw :none)
     (values
      `((inst call (make-fixup ',name :assembly-routine)))
      nil))
    (:full-call
     (values
      `((note-this-location ,vop :call-site)
        (inst call (make-fixup ',name :assembly-routine))
        (note-this-location ,vop :single-value-return)
        (cond
          ((member :cmov *backend-subfeatures*)
           (inst cmov :c esp-tn ebx-tn))
          (t
           (let ((single-value (gen-label)))
             (inst jmp :nc single-value)
             (move esp-tn ebx-tn)
             (emit-label single-value)))))
      '((:save-p :compute-only))))))

(!def-vm-support-routine generate-return-sequence (style)
  (ecase style
    (:raw
     `(inst ret))
    (:full-call
     `((inst clc)
       (inst ret)))
    (:none)))
