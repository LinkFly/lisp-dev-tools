;;;; the machine specific support routines needed by the file assembler

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; This software is derived from the CMU CL system, which was
;;;; written at Carnegie Mellon University and released into the
;;;; public domain. The software is in the public domain and is
;;;; provided with absolutely no warranty. See the COPYING and CREDITS
;;;; files for more information.

(in-package "SB!VM")

;;;; RETURN-MULTIPLE

;;; For RETURN-MULTIPLE, we have to move the results from the end of
;;; the frame for the function that is returning to the end of the
;;; frame for the function being returned to.

#+sb-assembling ;; We don't want a vop for this one.
(define-assembly-routine
    (return-multiple (:return-style :none))
    (;; These are really arguments.
     (:temp ecx unsigned-reg ecx-offset)
     (:temp esi unsigned-reg esi-offset)

     ;; These we need as temporaries.
     (:temp eax unsigned-reg eax-offset)
     (:temp ebx unsigned-reg ebx-offset)
     (:temp edx unsigned-reg edx-offset)
     (:temp edi unsigned-reg edi-offset))

  ;; Pick off the cases where everything fits in register args.
  (inst jecxz ZERO-VALUES)
  (inst cmp ecx (fixnumize 1))
  (inst jmp :e ONE-VALUE)
  (inst cmp ecx (fixnumize 2))
  (inst jmp :e TWO-VALUES)
  (inst cmp ecx (fixnumize 3))
  (inst jmp :e THREE-VALUES)

  ;; As per the calling convention EBX is expected to point at the SP
  ;; before the stack frame.
  (inst lea ebx (make-ea :dword :base ebp-tn
                         :disp (* sp->fp-offset n-word-bytes)))

  ;; Save the count, the return address and restore the frame pointer,
  ;; because the loop is going to destroy them.
  (inst mov edx ecx)
  (inst mov eax (make-ea :dword :base ebp-tn
                         :disp (frame-byte-offset return-pc-save-offset)))
  (inst mov ebp-tn (make-ea :dword :base ebp-tn
                            :disp (frame-byte-offset ocfp-save-offset)))
  ;; Blit the values down the stack. Note: there might be overlap, so
  ;; we have to be careful not to clobber values before we've read
  ;; them. Because the stack builds down, we are copying to a larger
  ;; address. Therefore, we need to iterate from larger addresses to
  ;; smaller addresses. pfw-this says copy ecx words from esi to edi
  ;; counting down.
  (inst shr ecx (1- n-lowtag-bits))
  (inst std)                            ; count down
  (inst sub esi n-word-bytes)
  (inst lea edi (make-ea :dword :base ebx :disp (- n-word-bytes)))
  (inst rep)
  (inst movs :dword)
  (inst cld)

  ;; Restore the count.
  (inst mov ecx edx)

  ;; Set the stack top to the last result.
  (inst lea esp-tn (make-ea :dword :base edi :disp n-word-bytes))

  ;; Load the register args.
  (loadw edx ebx -1)
  (loadw edi ebx -2)
  (loadw esi ebx -3)

  ;; And back we go.
  (inst stc)
  (inst push eax)
  (inst ret)

  ;; Handle the register arg cases.
  ZERO-VALUES
  (inst lea ebx (make-ea :dword :base ebp-tn
                         :disp (* sp->fp-offset n-word-bytes)))
  (inst mov edx nil-value)
  (inst mov edi edx)
  (inst mov esi edx)
  (inst mov esp-tn ebp-tn)
  (inst stc)
  (inst pop ebp-tn)
  (inst ret)

  ;; Note: we can get this, because the return-multiple vop doesn't
  ;; check for this case when size > speed.
  ONE-VALUE
  (loadw edx esi -1)
  (inst mov esp-tn ebp-tn)
  (inst clc)
  (inst pop ebp-tn)
  (inst ret)

  TWO-VALUES
  (inst lea ebx (make-ea :dword :base ebp-tn
                         :disp (* sp->fp-offset n-word-bytes)))
  (loadw edx esi -1)
  (loadw edi esi -2)
  (inst mov esi nil-value)
  (inst mov esp-tn ebp-tn)
  (inst stc)
  (inst pop ebp-tn)
  (inst ret)

  THREE-VALUES
  (inst lea ebx (make-ea :dword :base ebp-tn
                         :disp (* sp->fp-offset n-word-bytes)))
  (loadw edx esi -1)
  (loadw edi esi -2)
  (loadw esi esi -3)
  (inst mov esp-tn ebp-tn)
  (inst stc)
  (inst pop ebp-tn)
  (inst ret))

;;;; TAIL-CALL-VARIABLE

