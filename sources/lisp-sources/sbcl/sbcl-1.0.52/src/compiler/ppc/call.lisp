;;;; the VM definition of function call for the PPC

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; This software is derived from the CMU CL system, which was
;;;; written at Carnegie Mellon University and released into the
;;;; public domain. The software is in the public domain and is
;;;; provided with absolutely no warranty. See the COPYING and CREDITS
;;;; files for more information.

(in-package "SB!VM")

;;;; Interfaces to IR2 conversion:

;;; Return a wired TN describing the N'th full call argument passing
;;; location.
(!def-vm-support-routine standard-arg-location (n)
  (declare (type unsigned-byte n))
  (if (< n register-arg-count)
      (make-wired-tn *backend-t-primitive-type* register-arg-scn
                     (elt *register-arg-offsets* n))
      (make-wired-tn *backend-t-primitive-type* control-stack-arg-scn n)))


;;; Make a passing location TN for a local call return PC.  If
;;; standard is true, then use the standard (full call) location,
;;; otherwise use any legal location.  Even in the non-standard case,
;;; this may be restricted by a desire to use a subroutine call
;;; instruction.
(!def-vm-support-routine make-return-pc-passing-location (standard)
  (if standard
      (make-wired-tn *backend-t-primitive-type* register-arg-scn lra-offset)
      (make-restricted-tn *backend-t-primitive-type* register-arg-scn)))

;;; This is similar to MAKE-RETURN-PC-PASSING-LOCATION, but makes a
;;; location to pass OLD-FP in. This is (obviously) wired in the
;;; standard convention, but is totally unrestricted in non-standard
;;; conventions, since we can always fetch it off of the stack using
;;; the arg pointer.
(!def-vm-support-routine make-old-fp-passing-location (standard)
  (if standard
      (make-wired-tn *fixnum-primitive-type* immediate-arg-scn ocfp-offset)
      (make-normal-tn *fixnum-primitive-type*)))

;;; Make the TNs used to hold OLD-FP and RETURN-PC within the current
;;; function. We treat these specially so that the debugger can find
;;; them at a known location.
(!def-vm-support-routine make-old-fp-save-location (env)
  (specify-save-tn
   (physenv-debug-live-tn (make-normal-tn *fixnum-primitive-type*) env)
   (make-wired-tn *fixnum-primitive-type*
                  control-stack-arg-scn
                  ocfp-save-offset)))
(!def-vm-support-routine make-return-pc-save-location (env)
  (specify-save-tn
   (physenv-debug-live-tn (make-normal-tn *backend-t-primitive-type*) env)
   (make-wired-tn *backend-t-primitive-type*
                  control-stack-arg-scn
                  lra-save-offset)))

;;; Make a TN for the standard argument count passing location.  We
;;; only need to make the standard location, since a count is never
;;; passed when we are using non-standard conventions.
(!def-vm-support-routine make-arg-count-location ()
  (make-wired-tn *fixnum-primitive-type* immediate-arg-scn nargs-offset))


;;; Make a TN to hold the number-stack frame pointer.  This is
;;; allocated once per component, and is component-live.
(!def-vm-support-routine make-nfp-tn ()
  (component-live-tn
   (make-wired-tn *fixnum-primitive-type* immediate-arg-scn nfp-offset)))

(!def-vm-support-routine make-stack-pointer-tn ()
  (make-normal-tn *fixnum-primitive-type*))

(!def-vm-support-routine make-number-stack-pointer-tn ()
  (make-normal-tn *fixnum-primitive-type*))

;;; Return a list of TNs that can be used to represent an unknown-values
;;; continuation within a function.
(!def-vm-support-routine make-unknown-values-locations ()
  (list (make-stack-pointer-tn)
        (make-normal-tn *fixnum-primitive-type*)))

;;; This function is called by the ENTRY-ANALYZE phase, allowing
;;; VM-dependent initialization of the IR2-COMPONENT structure.  We push
;;; placeholder entries in the Constants to leave room for additional
;;; noise in the code object header.
(!def-vm-support-routine select-component-format (component)
  (declare (type component component))
  (dotimes (i code-constants-offset)
    (vector-push-extend nil
                        (ir2-component-constants (component-info component))))
  (values))

;;;; Frame hackery:

