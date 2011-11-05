;;;; predicate VOPs for the x86 VM

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; This software is derived from the CMU CL system, which was
;;;; written at Carnegie Mellon University and released into the
;;;; public domain. The software is in the public domain and is
;;;; provided with absolutely no warranty. See the COPYING and CREDITS
;;;; files for more information.

(in-package "SB!VM")

;;;; the branch VOP

;;; The unconditional branch, emitted when we can't drop through to the desired
;;; destination. Dest is the continuation we transfer control to.
(define-vop (branch)
  (:info dest)
  (:generator 5
    (inst jmp dest)))


;;;; Generic conditional VOPs

;;; The generic conditional branch, emitted immediately after test
;;; VOPs that only set flags.
;;;
;;; FLAGS is a list of condition descriptors. If the first descriptor
;;; is CL:NOT, the test was true if all the remaining conditions are
;;; false. Otherwise, the test was true if any of the conditions is.
;;;
;;; NOT-P flips the meaning of the test, as with regular :CONDITIONAL
;;; VOP. If NOT-P is true, the code must branch to dest if the test was
;;; false. Otherwise, the code must branch to dest if the test was true.

(define-vop (branch-if)
  (:info dest flags not-p)
  (:generator 0
     (flet ((negate-condition (name)
              (let ((code (logxor 1 (conditional-opcode name))))
                (aref *condition-name-vec* code))))
       (aver (null (rest flags)))
       (inst jmp
             (if not-p
                 (negate-condition (first flags))
                 (first flags))
             dest))))

(defvar *cmov-ptype-representation-vop*
  (mapcan (lambda (entry)
            (destructuring-bind (ptypes &optional sc vop)
                entry
              (unless (listp ptypes)
                (setf ptypes (list ptypes)))
              (mapcar (if (and vop sc)
                          (lambda (ptype)
                            (list ptype sc vop))
                          #'list)
                      ptypes)))
          '((t descriptor-reg move-if/t)

            ((fixnum positive-fixnum)
             any-reg move-if/fx)
            ((unsigned-byte-32 unsigned-byte-31)
             unsigned-reg move-if/unsigned)
            (signed-byte-32 signed-reg move-if/signed)
            ;; FIXME: Can't use CMOV with byte registers, and characters live
            ;; in such outside of unicode builds. A better solution then just
            ;; disabling MOVE-IF/CHAR should be possible, though.
            #!+sb-unicode
            (character character-reg move-if/char)

            ((single-float complex-single-float
              double-float complex-double-float))

            (system-area-pointer sap-reg move-if/sap)))
  "Alist of primitive type -> (storage-class-name VOP-name)
   if values of such a type should be cmoved, and NIL otherwise.

   storage-class-name is the name of the storage class to use for
   the values, and VOP-name the name of the VOP that will be used
   to execute the conditional move.")

(!def-vm-support-routine
    convert-conditional-move-p (node dst-tn x-tn y-tn)
  (declare (ignore node))
  (let* ((ptype (sb!c::tn-primitive-type dst-tn))
         (name  (sb!c::primitive-type-name ptype))
         (param (and (memq :cmov *backend-subfeatures*)
                     (cdr (or (assoc name *cmov-ptype-representation-vop*)
                              '(t descriptor-reg move-if/t))))))
    (when param
      (destructuring-bind (representation vop) param
        (let ((scn (sc-number-or-lose representation)))
          (labels ((make-tn ()
                     (make-representation-tn ptype scn))
                   (frob-tn (tn)
                     (if (immediate-tn-p tn)
                         tn
                         (make-tn))))
            (values vop
                    (frob-tn x-tn) (frob-tn y-tn)
                    (make-tn)
                    nil)))))))

(define-vop (move-if)
  (:args (then) (else))
  (:temporary (:sc unsigned-reg :from :eval) temp)
  (:results (res))
  (:info flags)
  (:generator 0
     (flet ((load-immediate (dst constant-tn
                                 &optional (sc (sc-name (tn-sc dst))))
              (let ((val (tn-value constant-tn)))
                (etypecase val
                  (integer
                     (if (memq sc '(any-reg descriptor-reg))
                         (inst mov dst (fixnumize val))
                         (inst mov dst val)))
                  (symbol
                     (aver (eq sc 'descriptor-reg))
                     (load-symbol dst val))
                  (character
                     (cond ((memq sc '(any-reg descriptor-reg))
                            (inst mov dst
                                  (logior (ash (char-code val) n-widetag-bits)
                                          character-widetag)))
                           (t
                            (aver (eq sc 'character-reg))
                            (inst mov dst (char-code val)))))))))
       (aver (null (rest flags)))
       (if (sc-is else immediate)
           (load-immediate res else)
           (move res else))
       (when (sc-is then immediate)
         (load-immediate temp then (sc-name (tn-sc res)))
         (setf then temp))
       (inst cmov (first flags) res then))))

(macrolet ((def-move-if (name type reg stack)
               `(define-vop (,name move-if)
                  (:args (then :scs (immediate ,reg ,stack) :to :eval
                               :target temp
                               :load-if (not (or (sc-is then immediate)
                                                 (and (sc-is then ,stack)
                                                      (not (location= else res))))))
                         (else :scs (immediate ,reg ,stack) :target res
                               :load-if (not (sc-is else immediate ,stack))))
                  (:arg-types ,type ,type)
                  (:results (res :scs (,reg)
                                 :from (:argument 1)))
                  (:result-types ,type))))
  (def-move-if move-if/t t descriptor-reg control-stack)
  (def-move-if move-if/fx tagged-num any-reg control-stack)
  (def-move-if move-if/unsigned unsigned-num unsigned-reg unsigned-stack)
  (def-move-if move-if/signed signed-num signed-reg signed-stack)
  ;; FIXME: See *CMOV-PTYPE-REPRESENTATION-VOP* above.
  #!+sb-unicode
  (def-move-if move-if/char character character-reg character-stack)
  (def-move-if move-if/sap system-area-pointer sap-reg sap-stack))


;;;; conditional VOPs

;;; Note: a constant-tn is allowed in CMP; it uses an EA displacement,
;;; not immediate data.
(define-vop (if-eq)
  (:args (x :scs (any-reg descriptor-reg control-stack constant)
            :load-if (not (and (sc-is x immediate)
                               (sc-is y any-reg descriptor-reg
                                      control-stack constant))))
         (y :scs (any-reg descriptor-reg immediate)
            :load-if (not (and (sc-is x any-reg descriptor-reg immediate)
                               (sc-is y control-stack constant)))))
  (:conditional :e)
  (:info)
  (:policy :fast-safe)
  (:translate eq)
  (:generator 3
    (let ((x-val (encode-value-if-immediate x))
          (y-val (encode-value-if-immediate y)))
      (cond
        ;; Shorter instruction sequences for these two cases.
        ((and (eql 0 y-val) (sc-is x any-reg descriptor-reg)) (inst test x x))
        ((and (eql 0 x-val) (sc-is y any-reg descriptor-reg)) (inst test y y))

        ;; An encoded value (literal integer) has to be the second argument.
        ((sc-is x immediate) (inst cmp y x-val))

        (t (inst cmp x y-val))))))