;;; For tail-call-variable, we have to copy the arguments from the end
;;; of our stack frame (were args are produced) to the start of our
;;; stack frame (were args are expected).
;;;
;;; We take the function to call in EAX and a pointer to the arguments in
;;; ESI. EBP says the same over the jump, and the old frame pointer is
;;; still saved in the first stack slot. The return-pc is saved in
;;; the second stack slot, so we have to push it to make it look like
;;; we actually called. We also have to compute ECX from the difference
;;; between ESI and the stack top.
#+sb-assembling ;; No vop for this one either.
(define-assembly-routine
    (tail-call-variable
     (:return-style :none))

    ((:temp eax unsigned-reg eax-offset)
     (:temp ebx unsigned-reg ebx-offset)
     (:temp ecx unsigned-reg ecx-offset)
     (:temp edx unsigned-reg edx-offset)
     (:temp edi unsigned-reg edi-offset)
     (:temp esi unsigned-reg esi-offset))

  ;; Calculate NARGS (as a fixnum)
  (move ecx esi)
  (inst sub ecx esp-tn)

  ;; Check for all the args fitting the registers.
  (inst cmp ecx (fixnumize 3))
  (inst jmp :le REGISTER-ARGS)

  ;; Save the OLD-FP and RETURN-PC because the blit is going to trash
  ;; those stack locations. Save the ECX, because the loop is going to
  ;; trash it.
  (pushw ebp-tn (frame-word-offset ocfp-save-offset))
  (loadw ebx ebp-tn (frame-word-offset return-pc-save-offset))
  (inst push ecx)

  ;; Do the blit. Because we are coping from smaller addresses to
  ;; larger addresses, we have to start at the largest pair and work
  ;; our way down.
  (inst shr ecx (1- n-lowtag-bits))
  (inst std)                            ; count down
  (inst lea edi (make-ea :dword :base ebp-tn :disp (frame-byte-offset 0)))
  (inst sub esi (fixnumize 1))
  (inst rep)
  (inst movs :dword)
  (inst cld)

  ;; Load the register arguments carefully.
  (loadw edx ebp-tn (frame-word-offset ocfp-save-offset))

  ;; Restore OLD-FP and ECX.
  (inst pop ecx)
  ;; Overwrites a1
  (popw ebp-tn (frame-word-offset ocfp-save-offset))

  ;; Blow off the stack above the arguments.
  (inst lea esp-tn (make-ea :dword :base edi :disp n-word-bytes))

  ;; remaining register args
  (inst mov edi edx)
  (loadw edx ebp-tn (frame-word-offset 0))
  (loadw esi ebp-tn (frame-word-offset 2))

  ;; Push the (saved) return-pc so it looks like we just called.
  (inst push ebx)

  ;; And jump into the function.
  (inst jmp (make-ea-for-object-slot eax closure-fun-slot fun-pointer-lowtag))

  ;; All the arguments fit in registers, so load them.
  REGISTER-ARGS
  (loadw edx esi -1)
  (loadw edi esi -2)
  (loadw esi esi -3)

  ;; Clear most of the stack.
  (inst lea esp-tn
        (make-ea :dword :base ebp-tn :disp (* (- sp->fp-offset 3) n-word-bytes)))

  ;; Push the return-pc so it looks like we just called.
  (pushw ebp-tn (frame-word-offset return-pc-save-offset))

  ;; And away we go.
  (inst jmp (make-ea-for-object-slot eax closure-fun-slot fun-pointer-lowtag)))

