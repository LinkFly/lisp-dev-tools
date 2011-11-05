;;;; the x86-64 VM definition of operand loading/saving and the MOVE vop

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; This software is derived from the CMU CL system, which was
;;;; written at Carnegie Mellon University and released into the
;;;; public domain. The software is in the public domain and is
;;;; provided with absolutely no warranty. See the COPYING and CREDITS
;;;; files for more information.

(in-package "SB!VM")

(defun make-byte-tn (tn)
  (aver (sc-is tn any-reg descriptor-reg unsigned-reg signed-reg))
  (make-random-tn :kind :normal
                  :sc (sc-or-lose 'byte-reg)
                  :offset (tn-offset tn)))

(defun make-dword-tn (tn)
  (aver (sc-is tn any-reg descriptor-reg character-reg
               unsigned-reg signed-reg))
  (make-random-tn :kind :normal
                  :sc (sc-or-lose 'dword-reg)
                  :offset (tn-offset tn)))

(defun zeroize (tn)
  (let ((offset (tn-offset tn)))
    ;; Using the 32-bit instruction accomplishes the same thing and is
    ;; one byte shorter.
    (if (<= offset edi-offset)
        (let ((tn (make-random-tn :kind :normal
                                  :sc (sc-or-lose 'dword-reg)
                                  :offset offset)))
          (inst xor tn tn))
        (inst xor tn tn))))

(define-move-fun (load-immediate 1) (vop x y)
  ((immediate)
   (any-reg descriptor-reg))
  (let ((val (tn-value x)))
    (etypecase val
      (integer
       (if (zerop val)
           (zeroize y)
         (inst mov y (fixnumize val))))
      (symbol
       (load-symbol y val))
      (character
       (inst mov y (logior (ash (char-code val) n-widetag-bits)
                           character-widetag))))))

(define-move-fun (load-number 1) (vop x y)
  ((immediate) (signed-reg unsigned-reg))
  (let ((val (tn-value x)))
    (if (zerop val)
        (zeroize y)
        (inst mov y val))))

(define-move-fun (load-character 1) (vop x y)
  ((immediate) (character-reg))
  (inst mov y (char-code (tn-value x))))

(define-move-fun (load-system-area-pointer 1) (vop x y)
  ((immediate) (sap-reg))
  (inst mov y (sap-int (tn-value x))))

(define-move-fun (load-constant 5) (vop x y)
  ((constant) (descriptor-reg any-reg))
  (inst mov y x))

(define-move-fun (load-stack 5) (vop x y)
  ((control-stack) (any-reg descriptor-reg)
   (character-stack) (character-reg)
   (sap-stack) (sap-reg)
   (signed-stack) (signed-reg)
   (unsigned-stack) (unsigned-reg))
  (inst mov y x))

(define-move-fun (store-stack 5) (vop x y)
  ((any-reg descriptor-reg) (control-stack)
   (character-reg) (character-stack)
   (sap-reg) (sap-stack)
   (signed-reg) (signed-stack)
   (unsigned-reg) (unsigned-stack))
  (inst mov y x))

;;;; the MOVE VOP
(define-vop (move)
  (:args (x :scs (any-reg descriptor-reg immediate) :target y
            :load-if (not (location= x y))))
  (:results (y :scs (any-reg descriptor-reg)
               :load-if
               (not (or (location= x y)
                        (and (sc-is x any-reg descriptor-reg immediate)
                             (sc-is y control-stack))))))
  (:temporary (:sc unsigned-reg) temp)
  (:effects)
  (:affected)
  (:generator 0
    (if (and (sc-is x immediate)
             (sc-is y any-reg descriptor-reg control-stack))
        (let ((val (tn-value x)))
          (etypecase val
            (integer
             (if (and (zerop val) (sc-is y any-reg descriptor-reg))
                 (zeroize y)
                 (move-immediate y (fixnumize val) temp)))
            (symbol
             (inst mov y (+ nil-value (static-symbol-offset val))))
            (character
             (inst mov y (logior (ash (char-code val) n-widetag-bits)
                                 character-widetag)))))
        (move y x))))

(define-move-vop move :move
  (any-reg descriptor-reg immediate)
  (any-reg descriptor-reg))

;;; Make MOVE the check VOP for T so that type check generation
;;; doesn't think it is a hairy type. This also allows checking of a
;;; few of the values in a continuation to fall out.
(primitive-type-vop move (:check) t)

(defun move-immediate (target val &optional tmp-tn)
  (cond
    ;; If target is a register, we can just mov it there directly
    ((and (tn-p target)
          (sc-is target signed-reg unsigned-reg descriptor-reg any-reg))
     (inst mov target val))
    ;; Likewise if the value is small enough.
    ((typep val '(signed-byte 31))
     (inst mov target val))
    ;; Otherwise go through the temporary register
    (tmp-tn
     (inst mov tmp-tn val)
     (inst mov target tmp-tn))
    (t
     (error "~A is not a register, no temporary given, and immediate ~A too large" target val))))

;;; The MOVE-ARG VOP is used for moving descriptor values into
;;; another frame for argument or known value passing.
;;;
;;; Note: It is not going to be possible to move a constant directly
;;; to another frame, except if the destination is a register and in
;;; this case the loading works out.
(define-vop (move-arg)
  (:args (x :scs (any-reg descriptor-reg immediate) :target y
            :load-if (not (and (sc-is y any-reg descriptor-reg)
                               (sc-is x control-stack))))
         (fp :scs (any-reg)
             :load-if (not (sc-is y any-reg descriptor-reg))))
  (:results (y))
  (:generator 0
    (sc-case y
      ((any-reg descriptor-reg)
       (if (sc-is x immediate)
           (let ((val (tn-value x)))
             (etypecase val
               ((integer 0 0)
                (zeroize y))
               ((or (signed-byte 29) (unsigned-byte 29))
                (inst mov y (fixnumize val)))
               (integer
                (move-immediate y (fixnumize val)))
               (symbol
                (load-symbol y val))
               (character
                (inst mov y (logior (ash (char-code val) n-widetag-bits)
                                    character-widetag)))))
           (move y x)))
      ((control-stack)
       (if (sc-is x immediate)
           (let ((val (tn-value x)))
             (if (= (tn-offset fp) esp-offset)
                 ;; C-call
                 (etypecase val
                   (integer
                    (storew (fixnumize val) fp (tn-offset y)))
                   (symbol
                    (storew (+ nil-value (static-symbol-offset val))
                            fp (tn-offset y)))
                   (character
                    (storew (logior (ash (char-code val) n-widetag-bits)
                                    character-widetag)
                            fp (tn-offset y))))
               ;; Lisp stack
               (etypecase val
                 (integer
                  (storew (fixnumize val) fp (frame-word-offset (tn-offset y))))
                 (symbol
                  (storew (+ nil-value (static-symbol-offset val))
                          fp (frame-word-offset (tn-offset y))))
                 (character
                  (storew (logior (ash (char-code val) n-widetag-bits)
                                  character-widetag)
                          fp (frame-word-offset (tn-offset y)))))))
         (if (= (tn-offset fp) esp-offset)
             ;; C-call
             (storew x fp (tn-offset y))
           ;; Lisp stack
           (storew x fp (frame-word-offset (tn-offset y)))))))))

(define-move-vop move-arg :move-arg
  (any-reg descriptor-reg)
  (any-reg descriptor-reg))

;;;; ILLEGAL-MOVE

;;; This VOP exists just to begin the lifetime of a TN that couldn't
;;; be written legally due to a type error. An error is signalled
;;; before this VOP is so we don't need to do anything (not that there
;;; would be anything sensible to do anyway.)
(define-vop (illegal-move)
  (:args (x) (type))
  (:results (y))
  (:ignore y)
  (:vop-var vop)
  (:save-p :compute-only)
  (:generator 666
    (error-call vop 'object-not-type-error x type)))

;;;; moves and coercions

;;; These MOVE-TO-WORD VOPs move a tagged integer to a raw full-word
;;; representation. Similarly, the MOVE-FROM-WORD VOPs converts a raw
;;; integer to a tagged bignum or fixnum.

;;; Arg is a fixnum, so just shift it. We need a type restriction
;;; because some possible arg SCs (control-stack) overlap with
;;; possible bignum arg SCs.
(define-vop (move-to-word/fixnum)
  (:args (x :scs (any-reg descriptor-reg) :target y
            :load-if (not (location= x y))))
  (:results (y :scs (signed-reg unsigned-reg)
               :load-if (not (location= x y))))
  (:arg-types tagged-num)
  (:note "fixnum untagging")
  (:generator 1
    (move y x)
    (inst sar y n-fixnum-tag-bits)))
(define-move-vop move-to-word/fixnum :move
  (any-reg descriptor-reg) (signed-reg unsigned-reg))

;;; Arg is a non-immediate constant, load it.
(define-vop (move-to-word-c)
  (:args (x :scs (constant)))
  (:results (y :scs (signed-reg unsigned-reg)))
  (:note "constant load")
  (:generator 1
    (cond ((sb!c::tn-leaf x)
           (inst mov y (tn-value x)))
          (t
           (inst mov y x)
           (inst sar y n-fixnum-tag-bits)))))
(define-move-vop move-to-word-c :move
  (constant) (signed-reg unsigned-reg))


;;; Arg is a fixnum or bignum, figure out which and load if necessary.
(define-vop (move-to-word/integer)
  (:args (x :scs (descriptor-reg) :target eax))
  (:results (y :scs (signed-reg unsigned-reg)))
  (:note "integer to untagged word coercion")
  (:temporary (:sc unsigned-reg :offset eax-offset
                   :from (:argument 0) :to (:result 0) :target y) eax)
  (:generator 4
    (move eax x)
    (inst test al-tn fixnum-tag-mask)
    (inst jmp :z FIXNUM)
    (loadw y eax bignum-digits-offset other-pointer-lowtag)
    (inst jmp DONE)
    FIXNUM
    (inst sar eax n-fixnum-tag-bits)
    (move y eax)
    DONE))
(define-move-vop move-to-word/integer :move
  (descriptor-reg) (signed-reg unsigned-reg))


;;; Result is a fixnum, so we can just shift. We need the result type
;;; restriction because of the control-stack ambiguity noted above.
(define-vop (move-from-word/fixnum)
  (:args (x :scs (signed-reg unsigned-reg) :target y
            :load-if (not (location= x y))))
  (:results (y :scs (any-reg descriptor-reg)
               :load-if (not (location= x y))))
  (:result-types tagged-num)
  (:note "fixnum tagging")
  (:generator 1
    (cond ((and (sc-is x signed-reg unsigned-reg)
                (not (location= x y)))
           ;; Uses 7 bytes, but faster on the Pentium
           (inst lea y (make-ea :qword :index x
                                :scale (ash 1 n-fixnum-tag-bits))))
          (t
           ;; Uses: If x is a reg 2 + 3; if x = y uses only 3 bytes
           (move y x)
           (inst shl y n-fixnum-tag-bits)))))
(define-move-vop move-from-word/fixnum :move
  (signed-reg unsigned-reg) (any-reg descriptor-reg))

;;; Convert an untagged signed word to a lispobj -- fixnum or bignum
;;; as the case may be. Fixnum case inline, bignum case in an assembly
;;; routine.
(define-vop (move-from-signed)
  (:args (x :scs (signed-reg unsigned-reg) :to :result))
  (:results (y :scs (any-reg descriptor-reg) :from :argument))
  (:note "signed word to integer coercion")
  ;; Worst case cost to make sure people know they may be number consing.
  (:generator 20
     (aver (not (location= x y)))
     (let ((done (gen-label)))
       (inst imul y x #.(ash 1 n-fixnum-tag-bits))
       (inst jmp :no done)
       (inst mov y x)
       (inst lea temp-reg-tn
             (make-ea :qword :disp
                      (make-fixup (ecase (tn-offset y)
                                    (#.rax-offset 'alloc-signed-bignum-in-rax)
                                    (#.rcx-offset 'alloc-signed-bignum-in-rcx)
                                    (#.rdx-offset 'alloc-signed-bignum-in-rdx)
                                    (#.rbx-offset 'alloc-signed-bignum-in-rbx)
                                    (#.rsi-offset 'alloc-signed-bignum-in-rsi)
                                    (#.rdi-offset 'alloc-signed-bignum-in-rdi)
                                    (#.r8-offset  'alloc-signed-bignum-in-r8)
                                    (#.r9-offset  'alloc-signed-bignum-in-r9)
                                    (#.r10-offset 'alloc-signed-bignum-in-r10)
                                    (#.r12-offset 'alloc-signed-bignum-in-r12)
                                    (#.r13-offset 'alloc-signed-bignum-in-r13)
                                    (#.r14-offset 'alloc-signed-bignum-in-r14)
                                    (#.r15-offset 'alloc-signed-bignum-in-r15))
                                  :assembly-routine)))
       (inst call temp-reg-tn)
       (emit-label done))))
(define-move-vop move-from-signed :move
  (signed-reg) (descriptor-reg))

;;; Convert an untagged unsigned word to a lispobj -- fixnum or bignum
;;; as the case may be. Fixnum case inline, bignum case in an assembly
;;; routine.
(define-vop (move-from-unsigned)
  (:args (x :scs (signed-reg unsigned-reg) :to :result))
  (:results (y :scs (any-reg descriptor-reg) :from :argument))
  (:note "unsigned word to integer coercion")
  ;; Worst case cost to make sure people know they may be number consing.
  (:generator 20
    (aver (not (location= x y)))
    (let ((done (gen-label)))
      (inst mov y #.(ash lowtag-mask n-positive-fixnum-bits))
      ;; The assembly routines test the sign flag from this one, so if
      ;; you change stuff here, make sure the sign flag doesn't get
      ;; overwritten before the CALL!
      (inst test x y)
      ;; Faster but bigger then SHL Y 4. The cost of doing this
      ;; speculatively should be noise compared to bignum consing if
      ;; that is needed and saves one branch.
      (inst lea y (make-ea :qword :index x :scale (ash 1 n-fixnum-tag-bits)))
      (inst jmp :z done)
      (inst mov y x)
      (inst lea temp-reg-tn
            (make-ea :qword :disp
                     (make-fixup (ecase (tn-offset y)
                                   (#.rax-offset 'alloc-unsigned-bignum-in-rax)
                                   (#.rcx-offset 'alloc-unsigned-bignum-in-rcx)
                                   (#.rdx-offset 'alloc-unsigned-bignum-in-rdx)
                                   (#.rbx-offset 'alloc-unsigned-bignum-in-rbx)
                                   (#.rsi-offset 'alloc-unsigned-bignum-in-rsi)
                                   (#.rdi-offset 'alloc-unsigned-bignum-in-rdi)
                                   (#.r8-offset  'alloc-unsigned-bignum-in-r8)
                                   (#.r9-offset  'alloc-unsigned-bignum-in-r9)
                                   (#.r10-offset 'alloc-unsigned-bignum-in-r10)
                                   (#.r12-offset 'alloc-unsigned-bignum-in-r12)
                                   (#.r13-offset 'alloc-unsigned-bignum-in-r13)
                                   (#.r14-offset 'alloc-unsigned-bignum-in-r14)
                                   (#.r15-offset 'alloc-unsigned-bignum-in-r15))
                                 :assembly-routine)))
      (inst call temp-reg-tn)
      (emit-label done))))
(define-move-vop move-from-unsigned :move
  (unsigned-reg) (descriptor-reg))

;;; Move untagged numbers.
(define-vop (word-move)
  (:args (x :scs (signed-reg unsigned-reg) :target y
            :load-if (not (location= x y))))
  (:results (y :scs (signed-reg unsigned-reg)
               :load-if
               (not (or (location= x y)
                        (and (sc-is x signed-reg unsigned-reg)
                             (sc-is y signed-stack unsigned-stack))))))
  (:effects)
  (:affected)
  (:note "word integer move")
  (:generator 0
    (move y x)))
(define-move-vop word-move :move
  (signed-reg unsigned-reg) (signed-reg unsigned-reg))

;;; Move untagged number arguments/return-values.
(define-vop (move-word-arg)
  (:args (x :scs (signed-reg unsigned-reg) :target y)
         (fp :scs (any-reg) :load-if (not (sc-is y sap-reg))))
  (:results (y))
  (:note "word integer argument move")
  (:generator 0
    (sc-case y
      ((signed-reg unsigned-reg)
       (move y x))
      ((signed-stack unsigned-stack)
       (if (= (tn-offset fp) esp-offset)
           (storew x fp (tn-offset y))  ; c-call
           (storew x fp (frame-word-offset (tn-offset y))))))))
(define-move-vop move-word-arg :move-arg
  (descriptor-reg any-reg signed-reg unsigned-reg) (signed-reg unsigned-reg))

;;; Use standard MOVE-ARG and coercion to move an untagged number
;;; to a descriptor passing location.
(define-move-vop move-arg :move-arg
  (signed-reg unsigned-reg) (any-reg descriptor-reg))
