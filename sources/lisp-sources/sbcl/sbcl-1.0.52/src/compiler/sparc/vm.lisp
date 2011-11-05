;;;; miscellaneous VM definition noise for the Sparc

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; This software is derived from the CMU CL system, which was
;;;; written at Carnegie Mellon University and released into the
;;;; public domain. The software is in the public domain and is
;;;; provided with absolutely no warranty. See the COPYING and CREDITS
;;;; files for more information.

(in-package "SB!VM")

;;;; Additional constants

;;; NUMBER-STACK-DISPLACEMENT
;;;
;;; The number of bytes reserved above the number stack pointer.  These
;;; slots are required by architecture for a place to spill register windows.
;;;
;;; FIXME: Where is this used?
(def!constant number-stack-displacement
  (* 16 n-word-bytes))

;;;; Define the registers

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defvar *register-names* (make-array 32 :initial-element nil)))

(macrolet ((defreg (name offset)
               (let ((offset-sym (symbolicate name "-OFFSET")))
                 `(eval-when (:compile-toplevel :load-toplevel :execute)
                   (def!constant ,offset-sym ,offset)
                   (setf (svref *register-names* ,offset-sym)
                        ,(symbol-name name)))))

           (defregset (name &rest regs)
                `(eval-when (:compile-toplevel :load-toplevel :execute)
                  (defparameter ,name
                    (list ,@(mapcar (lambda (name)
                                      (symbolicate name "-OFFSET"))
                                    regs))))))
  ;; c.f. src/runtime/sparc-lispregs.h

  ;; Globals.  These are difficult to extract from a sigcontext.
  (defreg zero 0)                               ; %g0
  (defreg alloc 1)                              ; %g1
  (defreg null 2)                               ; %g2
  (defreg csp 3)                                ; %g3
  (defreg cfp 4)                                ; %g4
  (defreg bsp 5)                                ; %g5
  ;; %g6 and %g7 are supposed to be reserved for the system.

  ;; Outs.  These get clobbered when we call into C.
  (defreg nl0 8)                                ; %o0
  (defreg nl1 9)                                ; %o1
  (defreg nl2 10)                               ; %o2
  (defreg nl3 11)                               ; %o3
  (defreg nl4 12)                               ; %o4
  (defreg nl5 13)                               ; %o5
  (defreg nsp 14)                               ; %o6
  (defreg nargs 15)                             ; %o7

  ;; Locals.  These are preserved when we call into C.
  (defreg a0 16)                                ; %l0
  (defreg a1 17)                                ; %l1
  (defreg a2 18)                                ; %l2
  (defreg a3 19)                                ; %l3
  (defreg a4 20)                                ; %l4
  (defreg a5 21)                                ; %l5
  (defreg ocfp 22)                              ; %l6
  (defreg lra 23)                               ; %l7

  ;; Ins.  These are preserved just like locals.
  (defreg cname 24)                             ; %i0
  (defreg lexenv 25)                            ; %i1
  (defreg l0 26)                                ; %i2
  (defreg nfp 27)                               ; %i3
  (defreg cfunc 28)                             ; %i4
  (defreg code 29)                              ; %i5
  ;; we can't touch reg 30 if we ever want to return
  (defreg lip 31)                               ; %i7

  (defregset non-descriptor-regs
      nl0 nl1 nl2 nl3 nl4 nl5 cfunc nargs nfp)

  (defregset descriptor-regs
      a0 a1 a2 a3 a4 a5 ocfp lra cname lexenv l0)

  (defregset *register-arg-offsets*
      a0 a1 a2 a3 a4 a5))

;;;; SB and SC definition

(define-storage-base registers :finite :size 32)
(define-storage-base float-registers :finite :size 64)
(define-storage-base control-stack :unbounded :size 8)
(define-storage-base non-descriptor-stack :unbounded :size 0)
(define-storage-base constant :non-packed)
(define-storage-base immediate-constant :non-packed)

;;; handy macro so we don't have to keep changing all the numbers
;;; whenever we insert a new storage class
(defmacro !define-storage-classes (&rest classes)
  (do ((forms (list 'progn)
              (let* ((class (car classes))
                     (sc-name (car class))
                     (constant-name (intern (concatenate 'simple-string
                                                         (string sc-name)
                                                         "-SC-NUMBER"))))
                (list* `(define-storage-class ,sc-name ,index
                          ,@(cdr class))
                       `(def!constant ,constant-name ,index)
                       ;; (The CMU CL version of this macro did
                       ;;   `(EXPORT ',CONSTANT-NAME)
                       ;; here, but in SBCL we try to have package
                       ;; structure described statically in one
                       ;; master source file, instead of building it
                       ;; dynamically by letting all the system code
                       ;; modify it as the system boots.)
                       forms)))
       (index 0 (1+ index))
       (classes classes (cdr classes)))
      ((null classes)
       (nreverse forms))))

;;; see comment in ../x86/vm.lisp.  The value of 7 was taken from
;;; vm:catch-block-size in a cmucl that I happened to have around
;;; and seems to be working so far    -dan
;;;
;;; arbitrarily taken for alpha, too. - Christophe
(def!constant kludge-nondeterministic-catch-block-size 6)

(!define-storage-classes

  ;; non-immediate constants in the constant pool
  (constant constant)

  ;; ZERO and NULL are in registers.
  (zero immediate-constant)
  (null immediate-constant)

  ;; Anything else that can be an immediate.
  (immediate immediate-constant)

  ;;
  ;; the stacks
  ;;

  ;; The control stack.  (Scanned by GC)
  (control-stack control-stack)

  ;; We put ANY-REG and DESCRIPTOR-REG early so that their SC-NUMBER
  ;; is small and therefore the error trap information is smaller.
  ;; Moving them up here from their previous place down below saves
  ;; ~250K in core file size.  --njf, 2006-01-27

  ;; Immediate descriptor objects.  Don't have to be seen by GC, but nothing
  ;; bad will happen if they are.  (fixnums, characters, header values, etc).
  (any-reg
   registers
   :locations #.(append non-descriptor-regs descriptor-regs)
   :constant-scs (zero immediate)
   :save-p t
   :alternate-scs (control-stack))

  ;; Pointer descriptor objects.  Must be seen by GC.
  (descriptor-reg registers
   :locations #.descriptor-regs
   :constant-scs (constant null immediate)
   :save-p t
   :alternate-scs (control-stack))

  ;; The non-descriptor stacks.
  (signed-stack non-descriptor-stack) ; (signed-byte 32)
  (unsigned-stack non-descriptor-stack) ; (unsigned-byte 32)
  (character-stack non-descriptor-stack) ; non-descriptor characters.
  (sap-stack non-descriptor-stack) ; System area pointers.
  (single-stack non-descriptor-stack) ; single-floats
  (double-stack non-descriptor-stack
                :element-size 2 :alignment 2) ; double floats.
  #!+long-float
  (long-stack non-descriptor-stack :element-size 4 :alignment 4) ; long floats.
  ;; complex-single-floats
  (complex-single-stack non-descriptor-stack :element-size 2)
  ;; complex-double-floats.
  (complex-double-stack non-descriptor-stack :element-size 4 :alignment 2)
  #!+long-float
  ;; complex-long-floats.
  (complex-long-stack non-descriptor-stack :element-size 8 :alignment 4)


  ;; **** Things that can go in the integer registers.

  ;; Non-Descriptor characters
  (character-reg registers
   :locations #.non-descriptor-regs
   :constant-scs (immediate)
   :save-p t
   :alternate-scs (character-stack))

  ;; Non-Descriptor SAP's (arbitrary pointers into address space)
  (sap-reg registers
   :locations #.non-descriptor-regs
   :constant-scs (immediate)
   :save-p t
   :alternate-scs (sap-stack))

  ;; Non-Descriptor (signed or unsigned) numbers.
  (signed-reg registers
   :locations #.non-descriptor-regs
   :constant-scs (zero immediate)
   :save-p t
   :alternate-scs (signed-stack))
  (unsigned-reg registers
   :locations #.non-descriptor-regs
   :constant-scs (zero immediate)
   :save-p t
   :alternate-scs (unsigned-stack))

  ;; Random objects that must not be seen by GC.  Used only as temporaries.
  (non-descriptor-reg registers
   :locations #.non-descriptor-regs)

  ;; Pointers to the interior of objects.  Used only as an temporary.
  (interior-reg registers
   :locations (#.lip-offset))


  ;; **** Things that can go in the floating point registers.

  ;; Non-Descriptor single-floats.
  (single-reg float-registers
   :locations #.(loop for i from 0 to 31 collect i)
   :reserve-locations (28 29 30 31)
   :constant-scs ()
   :save-p t
   :alternate-scs (single-stack))

  ;; Non-Descriptor double-floats.
  (double-reg float-registers
   :locations #.(loop for i from 0 to #!-sparc-64 31 #!+sparc-64 63
                      by 2 collect i)
   :element-size 2 :alignment 2
   :reserve-locations (28 30)
   :constant-scs ()
   :save-p t
   :alternate-scs (double-stack))

  ;; Non-Descriptor double-floats.
  #!+long-float
  (long-reg float-registers
   :locations #.(loop for i from 0 to #!-sparc-64 31 #!+sparc-64 63
                      by 4 collect i)
   :element-size 4 :alignment 4
   :reserve-locations (28)
   :constant-scs ()
   :save-p t
   :alternate-scs (long-stack))

  (complex-single-reg float-registers
   :locations #.(loop for i from 0 to 31 by 2 collect i)
   :element-size 2 :alignment 2
   :reserve-locations (28 30)
   :constant-scs ()
   :save-p t
   :alternate-scs (complex-single-stack))

  (complex-double-reg float-registers
   :locations #.(loop for i from 0 to #!-sparc-64 31 #!+sparc-64 63
                      by 4 collect i)
   :element-size 4 :alignment 4
   :reserve-locations (28)
   :constant-scs ()
   :save-p t
   :alternate-scs (complex-double-stack))

  #!+long-float
  (complex-long-reg float-registers
   :locations #.(loop for i from 0 to #!-sparc-64 31 #!+sparc-64 63
                      by 8 collect i)
   :element-size 8 :alignment 8
   :constant-scs ()
   :save-p t
   :alternate-scs (complex-long-stack))


  ;; A catch or unwind block.
  (catch-block control-stack :element-size kludge-nondeterministic-catch-block-size))

;;;; Make some miscellaneous TNs for important registers.
(macrolet ((defregtn (name sc)
               (let ((offset-sym (symbolicate name "-OFFSET"))
                     (tn-sym (symbolicate name "-TN")))
                 `(defparameter ,tn-sym
                   (make-random-tn :kind :normal
                    :sc (sc-or-lose ',sc)
                    :offset ,offset-sym)))))
  (defregtn zero any-reg)
  (defregtn null descriptor-reg)
  (defregtn code descriptor-reg)
  (defregtn alloc any-reg)

  (defregtn nargs any-reg)
  (defregtn bsp any-reg)
  (defregtn csp any-reg)
  (defregtn cfp any-reg)
  (defregtn ocfp any-reg)
  (defregtn nsp any-reg))

;;; If VALUE can be represented as an immediate constant, then return the
;;; appropriate SC number, otherwise return NIL.
(!def-vm-support-routine immediate-constant-sc (value)
  (typecase value
    ((integer 0 0)
     (sc-number-or-lose 'zero))
    (null
     (sc-number-or-lose 'null))
    ((or (integer #.sb!xc:most-negative-fixnum #.sb!xc:most-positive-fixnum)
         character)
     (sc-number-or-lose 'immediate))
    (symbol
     (if (static-symbol-p value)
         (sc-number-or-lose 'immediate)
         nil))))

;;;; function call parameters

;;; the SC numbers for register and stack arguments/return values.
(def!constant register-arg-scn (meta-sc-number-or-lose 'descriptor-reg))
(def!constant immediate-arg-scn (meta-sc-number-or-lose 'any-reg))
(def!constant control-stack-arg-scn (meta-sc-number-or-lose 'control-stack))

(eval-when (:compile-toplevel :load-toplevel :execute)

  ;; offsets of special stack frame locations
  (def!constant ocfp-save-offset 0)
  (def!constant lra-save-offset 1)
  (def!constant nfp-save-offset 2)

  ;; the number of arguments/return values passed in registers.
  (def!constant register-arg-count 6)

  ;; names to use for the argument registers.
  (defparameter register-arg-names '(a0 a1 a2 a3 a4 a5))
) ; EVAL-WHEN


;;; a list of TN's describing the register arguments
(defparameter *register-arg-tns*
  (mapcar (lambda (n)
            (make-random-tn :kind :normal
                              :sc (sc-or-lose 'descriptor-reg)
                              :offset n))
          *register-arg-offsets*))

;;; This is used by the debugger.
(def!constant single-value-return-byte-offset 8)

;;; This function is called by debug output routines that want a
;;; pretty name for a TN's location. It returns a thing that can be
;;; printed with PRINC.
(!def-vm-support-routine location-print-name (tn)
  (declare (type tn tn)) ; FIXME: commented out on alpha
  (let ((sb (sb-name (sc-sb (tn-sc tn))))
        (offset (tn-offset tn)))
    (ecase sb
      (registers (or (svref *register-names* offset)
                     (format nil "R~D" offset)))
      (float-registers (format nil "F~D" offset))
      (control-stack (format nil "CS~D" offset))
      (non-descriptor-stack (format nil "NS~D" offset))
      (constant (format nil "Const~D" offset))
      (immediate-constant "Immed"))))

(!def-vm-support-routine combination-implementation-style (node)
  (declare (type sb!c::combination node) (ignore node))
  (values :default nil))

(defun primitive-type-indirect-cell-type (ptype)
  (declare (ignore ptype))
  nil)