(define-assembly-routine (throw
                          (:return-style :raw))
                         ((:arg target (descriptor-reg any-reg) edx-offset)
                          (:arg start any-reg ebx-offset)
                          (:arg count any-reg ecx-offset)
                          (:temp catch any-reg eax-offset))

  (declare (ignore start count))

  (load-tl-symbol-value catch *current-catch-block*)

  LOOP

  (let ((error (gen-label)))
    (assemble (*elsewhere*)
      (emit-label error)

      ;; Fake up a stack frame so that backtraces come out right.
      (inst push ebp-tn)
      (inst mov ebp-tn esp-tn)

      (emit-error-break nil error-trap
                        (error-number-or-lose 'unseen-throw-tag-error)
                        (list target)))
    (inst or catch catch)               ; check for NULL pointer
    (inst jmp :z error))

  (inst cmp target (make-ea-for-object-slot catch catch-block-tag-slot 0))
  (inst jmp :e EXIT)

  (loadw catch catch catch-block-previous-catch-slot)
  (inst jmp LOOP)

  EXIT

  ;; Here EAX points to catch block containing symbol pointed to by EDX.
  (inst jmp (make-fixup 'unwind :assembly-routine)))

;;;; non-local exit noise

#!-win32
(define-assembly-routine (unwind
                          (:return-style :none)
                          (:translate %continue-unwind)
                          (:policy :fast-safe))
                         ((:arg block (any-reg descriptor-reg) eax-offset)
                          (:arg start (any-reg descriptor-reg) ebx-offset)
                          (:arg count (any-reg descriptor-reg) ecx-offset)
                          (:temp uwp unsigned-reg esi-offset))
  (declare (ignore start count))

  (let ((error (generate-error-code nil 'invalid-unwind-error)))
    (inst or block block)               ; check for NULL pointer
    (inst jmp :z error))

  (load-tl-symbol-value uwp *current-unwind-protect-block*)

  ;; Does *CURRENT-UNWIND-PROTECT-BLOCK* match the value stored in
  ;; argument's CURRENT-UWP-SLOT?
  (inst cmp uwp
        (make-ea-for-object-slot block unwind-block-current-uwp-slot 0))
  ;; If a match, return to context in arg block.
  (inst jmp :e DO-EXIT)

  ;; Not a match - return to *CURRENT-UNWIND-PROTECT-BLOCK* context.
  ;; Important! Must save (and return) the arg 'block' for later use!!
  (move edx-tn block)
  (move block uwp)
  ;; Set next unwind protect context.
  (loadw uwp uwp unwind-block-current-uwp-slot)
  ;; we're about to reload ebp anyway, so let's borrow it here as a
  ;; temporary.  Hope this works
  (store-tl-symbol-value uwp *current-unwind-protect-block* ebp-tn)

  DO-EXIT

  (loadw ebp-tn block unwind-block-current-cont-slot)

  ;; Uwp-entry expects some things in known locations so that they can
  ;; be saved on the stack: the block in edx-tn, start in ebx-tn, and
  ;; count in ecx-tn.

  (inst jmp (make-ea-for-object-slot block unwind-block-entry-pc-slot 0)))


;;;; Win32 non-local exit noise

#!+win32
(define-assembly-routine (unwind
                          (:return-style :none)
                          (:policy :fast-safe))
                         ((:arg block (any-reg descriptor-reg) eax-offset)
                          (:arg start (any-reg descriptor-reg) ebx-offset)
                          (:arg count (any-reg descriptor-reg) ecx-offset))
  (declare (ignore start count))

  (let ((error (generate-error-code nil 'invalid-unwind-error)))
    (inst or block block)               ; check for NULL pointer
    (inst jmp :z error))

  ;; Save all our registers, as we're about to clobber them.
  (inst pusha)

  ;; Find the SEH frame surrounding our target.
  (loadw ecx-tn block unwind-block-next-seh-frame-slot)

  ;; This section copied from VOP CALL-OUT.
  ;; Setup the NPX for C; all the FP registers need to be
  ;; empty; pop them all.
  (dotimes (i 8)
    (inst fstp fr0-tn))

  ;; I'm unlikely to ever forget this again.
  (inst cld)

  ;; Set up a bogus stack frame for RtlUnwind to pick its return
  ;; address from.  (Yes, this is how RtlUnwind works.)
  (inst push (make-fixup 'win32-unwind-tail :assembly-routine))
  (inst push ebp-tn)
  (inst mov ebp-tn esp-tn)

  ;; Actually call out for the unwind.
  (inst push 0)
  (inst push 0)
  (inst push 0)
  (inst push ecx-tn)
  (inst call (make-fixup "RtlUnwind@16" :foreign)))

;; We want no VOP for this one and for it to only happen on Win32
;; targets.  Hence the following disaster.
#!+#.(cl:if (cl:member sb-assembling cl:*features*) win32 '(or))
(define-assembly-routine
    (win32-unwind-tail (:return-style :none))
    ((:temp block unsigned-reg eax-offset))

  ;; The unwind returns here.  Had to use a VOP for this because
  ;; PUSH won't accept a label as an argument.

  ;; Clean up the bogus stack frame we pushed for the unwind.
  (inst pop ebp-tn)
  (inst pop esi-tn) ;; Random scratch register.

  ;; This section based on VOP CALL-OUT.
  ;; Restore the NPX for lisp; ensure no regs are empty
  (dotimes (i 8)
    (inst fldz))

  ;; Restore our regs.
  (inst popa)

  ;; By now we've unwound all the UWP frames required, so we
  ;; just jump to our target block.
  (loadw ebp-tn block unwind-block-current-cont-slot)

  ;; Nlx-entry expects the arg start in ebx-tn and the arg count
  ;; in ecx-tn.  Fortunately, that's where they are already.
  (inst jmp (make-ea-for-object-slot block unwind-block-entry-pc-slot 0)))


;;;; Win32 UWP block SEH interface.

;; We want no VOP for this one and for it to only happen on Win32
;; targets.  Hence the following disaster.
#!+#.(cl:if (cl:member sb-assembling cl:*features*) win32 '(or))
(define-assembly-routine
    (uwp-seh-handler (:return-style :none))
    ((:temp block unsigned-reg eax-offset))

  ;; We get called for any exception which happens within our
  ;; dynamic contour that isn't handled below us, and for
  ;; unwinding.

  ;; For the exceptions we just return ExceptionContinueSearch.

  ;; Find the exception record.
  (inst mov eax-tn (make-ea :dword :base esp-tn :disp 4))

  ;; Check unwind flags.
  (inst test (make-ea :byte :base eax-tn :disp 4) 6) ; EH_UNWINDING | EH_EXIT_UNWIND

  ;; To see if we're unwinding or not.
  (inst jmp :nz UNWINDING)

  ;; We're not unwinding, so we're not interested.
  (inst mov eax-tn 1) ;; exception-continue-search
  (inst ret)

  ;; For the unwinds we establish a basic environment as per
  ;; call_into_lisp, but without the extra SEH frame (the theory
  ;; being that we're already in a Lisp SEH context), and invoke
  ;; our UWP block to unwind itself.

  ;; FIXME: Do we need to establish an SEH frame anyway?  And do
  ;; we need to do the same stack frame hackery for the debugger
  ;; as we do for the main exception handler?

  ;; When the UWP block calls %continue-unwind, we come back to
  ;; the next assembly routine, below, which reinitializes for C
  ;; and returns to the Win32 unwind machinery.

  ;; If the UWP block sees fit to do a non-local exit, things
  ;; Just Work, thanks to the Win32 API being sanely designed
  ;; and our complying with it.

  ;; We also must update *current-unwind-protect-block* before
  ;; calling the cleanup function.

  UNWINDING

  ;; Save all registers (overkill)
  (inst pusha)

  ;; Establish our stack frame.
  (inst mov ebp-tn esp-tn)

  ;; This section based on VOP CALL-OUT.
  ;; Restore the NPX for lisp; ensure no regs are empty
  (dotimes (i 8)
    (inst fldz))

  ;; Find our unwind-block by way of our SEH frame.
  (inst mov block (make-ea :dword :base ebp-tn :disp #x28))
  (inst lea block (make-ea :dword :base block
                           :disp (- (* unwind-block-next-seh-frame-slot
                                       n-word-bytes))))

  ;; Update *CURRENT-UNWIND-PROTECT-BLOCK*.
  (loadw ebx-tn block unwind-block-current-uwp-slot)
  (store-tl-symbol-value ebx-tn *current-unwind-protect-block* ecx-tn)

  ;; Uwp-entry expects some things in known locations so that they can
  ;; be saved on the stack: the block in edx-tn, start in ebx-tn, and
  ;; count in ecx-tn.  We don't actually have any of that here, but we
  ;; do need to have access to our own stack frame, so we hijack the
  ;; known locations to cover our own state.

  (inst xor ebx-tn ebx-tn)
  (inst xor ecx-tn ecx-tn)
  (inst mov ebx-tn ebp-tn)
  (loadw ebp-tn block unwind-block-current-cont-slot)
  (inst jmp (make-ea-for-object-slot block unwind-block-entry-pc-slot 0)))

#!+win32
(define-assembly-routine (continue-unwind
                          (:return-style :none)
                          (:translate %continue-unwind)
                          (:policy :fast-safe))
                         ((:arg block (any-reg descriptor-reg) eax-offset)
                          (:arg start (any-reg descriptor-reg) ebx-offset)
                          (:arg count (any-reg descriptor-reg) ecx-offset))
  (declare (ignore block count))
  ;; The args here are mostly ignored because we're using the
  ;; win32 unwind mechanism and keep all that elsewhere.  The
  ;; exception is START, which we use to pass the saved EBP for
  ;; our exception handler.

  ;; "All" we have to do here is reload our EBP, reestablish a C
  ;; environment, and return ExceptionContinueSearch.  The OS
  ;; handles the rest.

  ;; Restore our frame pointer.
  (inst mov esp-tn start)

  ;; This section copied from VOP CALL-OUT.
  ;; Setup the NPX for C; all the FP registers need to be
  ;; empty; pop them all.
  (dotimes (i 8)
    (inst fstp fr0-tn))

  ;; I'm unlikely to ever forget this again.
  (inst cld)

  ;; Restore our saved registers
  (inst popa)

  ;; And we're done.
  (inst mov eax-tn 1) ;; exception-continue-search
  (inst ret))
