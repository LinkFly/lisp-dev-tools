;;;; the PPC VM definition of SAP operations

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; This software is derived from the CMU CL system, which was
;;;; written at Carnegie Mellon University and released into the
;;;; public domain. The software is in the public domain and is
;;;; provided with absolutely no warranty. See the COPYING and CREDITS
;;;; files for more information.

(in-package "SB!VM")


;;;; Moves and coercions:

;;; Move a tagged SAP to an untagged representation.
(define-vop (move-to-sap)
  (:args (x :scs (any-reg descriptor-reg)))
  (:results (y :scs (sap-reg)))
  (:note "pointer to SAP coercion")
  (:generator 1
    (loadw y x sap-pointer-slot other-pointer-lowtag)))

(define-move-vop move-to-sap :move
  (descriptor-reg) (sap-reg))


;;; Move an untagged SAP to a tagged representation.
(define-vop (move-from-sap)
  (:args (sap :scs (sap-reg) :to :save))
  (:temporary (:scs (non-descriptor-reg)) ndescr)
  (:temporary (:sc non-descriptor-reg :offset nl3-offset) pa-flag)
  (:results (res :scs (descriptor-reg)))
  (:note "SAP to pointer coercion")
  (:generator 20
    (with-fixed-allocation (res pa-flag ndescr sap-widetag sap-size)
      (storew sap res sap-pointer-slot other-pointer-lowtag))))

(define-move-vop move-from-sap :move
  (sap-reg) (descriptor-reg))

;;; Move untagged sap values.
(define-vop (sap-move)
  (:args (x :target y
            :scs (sap-reg)
            :load-if (not (location= x y))))
  (:results (y :scs (sap-reg)
               :load-if (not (location= x y))))
  (:note "SAP move")
  (:effects)
  (:affected)
  (:generator 0
    (move y x)))

(define-move-vop sap-move :move
  (sap-reg) (sap-reg))


;;; Move untagged sap arguments/return-values.
(define-vop (move-sap-arg)
  (:args (x :target y
            :scs (sap-reg))
         (fp :scs (any-reg)
             :load-if (not (sc-is y sap-reg))))
  (:results (y))
  (:note "SAP argument move")
  (:generator 0
    (sc-case y
      (sap-reg
       (move y x))
      (sap-stack
       (storew x fp (tn-offset y))))))

(define-move-vop move-sap-arg :move-arg
  (descriptor-reg sap-reg) (sap-reg))

;;; Use standard MOVE-ARG + coercion to move an untagged sap to a
;;; descriptor passing location.
(define-move-vop move-arg :move-arg
  (sap-reg) (descriptor-reg))

;;;; SAP-INT and INT-SAP
(define-vop (sap-int)
  (:args (sap :scs (sap-reg) :target int))
  (:arg-types system-area-pointer)
  (:results (int :scs (unsigned-reg)))
  (:result-types unsigned-num)
  (:translate sap-int)
  (:policy :fast-safe)
  (:generator 1
    (move int sap)))

(define-vop (int-sap)
  (:args (int :scs (unsigned-reg) :target sap))
  (:arg-types unsigned-num)
  (:results (sap :scs (sap-reg)))
  (:result-types system-area-pointer)
  (:translate int-sap)
  (:policy :fast-safe)
  (:generator 1
    (move sap int)))

;;;; POINTER+ and POINTER-
(define-vop (pointer+)
  (:translate sap+)
  (:args (ptr :scs (sap-reg))
         (offset :scs (signed-reg)))
  (:arg-types system-area-pointer signed-num)
  (:results (res :scs (sap-reg)))
  (:result-types system-area-pointer)
  (:policy :fast-safe)
  (:generator 2
    (inst add res ptr offset)))

(define-vop (pointer+-c)
  (:translate sap+)
  (:args (ptr :scs (sap-reg)))
  (:info offset)
  (:arg-types system-area-pointer (:constant (signed-byte 16)))
  (:results (res :scs (sap-reg)))
  (:result-types system-area-pointer)
  (:policy :fast-safe)
  (:generator 1
    (inst addi res ptr offset)))

(define-vop (pointer-)
  (:translate sap-)
  (:args (ptr1 :scs (sap-reg))
         (ptr2 :scs (sap-reg)))
  (:arg-types system-area-pointer system-area-pointer)
  (:policy :fast-safe)
  (:results (res :scs (signed-reg)))
  (:result-types signed-num)
  (:generator 1
    (inst sub res ptr1 ptr2)))