;;; this is the first function in this file that differs materially from
;;; ../alpha/call.lisp
(defun bytes-needed-for-non-descriptor-stack-frame ()
  (logandc2 (+ +stack-alignment-bytes+ number-stack-displacement
               (* (sb-allocated-size 'non-descriptor-stack) n-word-bytes))
            +stack-alignment-bytes+))


;;; Used for setting up the Old-FP in local call.
(define-vop (current-fp)
  (:results (val :scs (any-reg)))
  (:generator 1
    (move val cfp-tn)))

;;; Used for computing the caller's NFP for use in known-values return.  Only
;;; works assuming there is no variable size stuff on the nstack.
(define-vop (compute-old-nfp)
  (:results (val :scs (any-reg)))
  (:vop-var vop)
  (:generator 1
    (let ((nfp (current-nfp-tn vop)))
      (when nfp
        (inst addi val nfp (bytes-needed-for-non-descriptor-stack-frame))))))

;;; Accessing a slot from an earlier stack frame is definite hackery.
(define-vop (ancestor-frame-ref)
  (:args (frame-pointer :scs (descriptor-reg))
         (variable-home-tn :load-if nil))
  (:results (value :scs (descriptor-reg any-reg)))
  (:policy :fast-safe)
  (:generator 4
    (aver (sc-is variable-home-tn control-stack))
    (loadw value frame-pointer (tn-offset variable-home-tn))))
(define-vop (ancestor-frame-set)
  (:args (frame-pointer :scs (descriptor-reg))
         (value :scs (descriptor-reg any-reg)))
  (:results (variable-home-tn :load-if nil))
  (:policy :fast-safe)
  (:generator 4
    (aver (sc-is variable-home-tn control-stack))
    (storew value frame-pointer (tn-offset variable-home-tn))))

(define-vop (xep-allocate-frame)
  (:info start-lab copy-more-arg-follows)
  (:ignore copy-more-arg-follows)
  (:vop-var vop)
  (:temporary (:scs (non-descriptor-reg)) temp)
  (:generator 1
    ;; Make sure the function is aligned, and drop a label pointing to this
    ;; function header.
    (emit-alignment n-lowtag-bits)
    (trace-table-entry trace-table-fun-prologue)
    (emit-label start-lab)
    ;; Allocate function header.
    (inst simple-fun-header-word)
    (dotimes (i (1- simple-fun-code-offset))
      (inst word 0))
    (let* ((entry-point (gen-label)))
      (emit-label entry-point)
      (inst compute-code-from-lip code-tn lip-tn entry-point temp))
      ;; FIXME alpha port has a ### note here saying we should "save it
      ;; on the stack" so that GC sees it. No idea what "it" is -dan 20020110
    ;; Build our stack frames.
    (inst addi csp-tn cfp-tn
          (* n-word-bytes (sb-allocated-size 'control-stack)))
    (let ((nfp-tn (current-nfp-tn vop)))
      (when nfp-tn
        (let* ((nbytes (bytes-needed-for-non-descriptor-stack-frame)))
          (when (> nbytes number-stack-displacement)
            (inst stwu nsp-tn nsp-tn (- nbytes))
            (inst addi nfp-tn nsp-tn number-stack-displacement)))))
    (trace-table-entry trace-table-normal)))

(define-vop (allocate-frame)
  (:results (res :scs (any-reg))
            (nfp :scs (any-reg)))
  (:info callee)
  (:generator 2
    (trace-table-entry trace-table-fun-prologue)
    (move res csp-tn)
    (inst addi csp-tn csp-tn
          (* n-word-bytes (sb-allocated-size 'control-stack)))
    (when (ir2-physenv-number-stack-p callee)
      (let* ((nbytes (bytes-needed-for-non-descriptor-stack-frame)))
        (when (> nbytes number-stack-displacement)
          (inst stwu nsp-tn nsp-tn (- (bytes-needed-for-non-descriptor-stack-frame)))
          (inst addi nfp nsp-tn number-stack-displacement))))
    (trace-table-entry trace-table-normal)))

;;; Allocate a partial frame for passing stack arguments in a full call.  Nargs
;;; is the number of arguments passed.  If no stack arguments are passed, then
;;; we don't have to do anything.
(define-vop (allocate-full-call-frame)
  (:info nargs)
  (:results (res :scs (any-reg)))
  (:generator 2
    (when (> nargs register-arg-count)
      (move res csp-tn)
      (inst addi csp-tn csp-tn (* nargs n-word-bytes)))))

;;; Emit code needed at the return-point from an unknown-values call
;;; for a fixed number of values.  Values is the head of the TN-REF
;;; list for the locations that the values are to be received into.
;;; Nvals is the number of values that are to be received (should
;;; equal the length of Values).
;;;
;;; MOVE-TEMP is a DESCRIPTOR-REG TN used as a temporary.
;;;
;;; This code exploits the fact that in the unknown-values convention,
;;; a single value return returns at the return PC + 8, whereas a
;;; return of other than one value returns directly at the return PC.
;;;
;;; If 0 or 1 values are expected, then we just emit an instruction to
;;; reset the SP (which will only be executed when other than 1 value
;;; is returned.)
;;;
;;; In the general case, we have to do three things:
;;;  -- Default unsupplied register values.  This need only be done when a
;;;     single value is returned, since register values are defaulted by the
;;;     callee in the non-single case.
;;;  -- Default unsupplied stack values.  This needs to be done whenever there
;;;     are stack values.
;;;  -- Reset SP.  This must be done whenever other than 1 value is returned,
;;;     regardless of the number of values desired.
;;;
;;; The general-case code looks like this:
#|
        b regs-defaulted                ; Skip if MVs
        nop

        move a1 null-tn                 ; Default register values
        ...
        loadi nargs 1                   ; Force defaulting of stack values
        move old-fp csp                 ; Set up args for SP resetting

regs-defaulted
        subcc temp nargs register-arg-count

        b :lt default-value-7   ; jump to default code
        loadw move-temp ocfp-tn 6       ; Move value to correct location.
        subcc temp 1
        store-stack-tn val4-tn move-temp

        b :lt default-value-8
        loadw move-temp ocfp-tn 7
        subcc temp 1
        store-stack-tn val5-tn move-temp

        ...

defaulting-done
        move csp ocfp                   ; Reset SP.
<end of code>

<elsewhere>
default-value-7
        store-stack-tn val4-tn null-tn  ; Nil out 7'th value. (first on stack)

default-value-8
        store-stack-tn val5-tn null-tn  ; Nil out 8'th value.

        ...

        br defaulting-done
        nop
|#
;;; differences from alpha: (1) alpha tests for lra-label before
;;; compute-code-from-lra and skips if nil. (2) loop termination is
;;; different when clearing stack defaults

(defun default-unknown-values (vop values nvals move-temp temp lra-label)
  (declare (type (or tn-ref null) values)
           (type unsigned-byte nvals) (type tn move-temp temp))
  (if (<= nvals 1)
      (progn
        (sb!assem:without-scheduling ()
          (note-this-location vop :single-value-return)
          (move csp-tn ocfp-tn)
          (inst nop))
        (inst compute-code-from-lra code-tn lra-tn lra-label temp))
      (let ((regs-defaulted (gen-label))
            (defaulting-done (gen-label))
            (default-stack-vals (gen-label)))
        ;; Branch off to the MV case.
        (sb!assem:without-scheduling ()
          (note-this-location vop :unknown-return)
          (if (> nvals register-arg-count)
              (inst addic. temp nargs-tn (- (fixnumize register-arg-count)))
              (move csp-tn ocfp-tn))
          (inst b regs-defaulted))

        ;; Do the single value case.
        (do ((i 1 (1+ i))
             (val (tn-ref-across values) (tn-ref-across val)))
            ((= i (min nvals register-arg-count)))
          (move (tn-ref-tn val) null-tn))
        (when (> nvals register-arg-count)
          (move ocfp-tn csp-tn)
          (inst b default-stack-vals))

        (emit-label regs-defaulted)
        (when (> nvals register-arg-count)
          (collect ((defaults))
            (do ((i register-arg-count (1+ i))
                 (val (do ((i 0 (1+ i))
                           (val values (tn-ref-across val)))
                          ((= i register-arg-count) val))
                      (tn-ref-across val)))
                ((null val))

              (let ((default-lab (gen-label))
                    (tn (tn-ref-tn val)))
                (defaults (cons default-lab tn))

                (inst lwz move-temp ocfp-tn (* i n-word-bytes))
                (inst ble default-lab)
                (inst addic. temp temp (- (fixnumize 1)))
                (store-stack-tn tn move-temp)))

            (emit-label defaulting-done)
            (move csp-tn ocfp-tn)

            (let ((defaults (defaults)))
              (when defaults
                (assemble (*elsewhere*)
                  (emit-label default-stack-vals)
                  (trace-table-entry trace-table-fun-prologue)
                  (do ((remaining defaults (cdr remaining)))
                      ((null remaining))
                    (let ((def (car remaining)))
                      (emit-label (car def))
                      (store-stack-tn (cdr def) null-tn)))
                  (inst b defaulting-done)
                  (trace-table-entry trace-table-normal))))))

        (inst compute-code-from-lra code-tn lra-tn lra-label temp)))
  (values))


;;;; Unknown values receiving:

;;;    Emit code needed at the return point for an unknown-values call for an
;;; arbitrary number of values.
;;;
;;;    We do the single and non-single cases with no shared code: there doesn't
;;; seem to be any potential overlap, and receiving a single value is more
;;; important efficiency-wise.
;;;
;;;    When there is a single value, we just push it on the stack, returning
;;; the old SP and 1.
;;;
;;;    When there is a variable number of values, we move all of the argument
;;; registers onto the stack, and return Args and Nargs.
;;;
;;;    Args and Nargs are TNs wired to the named locations.  We must
;;; explicitly allocate these TNs, since their lifetimes overlap with the
;;; results Start and Count (also, it's nice to be able to target them).
(defun receive-unknown-values (args nargs start count lra-label temp)
  (declare (type tn args nargs start count temp))
  (let ((variable-values (gen-label))
        (done (gen-label)))
    (sb!assem:without-scheduling ()
      (inst b variable-values)
      (inst nop))

    (inst compute-code-from-lra code-tn lra-tn lra-label temp)
    (inst addi csp-tn csp-tn 4)
    (storew (first *register-arg-tns*) csp-tn -1)
    (inst subi start csp-tn 4)
    (inst li count (fixnumize 1))

    (emit-label done)

    (assemble (*elsewhere*)
      (trace-table-entry trace-table-fun-prologue)
      (emit-label variable-values)
      (inst compute-code-from-lra code-tn lra-tn lra-label temp)
      (do ((arg *register-arg-tns* (rest arg))
           (i 0 (1+ i)))
          ((null arg))
        (storew (first arg) args i))
      (move start args)
      (move count nargs)
      (inst b done)
      (trace-table-entry trace-table-normal)))
  (values))


;;; VOP that can be inherited by unknown values receivers.  The main
;;; thing this handles is allocation of the result temporaries.
(define-vop (unknown-values-receiver)
  (:results
   (start :scs (any-reg))
   (count :scs (any-reg)))
  (:temporary (:sc descriptor-reg :offset ocfp-offset
                   :from :eval :to (:result 0))
              values-start)
  (:temporary (:sc any-reg :offset nargs-offset
               :from :eval :to (:result 1))
              nvals)
  (:temporary (:scs (non-descriptor-reg)) temp))


;;; This hook in the codegen pass lets us insert code before fall-thru entry
;;; points, local-call entry points, and tail-call entry points.  The default
;;; does nothing.
(defun emit-block-header (start-label trampoline-label fall-thru-p alignp)
  (declare (ignore fall-thru-p alignp))
  (when trampoline-label
    (emit-label trampoline-label))
  (emit-label start-label))


;;;; Local call with unknown values convention return:

;;; Non-TR local call for a fixed number of values passed according to the
;;; unknown values convention.
;;;
;;; Args are the argument passing locations, which are specified only to
;;; terminate their lifetimes in the caller.
;;;
;;; Values are the return value locations (wired to the standard passing
;;; locations).
;;;
;;; Save is the save info, which we can ignore since saving has been done.
;;; Return-PC is the TN that the return PC should be passed in.
;;; Target is a continuation pointing to the start of the called function.
;;; Nvals is the number of values received.
;;;
;;; Note: we can't use normal load-tn allocation for the fixed args, since all
;;; registers may be tied up by the more operand.  Instead, we use
;;; MAYBE-LOAD-STACK-TN.
(define-vop (call-local)
  (:args (fp)
         (nfp)
         (args :more t))
  (:results (values :more t))
  (:save-p t)
  (:move-args :local-call)
  (:info arg-locs callee target nvals)
  (:vop-var vop)
  (:temporary (:scs (descriptor-reg) :from (:eval 0)) move-temp)
  (:temporary (:scs (non-descriptor-reg)) temp)
  (:temporary (:sc control-stack :offset nfp-save-offset) nfp-save)
  (:temporary (:sc any-reg :offset ocfp-offset :from (:eval 0)) ocfp)
  (:ignore arg-locs args ocfp)
  (:generator 5
    (trace-table-entry trace-table-call-site)
    (let ((label (gen-label))
          (cur-nfp (current-nfp-tn vop)))
      (when cur-nfp
        (store-stack-tn nfp-save cur-nfp))
      (let ((callee-nfp (callee-nfp-tn callee)))
        (when callee-nfp
          (maybe-load-stack-tn callee-nfp nfp)))
      (maybe-load-stack-tn cfp-tn fp)
      (inst compute-lra-from-code
            (callee-return-pc-tn callee) code-tn label temp)
      (note-this-location vop :call-site)
      (inst b target)
      (emit-return-pc label)
      (default-unknown-values vop values nvals move-temp temp label)
      ;; alpha uses (maybe-load-stack-nfp-tn cur-nfp nfp-save temp)
      ;; instead of the clause below
      (when cur-nfp
        (load-stack-tn cur-nfp nfp-save)))
    (trace-table-entry trace-table-normal)))


;;; Non-TR local call for a variable number of return values passed according
;;; to the unknown values convention.  The results are the start of the values
;;; glob and the number of values received.
;;;
;;; Note: we can't use normal load-tn allocation for the fixed args, since all
;;; registers may be tied up by the more operand.  Instead, we use
;;; MAYBE-LOAD-STACK-TN.
(define-vop (multiple-call-local unknown-values-receiver)
  (:args (fp)
         (nfp)
         (args :more t))
  (:save-p t)
  (:move-args :local-call)
  (:info save callee target)
  (:ignore args save)
  (:vop-var vop)
  (:temporary (:sc control-stack :offset nfp-save-offset) nfp-save)
  (:temporary (:scs (non-descriptor-reg)) temp)
  (:generator 20
    (trace-table-entry trace-table-call-site)
    (let ((label (gen-label))
          (cur-nfp (current-nfp-tn vop)))
      (when cur-nfp
        (store-stack-tn nfp-save cur-nfp))
      (let ((callee-nfp (callee-nfp-tn callee)))
        ;; alpha doesn't test this before the maybe-load
        (when callee-nfp
          (maybe-load-stack-tn callee-nfp nfp)))
      (maybe-load-stack-tn cfp-tn fp)
      (inst compute-lra-from-code
            (callee-return-pc-tn callee) code-tn label temp)
      (note-this-location vop :call-site)
      (inst b target)
      (emit-return-pc label)
      (note-this-location vop :unknown-return)
      (receive-unknown-values values-start nvals start count label temp)
      (when cur-nfp
        (load-stack-tn cur-nfp nfp-save)))
    (trace-table-entry trace-table-normal)))


;;;; Local call with known values return:

;;; Non-TR local call with known return locations.  Known-value return works
;;; just like argument passing in local call.
;;;
;;; Note: we can't use normal load-tn allocation for the fixed args, since all
;;; registers may be tied up by the more operand.  Instead, we use
;;; MAYBE-LOAD-STACK-TN.
(define-vop (known-call-local)
  (:args (fp)
         (nfp)
         (args :more t))
  (:results (res :more t))
  (:move-args :local-call)
  (:save-p t)
  (:info save callee target)
  (:ignore args res save)
  (:vop-var vop)
  (:temporary (:sc control-stack :offset nfp-save-offset) nfp-save)
  (:temporary (:scs (non-descriptor-reg)) temp)
  (:generator 5
    (trace-table-entry trace-table-call-site)
    (let ((label (gen-label))
          (cur-nfp (current-nfp-tn vop)))
      (when cur-nfp
        (store-stack-tn nfp-save cur-nfp))
      (let ((callee-nfp (callee-nfp-tn callee)))
        (when callee-nfp
          (maybe-load-stack-tn callee-nfp nfp)))
      (maybe-load-stack-tn cfp-tn fp)
      (inst compute-lra-from-code
            (callee-return-pc-tn callee) code-tn label temp)
      (note-this-location vop :call-site)
      (inst b target)
      (emit-return-pc label)
      (note-this-location vop :known-return)
      (when cur-nfp
        (load-stack-tn cur-nfp nfp-save)))
    (trace-table-entry trace-table-normal)))

;;; Return from known values call.  We receive the return locations as
;;; arguments to terminate their lifetimes in the returning function.  We
;;; restore FP and CSP and jump to the Return-PC.
;;;
;;; Note: we can't use normal load-tn allocation for the fixed args, since all
;;; registers may be tied up by the more operand.  Instead, we use
;;; MAYBE-LOAD-STACK-TN.
(define-vop (known-return)
  (:args (old-fp :target old-fp-temp)
         (return-pc :target return-pc-temp)
         (vals :more t))
  (:temporary (:sc any-reg :from (:argument 0)) old-fp-temp)
  (:temporary (:sc descriptor-reg :from (:argument 1)) return-pc-temp)
  (:move-args :known-return)
  (:info val-locs)
  (:ignore val-locs vals)
  (:vop-var vop)
  (:generator 6
    (trace-table-entry trace-table-fun-epilogue)
    (maybe-load-stack-tn old-fp-temp old-fp)
    (maybe-load-stack-tn return-pc-temp return-pc)
    (move csp-tn cfp-tn)
    (let ((cur-nfp (current-nfp-tn vop)))
      (when cur-nfp
        (inst addi nsp-tn cur-nfp
              (- (bytes-needed-for-non-descriptor-stack-frame)
                 number-stack-displacement))))
    (move cfp-tn old-fp-temp)
    (inst j return-pc-temp (- n-word-bytes other-pointer-lowtag))
    (trace-table-entry trace-table-normal)))


;;;; Full call:
;;;
;;;    There is something of a cross-product effect with full calls.  Different
;;; versions are used depending on whether we know the number of arguments or
;;; the name of the called function, and whether we want fixed values, unknown
;;; values, or a tail call.
;;;
;;; In full call, the arguments are passed creating a partial frame on the
;;; stack top and storing stack arguments into that frame.  On entry to the
;;; callee, this partial frame is pointed to by FP.  If there are no stack
;;; arguments, we don't bother allocating a partial frame, and instead set FP
;;; to SP just before the call.

;;;    This macro helps in the definition of full call VOPs by avoiding code
;;; replication in defining the cross-product VOPs.
;;;
;;; NAME is the name of the VOP to define.
;;;
;;; NAMED is true if the first argument is a symbol whose global function
;;; definition is to be called.
;;;
;;; RETURN is either :FIXED, :UNKNOWN or :TAIL:
;;; -- If :FIXED, then the call is for a fixed number of values, returned in
;;;    the standard passing locations (passed as result operands).
;;; -- If :UNKNOWN, then the result values are pushed on the stack, and the
;;;    result values are specified by the Start and Count as in the
;;;    unknown-values continuation representation.
;;; -- If :TAIL, then do a tail-recursive call.  No values are returned.
;;;    The Old-Fp and Return-PC are passed as the second and third arguments.
;;;
;;; In non-tail calls, the pointer to the stack arguments is passed as the last
;;; fixed argument.  If VARIABLE is false, then the passing locations are
;;; passed as a more arg.  VARIABLE is true if there are a variable number of
;;; arguments passed on the stack.  VARIABLE cannot be specified with :TAIL
;;; return.  TR variable argument call is implemented separately.
;;;
;;; In tail call with fixed arguments, the passing locations are passed as a
;;; more arg, but there is no new-FP, since the arguments have been set up in
;;; the current frame.
(defmacro define-full-call (name named return variable)
  (aver (not (and variable (eq return :tail))))
  `(define-vop (,name
                ,@(when (eq return :unknown)
                    '(unknown-values-receiver)))
     (:args
      ,@(unless (eq return :tail)
          '((new-fp :scs (any-reg) :to :eval)))

      ,(if named
           '(name :target name-pass)
           '(arg-fun :target lexenv))

      ,@(when (eq return :tail)
          '((old-fp :target old-fp-pass)
            (return-pc :target return-pc-pass)))

      ,@(unless variable '((args :more t :scs (descriptor-reg)))))

     ,@(when (eq return :fixed)
         '((:results (values :more t))))

     (:save-p ,(if (eq return :tail) :compute-only t))

     ,@(unless (or (eq return :tail) variable)
         '((:move-args :full-call)))

    (:vop-var vop)
    (:info ,@(unless (or variable (eq return :tail)) '(arg-locs))
           ,@(unless variable '(nargs))
           ,@(when (eq return :fixed) '(nvals))
           step-instrumenting)

     (:ignore
      ,@(unless (or variable (eq return :tail)) '(arg-locs))
      ,@(unless variable '(args)))

     (:temporary (:sc descriptor-reg
                  :offset ocfp-offset
                  :from (:argument 1)
                  ,@(unless (eq return :fixed)
                      '(:to :eval)))
                 old-fp-pass)

     (:temporary (:sc descriptor-reg
                  :offset lra-offset
                  :from (:argument ,(if (eq return :tail) 2 1))
                  :to :eval)
                 return-pc-pass)

     ,(if named
          `(:temporary (:sc descriptor-reg :offset fdefn-offset ; -dan
                            :from (:argument ,(if (eq return :tail) 0 1))
                            :to :eval)
                       name-pass)
          `(:temporary (:sc descriptor-reg :offset lexenv-offset
                            :from (:argument ,(if (eq return :tail) 0 1))
                            :to :eval)
                       lexenv))
     (:temporary (:scs (descriptor-reg) :from (:argument 0) :to :eval)
                 function)
     (:temporary (:sc any-reg :offset nargs-offset :to :eval)
                 nargs-pass)

     ,@(when variable
         (mapcar #'(lambda (name offset)
                     `(:temporary (:sc descriptor-reg
                                   :offset ,offset
                                   :to :eval)
                         ,name))
                 register-arg-names *register-arg-offsets*))
     ,@(when (eq return :fixed)
         '((:temporary (:scs (descriptor-reg) :from :eval) move-temp)))

     (:temporary (:scs (descriptor-reg) :to :eval) stepping)

     ,@(unless (eq return :tail)
         '((:temporary (:scs (non-descriptor-reg)) temp)
           (:temporary (:sc control-stack :offset nfp-save-offset) nfp-save)))

     (:temporary (:sc interior-reg :offset lip-offset) entry-point)

     (:generator ,(+ (if named 5 0)
                     (if variable 19 1)
                     (if (eq return :tail) 0 10)
                     15
                     (if (eq return :unknown) 25 0))
       (trace-table-entry trace-table-call-site)

       (let* ((cur-nfp (current-nfp-tn vop))
              ,@(unless (eq return :tail)
                  '((lra-label (gen-label))))
              (step-done-label (gen-label))
              (filler
               (remove nil
                       (list :load-nargs
                             ,@(if (eq return :tail)
                                   '((unless (location= old-fp old-fp-pass)
                                       :load-old-fp)
                                     (unless (location= return-pc
                                                        return-pc-pass)
                                       :load-return-pc)
                                     (when cur-nfp
                                       :frob-nfp))
                                   '(:comp-lra
                                     (when cur-nfp
                                       :frob-nfp)
                                     :save-fp
                                     :load-fp))))))
         (flet ((do-next-filler ()
                  (let* ((next (pop filler))
                         (what (if (consp next) (car next) next)))
                    (ecase what
                      (:load-nargs
                       ,@(if variable
                             `((inst sub nargs-pass csp-tn new-fp)
                               ,@(let ((index -1))
                                   (mapcar #'(lambda (name)
                                               `(loadw ,name new-fp
                                                       ,(incf index)))
                                           register-arg-names)))
                             '((inst lr nargs-pass (fixnumize nargs)))))
                      ,@(if (eq return :tail)
                            '((:load-old-fp
                               (sc-case old-fp
                                 (any-reg
                                  (inst mr old-fp-pass old-fp))
                                 (control-stack
                                  (loadw old-fp-pass cfp-tn
                                         (tn-offset old-fp)))))
                              (:load-return-pc
                               (sc-case return-pc
                                 (descriptor-reg
                                  (inst mr return-pc-pass return-pc))
                                 (control-stack
                                  (loadw return-pc-pass cfp-tn
                                         (tn-offset return-pc)))))
                              (:frob-nfp
                               (inst addi nsp-tn cur-nfp
                                     (- (bytes-needed-for-non-descriptor-stack-frame)
                                        number-stack-displacement))))
                            `((:comp-lra
                               (inst compute-lra-from-code
                                     return-pc-pass code-tn lra-label temp))
                              (:frob-nfp
                               (store-stack-tn nfp-save cur-nfp))
                              (:save-fp
                               (inst mr old-fp-pass cfp-tn))
                              (:load-fp
                               ,(if variable
                                    '(move cfp-tn new-fp)
                                    '(if (> nargs register-arg-count)
                                         (move cfp-tn new-fp)
                                         (move cfp-tn csp-tn))))))
                      ((nil)))))
                (insert-step-instrumenting (callable-tn)
                  ;; Conditionally insert a conditional trap:
                  (when step-instrumenting
                    ;; Get the symbol-value of SB!IMPL::*STEPPING*
                    #!-sb-thread
                    (load-symbol-value stepping sb!impl::*stepping*)
                    #!+sb-thread
                    (loadw stepping thread-base-tn thread-stepping-slot)
                    (inst cmpw stepping null-tn)
                    ;; If it's not null, trap.
                    (inst beq step-done-label)
                    ;; CONTEXT-PC will be pointing here when the
                    ;; interrupt is handled, not after the UNIMP.
                    (note-this-location vop :step-before-vop)
                    ;; Construct a trap code with the low bits from
                    ;; SINGLE-STEP-AROUND-TRAP and the high bits from
                    ;; the register number of CALLABLE-TN.
                    (inst unimp (logior single-step-around-trap
                                        (ash (reg-tn-encoding callable-tn)
                                             5)))
                    (emit-label step-done-label))))
           ,@(if named
                 `((sc-case name
                     (descriptor-reg (move name-pass name))
                     (control-stack
                      (loadw name-pass cfp-tn (tn-offset name))
                      (do-next-filler))
                     (constant
                      (loadw name-pass code-tn (tn-offset name)
                             other-pointer-lowtag)
                      (do-next-filler)))
                   ;; The step instrumenting must be done after
                   ;; FUNCTION is loaded, but before ENTRY-POINT is
                   ;; calculated.
                   (insert-step-instrumenting name-pass)
                   ;; The raw-addr (ENTRY-POINT) will be one of:
                   ;; closure_tramp, undefined_tramp, or somewhere
                   ;; within a simple-fun object.  If the latter, then
                   ;; it is essential (due to it being an interior
                   ;; pointer) that the function itself be in a
                   ;; register before the raw-addr is loaded.
                   (sb!assem:without-scheduling ()
                     (loadw function name-pass fdefn-fun-slot
                            other-pointer-lowtag)
                     (loadw entry-point name-pass fdefn-raw-addr-slot
                            other-pointer-lowtag))
                   (do-next-filler))
                 `((sc-case arg-fun
                     (descriptor-reg (move lexenv arg-fun))
                     (control-stack
                      (loadw lexenv cfp-tn (tn-offset arg-fun))
                      (do-next-filler))
                     (constant
                      (loadw lexenv code-tn (tn-offset arg-fun)
                             other-pointer-lowtag)
                      (do-next-filler)))
                   (loadw function lexenv closure-fun-slot
                    fun-pointer-lowtag)
                   (do-next-filler)
                   ;; The step instrumenting must be done before
                   ;; after FUNCTION is loaded, but before ENTRY-POINT
                   ;; is calculated.
                   (insert-step-instrumenting function)
                   (inst addi entry-point function
                    (- (ash simple-fun-code-offset word-shift)
                     fun-pointer-lowtag))
                   ))
           (loop
             (if filler
                 (do-next-filler)
                 (return)))

           (note-this-location vop :call-site)
           (inst mtctr entry-point)
           ;; this following line is questionable.  or else the alpha
           ;; code (which doesn't do it) is questionable
           ;; (inst mr code-tn function)
           (inst bctr))

         ,@(ecase return
             (:fixed
              '((emit-return-pc lra-label)
                (default-unknown-values vop values nvals move-temp
                                        temp lra-label)
                (when cur-nfp
                  (load-stack-tn cur-nfp nfp-save))))
             (:unknown
              '((emit-return-pc lra-label)
                (note-this-location vop :unknown-return)
                (receive-unknown-values values-start nvals start count
                                        lra-label temp)
                (when cur-nfp
                  (load-stack-tn cur-nfp nfp-save))))
             (:tail)))
       (trace-table-entry trace-table-normal))))


(define-full-call call nil :fixed nil)
(define-full-call call-named t :fixed nil)
(define-full-call multiple-call nil :unknown nil)
(define-full-call multiple-call-named t :unknown nil)
(define-full-call tail-call nil :tail nil)
(define-full-call tail-call-named t :tail nil)

(define-full-call call-variable nil :fixed t)
(define-full-call multiple-call-variable nil :unknown t)

;;; Defined separately, since needs special code that BLT's the
;;; arguments down.
(define-vop (tail-call-variable)
  (:args
   (args-arg :scs (any-reg) :target args)
   (function-arg :scs (descriptor-reg) :target lexenv)
   (old-fp-arg :scs (any-reg) :target old-fp)
   (lra-arg :scs (descriptor-reg) :target lra))
  (:temporary (:sc any-reg :offset nl0-offset :from (:argument 0)) args)
  (:temporary (:sc any-reg :offset lexenv-offset :from (:argument 1)) lexenv)
  (:temporary (:sc any-reg :offset ocfp-offset :from (:argument 2)) old-fp)
  (:temporary (:sc any-reg :offset lra-offset :from (:argument 3)) lra)
  (:temporary (:sc any-reg) temp)
  (:vop-var vop)
  (:generator 75
    ;; Move these into the passing locations if they are not already there.
    (move args args-arg)
    (move lexenv function-arg)
    (move old-fp old-fp-arg)
    (move lra lra-arg)
    ;; Clear the number stack if anything is there.
    (let ((cur-nfp (current-nfp-tn vop)))
      (when cur-nfp
        (inst addi nsp-tn cur-nfp
              (- (bytes-needed-for-non-descriptor-stack-frame)
                 number-stack-displacement))))
    (inst lr temp (make-fixup 'tail-call-variable :assembly-routine))
    (inst mtlr temp)
    (inst blr)))


;;;; Unknown values return:

;;; Return a single value using the unknown-values convention.
(define-vop (return-single)
  (:args (old-fp :scs (any-reg) :to :eval)
         (return-pc :scs (descriptor-reg) :target lra)
         (value))
  (:ignore value)
  (:temporary (:sc descriptor-reg :offset lra-offset :from (:argument 1)) lra)
  (:temporary (:scs (interior-reg)) lip)
  (:vop-var vop)
  (:generator 6
    (trace-table-entry trace-table-fun-epilogue)
    (move lra return-pc)
    ;; Clear the number stack.
    (let ((cur-nfp (current-nfp-tn vop)))
      (when cur-nfp
        (inst addi nsp-tn cur-nfp
              (- (bytes-needed-for-non-descriptor-stack-frame)
                 number-stack-displacement))))
    ;; Clear the control stack, and restore the frame pointer.
    (move csp-tn cfp-tn)
    (move cfp-tn old-fp)
    ;; Out of here.
    (lisp-return lra lip :offset 2)
    (trace-table-entry trace-table-normal)))

;;; Do unknown-values return of a fixed number of values.  The Values are
;;; required to be set up in the standard passing locations.  Nvals is the
;;; number of values returned.
;;;
;;; If returning a single value, then deallocate the current frame, restore
;;; FP and jump to the single-value entry at Return-PC + 8.
;;;
;;; If returning other than one value, then load the number of values returned,
;;; NIL out unsupplied values registers, restore FP and return at Return-PC.
;;; When there are stack values, we must initialize the argument pointer to
;;; point to the beginning of the values block (which is the beginning of the
;;; current frame.)
(define-vop (return)
  (:args
   (old-fp :scs (any-reg))
   (return-pc :scs (descriptor-reg) :to (:eval 1) :target lra)
   (values :more t))
  (:ignore values)
  (:info nvals)
  (:temporary (:sc descriptor-reg :offset a0-offset :from (:eval 0)) a0)
  (:temporary (:sc descriptor-reg :offset a1-offset :from (:eval 0)) a1)
  (:temporary (:sc descriptor-reg :offset a2-offset :from (:eval 0)) a2)
  (:temporary (:sc descriptor-reg :offset a3-offset :from (:eval 0)) a3)
  (:temporary (:sc descriptor-reg :offset lra-offset :from (:eval 1)) lra)
  (:temporary (:sc any-reg :offset nargs-offset) nargs)
  (:temporary (:sc any-reg :offset ocfp-offset) val-ptr)
  (:temporary (:scs (interior-reg)) lip)
  (:vop-var vop)
  (:generator 6
    (trace-table-entry trace-table-fun-epilogue)
    (move lra return-pc)
    ;; Clear the number stack.
    (let ((cur-nfp (current-nfp-tn vop)))
      (when cur-nfp
        (inst addi nsp-tn cur-nfp
              (- (bytes-needed-for-non-descriptor-stack-frame)
                 number-stack-displacement))))
    (cond ((= nvals 1)
           ;; Clear the control stack, and restore the frame pointer.
           (move csp-tn cfp-tn)
           (move cfp-tn old-fp)
           ;; Out of here.
           (lisp-return lra lip :offset 2))
          (t
           ;; Establish the values pointer and values count.
           (move val-ptr cfp-tn)
           (inst lr nargs (fixnumize nvals))
           ;; restore the frame pointer and clear as much of the control
           ;; stack as possible.
           (move cfp-tn old-fp)
           (inst addi csp-tn val-ptr (* nvals n-word-bytes))
           ;; pre-default any argument register that need it.
           (when (< nvals register-arg-count)
             (dolist (reg (subseq (list a0 a1 a2 a3) nvals))
               (move reg null-tn)))
           ;; And away we go.
           (lisp-return lra lip)))
    (trace-table-entry trace-table-normal)))

;;; Do unknown-values return of an arbitrary number of values (passed
;;; on the stack.)  We check for the common case of a single return
;;; value, and do that inline using the normal single value return
;;; convention.  Otherwise, we branch off to code that calls an
;;; assembly-routine.
(define-vop (return-multiple)
  (:args
   (old-fp-arg :scs (any-reg) :to (:eval 1))
   (lra-arg :scs (descriptor-reg) :to (:eval 1))
   (vals-arg :scs (any-reg) :target vals)
   (nvals-arg :scs (any-reg) :target nvals))
  (:temporary (:sc any-reg :offset nl1-offset :from (:argument 0)) old-fp)
  (:temporary (:sc descriptor-reg :offset lra-offset :from (:argument 1)) lra)
  (:temporary (:sc any-reg :offset nl0-offset :from (:argument 2)) vals)
  (:temporary (:sc any-reg :offset nargs-offset :from (:argument 3)) nvals)
  (:temporary (:sc descriptor-reg :offset a0-offset) a0)
  (:temporary (:scs (interior-reg)) lip)
  (:temporary (:sc any-reg) temp)
  (:vop-var vop)
  (:generator 13
    (trace-table-entry trace-table-fun-epilogue)
    (move lra lra-arg)
    (let ((not-single (gen-label)))
      ;; Clear the number stack.
      (let ((cur-nfp (current-nfp-tn vop)))
        (when cur-nfp
          (inst addi nsp-tn cur-nfp
                (- (bytes-needed-for-non-descriptor-stack-frame)
                   number-stack-displacement))))
      ;; Check for the single case.
      (inst cmpwi nvals-arg (fixnumize 1))
      (inst lwz a0 vals-arg 0)
      (inst bne not-single)
      ;; Return with one value.
      (move csp-tn cfp-tn)
      (move cfp-tn old-fp-arg)
      (lisp-return lra-arg lip :offset 2)
      ;; Nope, not the single case.
      (emit-label not-single)
      (move old-fp old-fp-arg)
      (move vals vals-arg)
      (move nvals nvals-arg)
      (inst lr temp (make-fixup 'return-multiple :assembly-routine))
      (inst mtlr temp)
      (inst blr))
    (trace-table-entry trace-table-normal)))

;;;; XEP hackery:

;;; We don't need to do anything special for regular functions.
(define-vop (setup-environment)
  (:info label)
  (:ignore label)
  (:generator 0
    ;; Don't bother doing anything.
    ))

;;; Get the lexical environment from its passing location.
(define-vop (setup-closure-environment)
  (:temporary (:sc descriptor-reg :offset lexenv-offset :target closure
               :to (:result 0))
              lexenv)
  (:results (closure :scs (descriptor-reg)))
  (:info label)
  (:ignore label)
  (:generator 6
    ;; Get result.
    (move closure lexenv)))

;;; Copy a more arg from the argument area to the end of the current frame.
;;; Fixed is the number of non-more arguments.
(define-vop (copy-more-arg)
  (:temporary (:sc any-reg :offset nl0-offset) result)
  (:temporary (:sc any-reg :offset nl1-offset) count)
  (:temporary (:sc any-reg :offset nl2-offset) src)
  (:temporary (:sc any-reg :offset nl3-offset) dst)
  (:temporary (:sc descriptor-reg :offset l0-offset) temp)
  (:info fixed)
  (:generator 20
    (let ((loop (gen-label))
          (do-regs (gen-label))
          (done (gen-label)))
      (when (< fixed register-arg-count)
        ;; Save a pointer to the results so we can fill in register args.
        ;; We don't need this if there are more fixed args than reg args.
        (move result csp-tn))
      ;; Allocate the space on the stack.
      (cond ((zerop fixed)
             (inst cmpwi nargs-tn 0)
             (inst add csp-tn csp-tn nargs-tn)
             (inst beq done))
            (t
             (inst addic. count nargs-tn (- (fixnumize fixed)))
             (inst ble done)
             (inst add csp-tn csp-tn count)))
      (when (< fixed register-arg-count)
        ;; We must stop when we run out of stack args, not when we run out of
        ;; more args.
        (inst addic. count nargs-tn (- (fixnumize register-arg-count)))
        ;; Everything of interest is in registers.
        (inst ble do-regs))
      ;; Initialize dst to be end of stack.
      (move dst csp-tn)
      ;; Initialize src to be end of args.
      (inst add src cfp-tn nargs-tn)

      (emit-label loop)
      ;; *--dst = *--src, --count
      (inst lwzu temp src (- n-word-bytes))
      (inst addic. count count (- (fixnumize 1)))
      (inst stwu temp dst (- n-word-bytes))
      (inst bgt loop)

      (emit-label do-regs)
      (when (< fixed register-arg-count)
        ;; Now we have to deposit any more args that showed up in registers.
        (inst subic. count nargs-tn (fixnumize fixed))
        (do ((i fixed (1+ i)))
            ((>= i register-arg-count))
          ;; Don't deposit any more than there are.
          (inst beq done)
          (inst subic. count count (fixnumize 1))
          ;; Store it relative to the pointer saved at the start.
          (storew (nth i *register-arg-tns*) result (- i fixed))))
      (emit-label done))))


;;; More args are stored consecutively on the stack, starting
;;; immediately at the context pointer.  The context pointer is not
;;; typed, so the lowtag is 0.
(define-vop (more-arg word-index-ref)
  (:variant 0 0)
  (:translate %more-arg))

;;; Turn more arg (context, count) into a list.
(define-vop (listify-rest-args)
  (:args (context-arg :target context :scs (descriptor-reg))
         (count-arg :target count :scs (any-reg)))
  (:arg-types * tagged-num)
  (:temporary (:scs (any-reg) :from (:argument 0)) context)
  (:temporary (:scs (any-reg) :from (:argument 1)) count)
  (:temporary (:scs (descriptor-reg) :from :eval) temp)
  (:temporary (:scs (non-descriptor-reg) :from :eval) dst)
  (:temporary (:sc non-descriptor-reg :offset nl3-offset) pa-flag)
  (:results (result :scs (descriptor-reg)))
  (:translate %listify-rest-args)
  (:policy :safe)
  (:node-var node)
  (:generator 20
    (let* ((enter (gen-label))
           (loop (gen-label))
           (done (gen-label))
           (dx-p (node-stack-allocate-p node)))
      (move context context-arg)
      (move count count-arg)
      ;; Check to see if there are any arguments.
      (inst cmpwi count 0)
      (move result null-tn)
      (inst beq done)

    ;; We need to do this atomically.
    (pseudo-atomic (pa-flag)
      ;; Allocate a cons (2 words) for each item.
      (if dx-p
          (progn
            (align-csp temp)
            (inst clrrwi result csp-tn n-lowtag-bits)
            (inst ori result result list-pointer-lowtag)
            (move dst result)
            (inst slwi temp count 1)
            (inst add csp-tn csp-tn temp))
          (progn
            (inst slwi temp count 1)
            (allocation result temp list-pointer-lowtag
                        :temp-tn dst
                        :flag-tn pa-flag)
            (move dst result)))
      (inst b enter)

      ;; Compute the next cons and store it in the current one.
      (emit-label loop)
      (inst addi dst dst (* 2 n-word-bytes))
      (storew dst dst -1 list-pointer-lowtag)

      ;; Grab one value.
      (emit-label enter)
      (loadw temp context)
      (inst addi context context n-word-bytes)

      ;; Dec count, and if != zero, go back for more.
      (inst addic. count count (- (fixnumize 1)))
      ;; Store the value into the car of the current cons (in the delay
      ;; slot).
      (storew temp dst 0 list-pointer-lowtag)
      (inst bgt loop)

      ;; NIL out the last cons.
      (storew null-tn dst 1 list-pointer-lowtag))
    (emit-label done))))


;;; Return the location and size of the more arg glob created by
;;; COPY-MORE-ARG.  SUPPLIED is the total number of arguments supplied
;;; (originally passed in NARGS.)  Fixed is the number of non-rest
;;; arguments.
;;;
;;; We must duplicate some of the work done by COPY-MORE-ARG, since at
;;; that time the environment is in a pretty brain-damaged state,
;;; preventing this info from being returned as values.  What we do is
;;; compute (- SUPPLIED FIXED), and return a pointer that many words
;;; below the current stack top.
(define-vop (more-arg-context)
  (:policy :fast-safe)
  (:translate sb!c::%more-arg-context)
  (:args (supplied :scs (any-reg)))
  (:arg-types tagged-num (:constant fixnum))
  (:info fixed)
  (:results (context :scs (descriptor-reg))
            (count :scs (any-reg)))
  (:result-types t tagged-num)
  (:note "more-arg-context")
  (:generator 5
    (inst subi count supplied (fixnumize fixed))
    (inst sub context csp-tn count)))

(define-vop (verify-arg-count)
  (:policy :fast-safe)
  (:translate sb!c::%verify-arg-count)
  (:args (nargs :scs (any-reg)))
  (:arg-types positive-fixnum (:constant t))
  (:info count)
  (:vop-var vop)
  (:save-p :compute-only)
  (:generator 3
   (inst twi :ne nargs (fixnumize count))))

;;; Signal various errors.
(macrolet ((frob (name error translate &rest args)
             `(define-vop (,name)
                ,@(when translate
                    `((:policy :fast-safe)
                      (:translate ,translate)))
                (:args ,@(mapcar #'(lambda (arg)
                                     `(,arg :scs (any-reg descriptor-reg)))
                                 args))
                (:vop-var vop)
                (:save-p :compute-only)
                (:generator 1000
                  (error-call vop ',error ,@args)))))
  (frob arg-count-error invalid-arg-count-error
    sb!c::%arg-count-error nargs)
  (frob type-check-error object-not-type-error sb!c::%type-check-error
    object type)
  (frob layout-invalid-error layout-invalid-error sb!c::%layout-invalid-error
    object layout)
  (frob odd-key-args-error odd-key-args-error
        sb!c::%odd-key-args-error)
  (frob unknown-key-arg-error unknown-key-arg-error
        sb!c::%unknown-key-arg-error key)
  (frob nil-fun-returned-error nil-fun-returned-error nil fun))

(define-vop (step-instrument-before-vop)
  (:temporary (:scs (descriptor-reg)) stepping)
  (:policy :fast-safe)
  (:vop-var vop)
  (:generator 3
    ;; Get the symbol-value of SB!IMPL::*STEPPING*
    #!-sb-thread
    (load-symbol-value stepping sb!impl::*stepping*)
    #!+sb-thread
    (loadw stepping thread-base-tn thread-stepping-slot)
    (inst cmpw stepping null-tn)
    ;; If it's not null, trap.
    (inst beq DONE)
    ;; CONTEXT-PC will be pointing here when the interrupt is handled,
    ;; not after the UNIMP.
    (note-this-location vop :step-before-vop)
    ;; CALLEE-REGISTER-OFFSET isn't needed for before-traps, so we
    ;; can just use a bare SINGLE-STEP-BEFORE-TRAP as the code.
    (inst unimp single-step-before-trap)
    DONE))