;;;; mumble-SYSTEM-REF and mumble-SYSTEM-SET
(macrolet ((def-system-ref-and-set
               (ref-name set-name sc type size &optional signed)
               (let ((ref-name-c (symbolicate ref-name "-C"))
                     (set-name-c (symbolicate set-name "-C")))
                 `(progn
                   (define-vop (,ref-name)
                       (:translate ,ref-name)
                     (:policy :fast-safe)
                     (:args (sap :scs (sap-reg))
                      (offset :scs (signed-reg)))
                     (:arg-types system-area-pointer signed-num)
                     (:results (result :scs (,sc)))
                     (:result-types ,type)
                     (:generator 5
                      (inst ,(ecase size
                                    (:byte 'lbzx)
                                    (:short (if signed 'lhax 'lhzx))
                                    (:long 'lwzx)
                                    (:single 'lfsx)
                                    (:double 'lfdx))
                            result sap offset)
                      ,@(when (and (eq size :byte) signed)
                              '((inst extsb result result)))))
                   (define-vop (,ref-name-c)
                       (:translate ,ref-name)
                     (:policy :fast-safe)
                     (:args (sap :scs (sap-reg)))
                     (:arg-types system-area-pointer (:constant (signed-byte 16)))
                     (:info offset)
                     (:results (result :scs (,sc)))
                     (:result-types ,type)
                     (:generator 4
                      (inst ,(ecase size
                                    (:byte 'lbz)
                                    (:short (if signed 'lha 'lhz))
                                    (:long 'lwz)
                                    (:single 'lfs)
                                    (:double 'lfd))
                            result sap offset)
                      ,@(when (and (eq size :byte) signed)
                              '((inst extsb result result)))))
                   (define-vop (,set-name)
                       (:translate ,set-name)
                     (:policy :fast-safe)
                     (:args (sap :scs (sap-reg))
                      (offset :scs (signed-reg))
                      (value :scs (,sc) :target result))
                     (:arg-types system-area-pointer signed-num ,type)
                     (:results (result :scs (,sc)))
                     (:result-types ,type)
                     (:generator 5
                      (inst ,(ecase size
                                    (:byte 'stbx)
                                    (:short 'sthx)
                                    (:long 'stwx)
                                    (:single 'stfsx)
                                    (:double 'stfdx))
                            value sap offset)
                      (unless (location= result value)
                        ,@(case size
                                (:single
                                 '((inst frsp result value)))
                                (:double
                                 '((inst fmr result value)))
                                (t
                                 '((inst mr result value)))))))
                   (define-vop (,set-name-c)
                       (:translate ,set-name)
                     (:policy :fast-safe)
                     (:args (sap :scs (sap-reg))
                      (value :scs (,sc) :target result))
                     (:arg-types system-area-pointer (:constant (signed-byte 16)) ,type)
                     (:info offset)
                     (:results (result :scs (,sc)))
                     (:result-types ,type)
                     (:generator 4
                      (inst ,(ecase size
                                    (:byte 'stb)
                                    (:short 'sth)
                                    (:long 'stw)
                                    (:single 'stfs)
                                    (:double 'stfd))
                            value sap offset)
                      (unless (location= result value)
                        ,@(case size
                                (:single
                                 '((inst frsp result value)))
                                (:double
                                 '((inst fmr result value)))
                                (t
                                 '((inst mr result value)))))))))))
  (def-system-ref-and-set sap-ref-8 %set-sap-ref-8
    unsigned-reg positive-fixnum :byte nil)
  (def-system-ref-and-set signed-sap-ref-8 %set-signed-sap-ref-8
    signed-reg tagged-num :byte t)
  (def-system-ref-and-set sap-ref-16 %set-sap-ref-16
    unsigned-reg positive-fixnum :short nil)
  (def-system-ref-and-set signed-sap-ref-16 %set-signed-sap-ref-16
    signed-reg tagged-num :short t)
  (def-system-ref-and-set sap-ref-32 %set-sap-ref-32
    unsigned-reg unsigned-num :long nil)
  (def-system-ref-and-set signed-sap-ref-32 %set-signed-sap-ref-32
    signed-reg signed-num :long t)
  (def-system-ref-and-set sap-ref-sap %set-sap-ref-sap
    sap-reg system-area-pointer :long)
  (def-system-ref-and-set sap-ref-single %set-sap-ref-single
    single-reg single-float :single)
  (def-system-ref-and-set sap-ref-double %set-sap-ref-double
    double-reg double-float :double))

;;; Noise to convert normal lisp data objects into SAPs.
(define-vop (vector-sap)
  (:translate vector-sap)
  (:policy :fast-safe)
  (:args (vector :scs (descriptor-reg)))
  (:results (sap :scs (sap-reg)))
  (:result-types system-area-pointer)
  (:generator 2
    (inst addi sap vector
          (- (* vector-data-offset n-word-bytes) other-pointer-lowtag))))
