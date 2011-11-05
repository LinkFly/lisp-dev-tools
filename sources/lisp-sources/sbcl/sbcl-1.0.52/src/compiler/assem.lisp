;;;; scheduling assembler

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; This software is derived from the CMU CL system, which was
;;;; written at Carnegie Mellon University and released into the
;;;; public domain. The software is in the public domain and is
;;;; provided with absolutely no warranty. See the COPYING and CREDITS
;;;; files for more information.

(in-package "SB!ASSEM")

;;;; assembly control parameters

(defvar *assem-scheduler-p* nil)
(declaim (type boolean *assem-scheduler-p*))

(defvar *assem-instructions* (make-hash-table :test 'equal))
(declaim (type hash-table *assem-instructions*))

(defvar *assem-max-locations* 0)
(declaim (type index *assem-max-locations*))

;;;; the SEGMENT structure

;;; This structure holds the state of the assembler.
(defstruct (segment (:copier nil))
  ;; the type of this segment (for debugging output and stuff)
  (type :regular :type (member :regular :elsewhere))
  ;; Ordinarily this is a vector where instructions are written. If
  ;; the segment is made invalid (e.g. by APPEND-SEGMENT) then the
  ;; vector can be replaced by NIL. This used to be an adjustable
  ;; array, but we now do the array size management manually for
  ;; performance reasons (as of 2006-05-13 hairy array operations
  ;; are rather slow compared to simple ones).
  (buffer (make-array 0 :element-type 'assembly-unit)
          :type (or null (simple-array assembly-unit)))
  ;; whether or not to run the scheduler. Note: if the instruction
  ;; definitions were not compiled with the scheduler turned on, this
  ;; has no effect.
  (run-scheduler nil)
  ;; If a function, then this is funcalled for each inst emitted with
  ;; the segment, the VOP, the name of the inst (as a string), and the
  ;; inst arguments.
  (inst-hook nil :type (or function null))
  ;; what position does this correspond to? Initially, positions and
  ;; indexes are the same, but after we start collapsing choosers,
  ;; positions can change while indexes stay the same.
  (current-posn 0 :type index)
  (%current-index 0 :type index)
  ;; a list of all the annotations that have been output to this segment
  (annotations nil :type list)
  ;; a pointer to the last cons cell in the annotations list. This is
  ;; so we can quickly add things to the end of the annotations list.
  (last-annotation nil :type list)
  ;; the number of bits of alignment at the last time we synchronized
  (alignment max-alignment :type alignment)
  ;; the position the last time we synchronized
  (sync-posn 0 :type index)
  ;; The posn and index everything ends at. This is not maintained
  ;; while the data is being generated, but is filled in after.
  ;; Basically, we copy CURRENT-POSN and CURRENT-INDEX so that we can
  ;; trash them while processing choosers and back-patches.
  (final-posn 0 :type index)
  (final-index 0 :type index)
  ;; *** State used by the scheduler during instruction queueing.
  ;;
  ;; a list of postits. These are accumulated between instructions.
  (postits nil :type list)
  ;; ``Number'' for last instruction queued. Used only to supply insts
  ;; with unique sset-element-number's.
  (inst-number 0 :type index)
  ;; SIMPLE-VECTORs mapping locations to the instruction that reads them and
  ;; instructions that write them
  (readers (make-array *assem-max-locations* :initial-element nil)
           :type simple-vector)
  (writers (make-array *assem-max-locations* :initial-element nil)
           :type simple-vector)
  ;; The number of additional cycles before the next control transfer,
  ;; or NIL if a control transfer hasn't been queued. When a delayed
  ;; branch is queued, this slot is set to the delay count.
  (branch-countdown nil :type (or null (and fixnum unsigned-byte)))
  ;; *** These two slots are used both by the queuing noise and the
  ;; scheduling noise.
  ;;
  ;; All the instructions that are pending and don't have any
  ;; unresolved dependents. We don't list branches here even if they
  ;; would otherwise qualify. They are listed above.
  (emittable-insts-sset (make-sset) :type sset)
  ;; list of queued branches. We handle these specially, because they
  ;; have to be emitted at a specific place (e.g. one slot before the
  ;; end of the block).
  (queued-branches nil :type list)
  ;; *** state used by the scheduler during instruction scheduling
  ;;
  ;; the instructions who would have had a read dependent removed if
  ;; it were not for a delay slot. This is a list of lists. Each
  ;; element in the top level list corresponds to yet another cycle of
  ;; delay. Each element in the second level lists is a dotted pair,
  ;; holding the dependency instruction and the dependent to remove.
  (delayed nil :type list)
  ;; The emittable insts again, except this time as a list sorted by depth.
  (emittable-insts-queue nil :type list)
  ;; Whether or not to collect dynamic statistics. This is just the same as
  ;; *COLLECT-DYNAMIC-STATISTICS* but is faster to reference.
  #!+sb-dyncount
  (collect-dynamic-statistics nil))
(sb!c::defprinter (segment)
  type)

(declaim (inline segment-current-index))
(defun segment-current-index (segment)
  (segment-%current-index segment))

(defun (setf segment-current-index) (new-value segment)
  (declare (type index new-value)
           (type segment segment))
  ;; FIXME: It would be lovely to enforce this, but first FILL-IN will
  ;; need to be convinced to stop rolling SEGMENT-CURRENT-INDEX
  ;; backwards.
  ;;
  ;; Enforce an observed regularity which makes it easier to think
  ;; about what's going on in the (legacy) code: The segment never
  ;; shrinks. -- WHN the reverse engineer
  #+nil (aver (>= new-value (segment-current-index segment)))
  (let* ((buffer (segment-buffer segment))
         (new-buffer-size (length buffer)))
    (declare (type (simple-array (unsigned-byte 8)) buffer)
             (type index new-buffer-size))
    ;; Make sure the array is big enough.
    (when (<= new-buffer-size new-value)
      (do ()
          ((> new-buffer-size new-value))
        ;; When we have to increase the size of the array, we want to
        ;; roughly double the vector length: that way growing the array
        ;; to size N conses only O(N) bytes in total. But just doubling
        ;; the length would leave a zero-length vector unchanged. Hence,
        ;; take the MAX with 1..
        (setf new-buffer-size (max 1 (* 2 new-buffer-size))))
      (let ((new-buffer (make-array new-buffer-size
                                    :element-type '(unsigned-byte 8))))
        (replace new-buffer buffer)
        (setf (segment-buffer segment) new-buffer)))
    ;; Now that the array has the intended next free byte, we can point to it.
    (setf (segment-%current-index segment) new-value)))

;;; Various functions (like BACK-PATCH-FUN or CHOOSER-WORST-CASE-FUN)
;;; aren't cleanly parameterized, but instead use
;;; SEGMENT-CURRENT-INDEX and/or SEGMENT-CURRENT-POSN as global
;;; variables. So code which calls such functions needs to modify
;;; SEGMENT-CURRENT-INDEX and SEGMENT-CURRENT-POSN. This is left over
;;; from the old new-assem.lisp C-style code, and so all the
;;; destruction happens to be done after other uses of these slots are
;;; done and things basically work. However, (1) it's fundamentally
;;; nasty, and (2) at least one thing doesn't work right: OpenMCL
;;; properly points out that SUBSEQ's indices aren't supposed to
;;; exceed its logical LENGTH, i.e. its FILL-POINTER, i.e.
;;; SEGMENT-CURRENT-INDEX.
;;;
;;; As a quick fix involving minimal modification of legacy code,
;;; we do such sets of SEGMENT-CURRENT-INDEX and SEGMENT-CURRENT-POSN
;;; using this macro, which restores 'em afterwards.
;;;
;;; FIXME: It'd probably be better to cleanly parameterize things like
;;; BACK-PATCH-FUN so we can avoid this nastiness altogether.
(defmacro with-modified-segment-index-and-posn ((segment index posn)
                                                &body body)
  (with-unique-names (n-segment old-index old-posn)
    `(let* ((,n-segment ,segment)
            (,old-index (segment-current-index ,n-segment))
            (,old-posn (segment-current-posn ,n-segment)))
       (unwind-protect
           (progn
             (setf (segment-current-index ,n-segment) ,index
                   (segment-current-posn ,n-segment) ,posn)
             ,@body)
         (setf (segment-current-index ,n-segment) ,old-index
               (segment-current-posn ,n-segment) ,old-posn)))))

;;;; structures/types used by the scheduler

(!def-boolean-attribute instruction
  ;; This attribute is set if the scheduler can freely flush this
  ;; instruction if it thinks it is not needed. Examples are NOP and
  ;; instructions that have no side effect not described by the
  ;; writes.
  flushable
  ;; This attribute is set when an instruction can cause a control
  ;; transfer. For test instructions, the delay is used to determine
  ;; how many instructions follow the branch.
  branch
  ;; This attribute indicates that this ``instruction'' can be
  ;; variable length, and therefore had better never be used in a
  ;; branch delay slot.
  variable-length)

(def!struct (instruction
            (:include sset-element)
            (:conc-name inst-)
            (:constructor make-instruction (number emitter attributes delay))
            (:copier nil))
  ;; The function to envoke to actually emit this instruction. Gets called
  ;; with the segment as its one argument.
  (emitter (missing-arg) :type (or null function))
  ;; The attributes of this instruction.
  (attributes (instruction-attributes) :type sb!c:attributes)
  ;; Number of instructions or cycles of delay before additional
  ;; instructions can read our writes.
  (delay 0 :type (and fixnum unsigned-byte))
  ;; the maximum number of instructions in the longest dependency
  ;; chain from this instruction to one of the independent
  ;; instructions. This is used as a heuristic at to which
  ;; instructions should be scheduled first.
  (depth nil :type (or null (and fixnum unsigned-byte)))
  ;; Note: When trying remember which of the next four is which, note
  ;; that the ``read'' or ``write'' always refers to the dependent
  ;; (second) instruction.
  ;;
  ;; instructions whose writes this instruction tries to read
  (read-dependencies (make-sset) :type sset)
  ;; instructions whose writes or reads are overwritten by this instruction
  (write-dependencies (make-sset) :type sset)
  ;; instructions which write what we read or write
  (write-dependents (make-sset) :type sset)
  ;; instructions which read what we write
  (read-dependents (make-sset) :type sset))
#!+sb-show-assem (defvar *inst-ids* (make-hash-table :test 'eq))
#!+sb-show-assem (defvar *next-inst-id* 0)
(sb!int:def!method print-object ((inst instruction) stream)
  (print-unreadable-object (inst stream :type t :identity t)
    #!+sb-show-assem
    (princ (or (gethash inst *inst-ids*)
               (setf (gethash inst *inst-ids*)
                     (incf *next-inst-id*)))
           stream)
    (format stream
            #!+sb-show-assem " emitter=~S" #!-sb-show-assem "emitter=~S"
            (let ((emitter (inst-emitter inst)))
              (if emitter
                  (multiple-value-bind (lambda lexenv-p name)
                      (function-lambda-expression emitter)
                    (declare (ignore lambda lexenv-p))
                    name)
                  '<flushed>)))
    (when (inst-depth inst)
      (format stream ", depth=~W" (inst-depth inst)))))

#!+sb-show-assem
(defun reset-inst-ids ()
  (clrhash *inst-ids*)
  (setf *next-inst-id* 0))

;;;; the scheduler itself

(defmacro without-scheduling ((&optional (segment '(%%current-segment%%)))
                              &body body)
  #!+sb-doc
  "Execute BODY (as a PROGN) without scheduling any of the instructions
   generated inside it. This is not protected by UNWIND-PROTECT, so
   DO NOT use THROW or RETURN-FROM to escape from it."
  ;; FIXME: Why not just use UNWIND-PROTECT? Or is there some other
  ;; reason why we shouldn't use THROW or RETURN-FROM?
  (let ((var (gensym))
        (seg (gensym)))
    `(let* ((,seg ,segment)
            (,var (segment-run-scheduler ,seg)))
       (when ,var
         (schedule-pending-instructions ,seg)
         (setf (segment-run-scheduler ,seg) nil))
       ,@body
       (setf (segment-run-scheduler ,seg) ,var))))

(defmacro note-dependencies ((segment inst) &body body)
  (sb!int:once-only ((segment segment) (inst inst))
    `(macrolet ((reads (loc) `(note-read-dependency ,',segment ,',inst ,loc))
                (writes (loc &rest keys)
                  `(note-write-dependency ,',segment ,',inst ,loc ,@keys)))
       ,@body)))

(defun note-read-dependency (segment inst read)
  (multiple-value-bind (loc-num size)
      (sb!c:location-number read)
    #!+sb-show-assem (format *trace-output*
                             "~&~S reads ~S[~W for ~W]~%"
                             inst read loc-num size)
    (when loc-num
      ;; Iterate over all the locations for this TN.
      (do ((index loc-num (1+ index))
           (end-loc (+ loc-num (or size 1))))
          ((>= index end-loc))
        (declare (type (mod 2048) index end-loc))
        (let ((writers (svref (segment-writers segment) index)))
          (when writers
            ;; The inst that wrote the value we want to read must have
            ;; completed.
            (let ((writer (car writers)))
              (sset-adjoin writer (inst-read-dependencies inst))
              (sset-adjoin inst (inst-read-dependents writer))
              (sset-delete writer (segment-emittable-insts-sset segment))
              ;; And it must have been completed *after* all other
              ;; writes to that location. Actually, that isn't quite
              ;; true. Each of the earlier writes could be done
              ;; either before this last write, or after the read, but
              ;; we have no way of representing that.
              (dolist (other-writer (cdr writers))
                (sset-adjoin other-writer (inst-write-dependencies writer))
                (sset-adjoin writer (inst-write-dependents other-writer))
                (sset-delete other-writer
                             (segment-emittable-insts-sset segment))))
            ;; And we don't need to remember about earlier writes any
            ;; more. Shortening the writers list means that we won't
            ;; bother generating as many explicit arcs in the graph.
            (setf (cdr writers) nil)))
        (push inst (svref (segment-readers segment) index)))))
  (values))

(defun note-write-dependency (segment inst write &key partially)
  (multiple-value-bind (loc-num size)
      (sb!c:location-number write)
    #!+sb-show-assem (format *trace-output*
                             "~&~S writes ~S[~W for ~W]~%"
                             inst write loc-num size)
    (when loc-num
      ;; Iterate over all the locations for this TN.
      (do ((index loc-num (1+ index))
           (end-loc (+ loc-num (or size 1))))
          ((>= index end-loc))
        (declare (type (mod 2048) index end-loc))
        ;; All previous reads of this location must have completed.
        (dolist (prev-inst (svref (segment-readers segment) index))
          (unless (eq prev-inst inst)
            (sset-adjoin prev-inst (inst-write-dependencies inst))
            (sset-adjoin inst (inst-write-dependents prev-inst))
            (sset-delete prev-inst (segment-emittable-insts-sset segment))))
        (when partially
          ;; All previous writes to the location must have completed.
          (dolist (prev-inst (svref (segment-writers segment) index))
            (sset-adjoin prev-inst (inst-write-dependencies inst))
            (sset-adjoin inst (inst-write-dependents prev-inst))
            (sset-delete prev-inst (segment-emittable-insts-sset segment)))
          ;; And we can forget about remembering them, because
          ;; depending on us is as good as depending on them.
          (setf (svref (segment-writers segment) index) nil))
        (push inst (svref (segment-writers segment) index)))))
  (values))

;;; This routine is called by due to uses of the INST macro when the
;;; scheduler is turned on. The change to the dependency graph has
;;; already been computed, so we just have to check to see whether the
;;; basic block is terminated.
(defun queue-inst (segment inst)
  #!+sb-show-assem (format *trace-output* "~&queuing ~S~%" inst)
  #!+sb-show-assem (format *trace-output*
                           "  reads ~S~%  writes ~S~%"
                           (sb!int:collect ((reads))
                             (do-sset-elements (read
                                                (inst-read-dependencies inst))
                                (reads read))
                             (reads))
                           (sb!int:collect ((writes))
                             (do-sset-elements (write
                                                (inst-write-dependencies inst))
                                (writes write))
                             (writes)))
  (aver (segment-run-scheduler segment))
  (let ((countdown (segment-branch-countdown segment)))
    (when countdown
      (decf countdown)
      (aver (not (instruction-attributep (inst-attributes inst)
                                         variable-length))))
    (cond ((instruction-attributep (inst-attributes inst) branch)
           (unless countdown
             (setf countdown (inst-delay inst)))
           (push (cons countdown inst)
                 (segment-queued-branches segment)))
          (t
           (sset-adjoin inst (segment-emittable-insts-sset segment))))
    (when countdown
      (setf (segment-branch-countdown segment) countdown)
      (when (zerop countdown)
        (schedule-pending-instructions segment))))
  (values))

;;; Emit all the pending instructions, and reset any state. This is
;;; called whenever we hit a label (i.e. an entry point of some kind)
;;; and when the user turns the scheduler off (otherwise, the queued
;;; instructions would sit there until the scheduler was turned back
;;; on, and emitted in the wrong place).
(defun schedule-pending-instructions (segment)
  (aver (segment-run-scheduler segment))

  ;; Quick blow-out if nothing to do.
  (when (and (sset-empty (segment-emittable-insts-sset segment))
             (null (segment-queued-branches segment)))
    (return-from schedule-pending-instructions
                 (values)))

  #!+sb-show-assem (format *trace-output*
                           "~&scheduling pending instructions..~%")

  ;; Note that any values live at the end of the block have to be
  ;; computed last.
  (let ((emittable-insts (segment-emittable-insts-sset segment))
        (writers (segment-writers segment)))
    (dotimes (index (length writers))
      (let* ((writer (svref writers index))
             (inst (car writer))
             (overwritten (cdr writer)))
        (when writer
          (when overwritten
            (let ((write-dependencies (inst-write-dependencies inst)))
              (dolist (other-inst overwritten)
                (sset-adjoin inst (inst-write-dependents other-inst))
                (sset-adjoin other-inst write-dependencies)
                (sset-delete other-inst emittable-insts))))
          ;; If the value is live at the end of the block, we can't flush it.
          (setf (instruction-attributep (inst-attributes inst) flushable)
                nil)))))

  ;; Grovel through the entire graph in the forward direction finding
  ;; all the leaf instructions.
  (labels ((grovel-inst (inst)
             (let ((max 0))
               (do-sset-elements (dep (inst-write-dependencies inst))
                 (let ((dep-depth (or (inst-depth dep) (grovel-inst dep))))
                   (when (> dep-depth max)
                     (setf max dep-depth))))
               (do-sset-elements (dep (inst-read-dependencies inst))
                 (let ((dep-depth
                        (+ (or (inst-depth dep) (grovel-inst dep))
                           (inst-delay dep))))
                   (when (> dep-depth max)
                     (setf max dep-depth))))
               (cond ((and (sset-empty (inst-read-dependents inst))
                           (instruction-attributep (inst-attributes inst)
                                                   flushable))
                      #!+sb-show-assem (format *trace-output*
                                               "flushing ~S~%"
                                               inst)
                      (setf (inst-emitter inst) nil)
                      (setf (inst-depth inst) max))
                     (t
                      (setf (inst-depth inst) max))))))
    (let ((emittable-insts nil)
          (delayed nil))
      (do-sset-elements (inst (segment-emittable-insts-sset segment))
        (grovel-inst inst)
        (if (zerop (inst-delay inst))
            (push inst emittable-insts)
            (setf delayed
                  (add-to-nth-list delayed inst (1- (inst-delay inst))))))
      (setf (segment-emittable-insts-queue segment)
            (sort emittable-insts #'> :key #'inst-depth))
      (setf (segment-delayed segment) delayed))
    (dolist (branch (segment-queued-branches segment))
      (grovel-inst (cdr branch))))
  #!+sb-show-assem (format *trace-output*
                           "queued branches: ~S~%"
                           (segment-queued-branches segment))
  #!+sb-show-assem (format *trace-output*
                           "initially emittable: ~S~%"
                           (segment-emittable-insts-queue segment))
  #!+sb-show-assem (format *trace-output*
                           "initially delayed: ~S~%"
                           (segment-delayed segment))

  ;; Accumulate the results in reverse order. Well, actually, this
  ;; list will be in forward order, because we are generating the
  ;; reverse order in reverse.
  (let ((results nil))

    ;; Schedule all the branches in their exact locations.
    (let ((insts-from-end (segment-branch-countdown segment)))
      (dolist (branch (segment-queued-branches segment))
        (let ((inst (cdr branch)))
          (dotimes (i (- (car branch) insts-from-end))
            ;; Each time through this loop we need to emit another
            ;; instruction. First, we check to see whether there is
            ;; any instruction that must be emitted before (i.e. must
            ;; come after) the branch inst. If so, emit it. Otherwise,
            ;; just pick one of the emittable insts. If there is
            ;; nothing to do, then emit a nop. ### Note: despite the
            ;; fact that this is a loop, it really won't work for
            ;; repetitions other then zero and one. For example, if
            ;; the branch has two dependents and one of them dpends on
            ;; the other, then the stuff that grabs a dependent could
            ;; easily grab the wrong one. But I don't feel like fixing
            ;; this because it doesn't matter for any of the
            ;; architectures we are using or plan on using.
            (flet ((maybe-schedule-dependent (dependents)
                     (do-sset-elements (inst dependents)
                       ;; If do-sset-elements enters the body, then there is a
                       ;; dependent. Emit it.
                       (note-resolved-dependencies segment inst)
                       ;; Remove it from the emittable insts.
                       (setf (segment-emittable-insts-queue segment)
                             (delete inst
                                     (segment-emittable-insts-queue segment)
                                     :test #'eq))
                       ;; And if it was delayed, removed it from the delayed
                       ;; list. This can happen if there is a load in a
                       ;; branch delay slot.
                       (block scan-delayed
                         (do ((delayed (segment-delayed segment)
                                       (cdr delayed)))
                             ((null delayed))
                           (do ((prev nil cons)
                                (cons (car delayed) (cdr cons)))
                               ((null cons))
                             (when (eq (car cons) inst)
                               (if prev
                                   (setf (cdr prev) (cdr cons))
                                   (setf (car delayed) (cdr cons)))
                               (return-from scan-delayed nil)))))
                       ;; And return it.
                       (return inst))))
              (let ((fill (or (maybe-schedule-dependent
                               (inst-read-dependents inst))
                              (maybe-schedule-dependent
                               (inst-write-dependents inst))
                              (schedule-one-inst segment t)
                              :nop)))
                #!+sb-show-assem (format *trace-output*
                                         "filling branch delay slot with ~S~%"
                                         fill)
                (push fill results)))
            (advance-one-inst segment)
            (incf insts-from-end))
          (note-resolved-dependencies segment inst)
          (push inst results)
          #!+sb-show-assem (format *trace-output* "emitting ~S~%" inst)
          (advance-one-inst segment))))

    ;; Keep scheduling stuff until we run out.
    (loop
      (let ((inst (schedule-one-inst segment nil)))
        (unless inst
          (return))
        (push inst results)
        (advance-one-inst segment)))

    ;; Now call the emitters, but turn the scheduler off for the duration.
    (setf (segment-run-scheduler segment) nil)
    (dolist (inst results)
      (if (eq inst :nop)
          (sb!c:emit-nop segment)
          (funcall (inst-emitter inst) segment)))
    (setf (segment-run-scheduler segment) t))

  ;; Clear out any residue left over.
  (setf (segment-inst-number segment) 0)
  (setf (segment-queued-branches segment) nil)
  (setf (segment-branch-countdown segment) nil)
  (setf (segment-emittable-insts-sset segment) (make-sset))
  (fill (segment-readers segment) nil)
  (fill (segment-writers segment) nil)

  ;; That's all, folks.
  (values))

;;; a utility for maintaining the segment-delayed list. We cdr down
;;; list n times (extending it if necessary) and then push thing on
;;; into the car of that cons cell.
(defun add-to-nth-list (list thing n)
  (do ((cell (or list (setf list (list nil)))
             (or (cdr cell) (setf (cdr cell) (list nil))))
       (i n (1- i)))
      ((zerop i)
       (push thing (car cell))
       list)))

;;; Find the next instruction to schedule and return it after updating
;;; any dependency information. If we can't do anything useful right
;;; now, but there is more work to be done, return :NOP to indicate
;;; that a nop must be emitted. If we are all done, return NIL.
(defun schedule-one-inst (segment delay-slot-p)
  (do ((prev nil remaining)
       (remaining (segment-emittable-insts-queue segment) (cdr remaining)))
      ((null remaining))
    (let ((inst (car remaining)))
      (unless (and delay-slot-p
                   (instruction-attributep (inst-attributes inst)
                                           variable-length))
        ;; We've got us a live one here. Go for it.
        #!+sb-show-assem (format *trace-output* "emitting ~S~%" inst)
        ;; Delete it from the list of insts.
        (if prev
            (setf (cdr prev) (cdr remaining))
            (setf (segment-emittable-insts-queue segment)
                  (cdr remaining)))
        ;; Note that this inst has been emitted.
        (note-resolved-dependencies segment inst)
        ;; And return.
        (return-from schedule-one-inst
                     ;; Are we wanting to flush this instruction?
                     (if (inst-emitter inst)
                         ;; Nope, it's still a go. So return it.
                         inst
                         ;; Yes, so pick a new one. We have to start
                         ;; over, because note-resolved-dependencies
                         ;; might have changed the emittable-insts-queue.
                         (schedule-one-inst segment delay-slot-p))))))
  ;; Nothing to do, so make something up.
  (cond ((segment-delayed segment)
         ;; No emittable instructions, but we have more work to do. Emit
         ;; a NOP to fill in a delay slot.
         #!+sb-show-assem (format *trace-output* "emitting a NOP~%")
         :nop)
        (t
         ;; All done.
         nil)))

;;; This function is called whenever an instruction has been
;;; scheduled, and we want to know what possibilities that opens up.
;;; So look at all the instructions that this one depends on, and
;;; remove this instruction from their dependents list. If we were the
;;; last dependent, then that dependency can be emitted now.
(defun note-resolved-dependencies (segment inst)
  (aver (sset-empty (inst-read-dependents inst)))
  (aver (sset-empty (inst-write-dependents inst)))
  (do-sset-elements (dep (inst-write-dependencies inst))
    ;; These are the instructions who have to be completed before our
    ;; write fires. Doesn't matter how far before, just before.
    (let ((dependents (inst-write-dependents dep)))
      (sset-delete inst dependents)
      (when (and (sset-empty dependents)
                 (sset-empty (inst-read-dependents dep)))
        (insert-emittable-inst segment dep))))
  (do-sset-elements (dep (inst-read-dependencies inst))
    ;; These are the instructions who write values we read. If there
    ;; is no delay, then just remove us from the dependent list.
    ;; Otherwise, record the fact that in n cycles, we should be
    ;; removed.
    (if (zerop (inst-delay dep))
        (let ((dependents (inst-read-dependents dep)))
          (sset-delete inst dependents)
          (when (and (sset-empty dependents)
                     (sset-empty (inst-write-dependents dep)))
            (insert-emittable-inst segment dep)))
        (setf (segment-delayed segment)
              (add-to-nth-list (segment-delayed segment)
                               (cons dep inst)
                               (inst-delay dep)))))
  (values))

;;; Process the next entry in segment-delayed. This is called whenever
;;; anyone emits an instruction.
(defun advance-one-inst (segment)
  (let ((delayed-stuff (pop (segment-delayed segment))))
    (dolist (stuff delayed-stuff)
      (if (consp stuff)
          (let* ((dependency (car stuff))
                 (dependent (cdr stuff))
                 (dependents (inst-read-dependents dependency)))
            (sset-delete dependent dependents)
            (when (and (sset-empty dependents)
                       (sset-empty (inst-write-dependents dependency)))
              (insert-emittable-inst segment dependency)))
          (insert-emittable-inst segment stuff)))))

;;; Note that inst is emittable by sticking it in the
;;; SEGMENT-EMITTABLE-INSTS-QUEUE list. We keep the emittable-insts
;;; sorted with the largest ``depths'' first. Except that if INST is a
;;; branch, don't bother. It will be handled correctly by the branch
;;; emitting code in SCHEDULE-PENDING-INSTRUCTIONS.
(defun insert-emittable-inst (segment inst)
  (unless (instruction-attributep (inst-attributes inst) branch)
    #!+sb-show-assem (format *trace-output* "now emittable: ~S~%" inst)
    (do ((my-depth (inst-depth inst))
         (remaining (segment-emittable-insts-queue segment) (cdr remaining))
         (prev nil remaining))
        ((or (null remaining) (> my-depth (inst-depth (car remaining))))
         (if prev
             (setf (cdr prev) (cons inst remaining))
             (setf (segment-emittable-insts-queue segment)
                   (cons inst remaining))))))
  (values))

;;;; structure used during output emission

;;; common supertype for all the different kinds of annotations
(def!struct (annotation (:constructor nil)
                        (:copier nil))
  ;; Where in the raw output stream was this annotation emitted?
  (index 0 :type index)
  ;; What position does that correspond to?
  (posn nil :type (or index null)))

(def!struct (label (:include annotation)
                   (:constructor gen-label ())
                   (:copier nil))
  ;; (doesn't need any additional information beyond what is in the
  ;; annotation structure)
  )
(sb!int:def!method print-object ((label label) stream)
  (if (or *print-escape* *print-readably*)
      (print-unreadable-object (label stream :type t)
        (prin1 (sb!c:label-id label) stream))
      (format stream "L~D" (sb!c:label-id label))))

;;; a constraint on how the output stream must be aligned
(def!struct (alignment-note (:include annotation)
                            (:conc-name alignment-)
                            (:predicate alignment-p)
                            (:constructor make-alignment (bits size fill-byte))
                            (:copier nil))
  ;; the minimum number of low-order bits that must be zero
  (bits 0 :type alignment)
  ;; the amount of filler we are assuming this alignment op will take
  (size 0 :type (integer 0 #.(1- (ash 1 max-alignment))))
  ;; the byte used as filling
  (fill-byte 0 :type (or assembly-unit (signed-byte #.assembly-unit-bits))))

;;; a reference to someplace that needs to be back-patched when
;;; we actually know what label positions, etc. are
(def!struct (back-patch (:include annotation)
                        (:constructor make-back-patch (size fun))
                        (:copier nil))
  ;; the area affected by this back-patch
  (size 0 :type index :read-only t)
  ;; the function to use to generate the real data
  (fun nil :type function :read-only t))

;;; This is similar to a BACK-PATCH, but also an indication that the
;;; amount of stuff output depends on label positions, etc.
;;; BACK-PATCHes can't change their mind about how much stuff to emit,
;;; but CHOOSERs can.
(def!struct (chooser (:include annotation)
                     (:constructor make-chooser
                                   (size alignment maybe-shrink worst-case-fun))
                     (:copier nil))
  ;; the worst case size for this chooser. There is this much space
  ;; allocated in the output buffer.
  (size 0 :type index :read-only t)
  ;; the worst case alignment this chooser is guaranteed to preserve
  (alignment 0 :type alignment :read-only t)
  ;; the function to call to determine if we can use a shorter
  ;; sequence. It returns NIL if nothing shorter can be used, or emits
  ;; that sequence and returns T.
  (maybe-shrink nil :type function :read-only t)
  ;; the function to call to generate the worst case sequence. This is
  ;; used when nothing else can be condensed.
  (worst-case-fun nil :type function :read-only t))

;;; This is used internally when we figure out a chooser or alignment
;;; doesn't really need as much space as we initially gave it.
(def!struct (filler (:include annotation)
                    (:constructor make-filler (bytes))
                    (:copier nil))
  ;; the number of bytes of filler here
  (bytes 0 :type index))

;;;; output functions

;;; interface: Emit the supplied BYTE to SEGMENT, growing SEGMENT if
;;; necessary.
(defun emit-byte (segment byte)
  (declare (type segment segment))
  (declare (type possibly-signed-assembly-unit byte))
  (let ((old-index (segment-current-index segment)))
    (incf (segment-current-index segment))
    (setf (aref (segment-buffer segment) old-index)
          (logand byte assembly-unit-mask)))
  (incf (segment-current-posn segment))
  (values))

;;; interface: Output AMOUNT copies of FILL-BYTE to SEGMENT.
(defun emit-skip (segment amount &optional (fill-byte 0))
  (declare (type segment segment)
           (type index amount))
  (dotimes (i amount)
    (emit-byte segment fill-byte))
  (values))

;;; This is used to handle the common parts of annotation emission. We
;;; just assign the POSN and INDEX of NOTE and tack it on to the end
;;; of SEGMENT's annotations list.
(defun emit-annotation (segment note)
  (declare (type segment segment)
           (type annotation note))
  (when (annotation-posn note)
    (error "attempt to emit ~S a second time" note))
  (setf (annotation-posn note) (segment-current-posn segment))
  (setf (annotation-index note) (segment-current-index segment))
  (let ((last (segment-last-annotation segment))
        (new (list note)))
    (setf (segment-last-annotation segment)
          (if last
              (setf (cdr last) new)
              (setf (segment-annotations segment) new))))
  (values))

;;; Note that the instruction stream has to be back-patched when label
;;; positions are finally known. SIZE bytes are reserved in SEGMENT,
;;; and function will be called with two arguments: the segment and
;;; the position. The function should look at the position and the
;;; position of any labels it wants to and emit the correct sequence.
;;; (And it better be the same size as SIZE). SIZE can be zero, which
;;; is useful if you just want to find out where things ended up.
(defun emit-back-patch (segment size function)
  (emit-annotation segment (make-back-patch size function))
  (emit-skip segment size))

;;; Note that the instruction stream here depends on the actual
;;; positions of various labels, so can't be output until label
;;; positions are known. Space is made in SEGMENT for at least SIZE
;;; bytes. When all output has been generated, the MAYBE-SHRINK
;;; functions for all choosers are called with three arguments: the
;;; segment, the position, and a magic value. The MAYBE-SHRINK
;;; decides if it can use a shorter sequence, and if so, emits that
;;; sequence to the segment and returns T. If it can't do better than
;;; the worst case, it should return NIL (without emitting anything).
;;; When calling LABEL-POSITION, it should pass it the position and
;;; the magic-value it was passed so that LABEL-POSITION can return
;;; the correct result. If the chooser never decides to use a shorter
;;; sequence, the WORST-CASE-FUN will be called, just like a
;;; BACK-PATCH. (See EMIT-BACK-PATCH.)
(defun emit-chooser (segment size alignment maybe-shrink worst-case-fun)
  (declare (type segment segment) (type index size) (type alignment alignment)
           (type function maybe-shrink worst-case-fun))
  (let ((chooser (make-chooser size alignment maybe-shrink worst-case-fun)))
    (emit-annotation segment chooser)
    (emit-skip segment size)
    (adjust-alignment-after-chooser segment chooser)))

;;; This is called in EMIT-CHOOSER and COMPRESS-SEGMENT in order to
;;; recompute the current alignment information in light of this
;;; chooser. If the alignment guaranteed by the chooser is less than
;;; the segment's current alignment, we have to adjust the segment's
;;; notion of the current alignment.
;;;
;;; The hard part is recomputing the sync posn, because it's not just
;;; the chooser's posn. Consider a chooser that emits either one or
;;; three words. It preserves 8-byte (3 bit) alignments, because the
;;; difference between the two choices is 8 bytes.
(defun adjust-alignment-after-chooser (segment chooser)
  (declare (type segment segment) (type chooser chooser))
  (let ((alignment (chooser-alignment chooser))
        (seg-alignment (segment-alignment segment)))
    (when (< alignment seg-alignment)
      ;; The chooser might change the alignment of the output. So we
      ;; have to figure out what the worst case alignment could be.
      (setf (segment-alignment segment) alignment)
      (let* ((posn (chooser-posn chooser))
             (sync-posn (segment-sync-posn segment))
             (offset (- posn sync-posn))
             (delta (logand offset (1- (ash 1 alignment)))))
        (setf (segment-sync-posn segment) (- posn delta)))))
  (values))

;;; This is used internally whenever a chooser or alignment decides it
;;; doesn't need as much space as it originally thought.
(defun emit-filler (segment n-bytes)
  (declare (type index n-bytes))
  (let ((last (segment-last-annotation segment)))
    (cond ((and last (filler-p (car last)))
           (incf (filler-bytes (car last)) n-bytes))
          (t
           (emit-annotation segment (make-filler n-bytes)))))
  (incf (segment-current-index segment) n-bytes)
  (values))

;;; EMIT-LABEL (the interface) basically just expands into this,
;;; supplying the SEGMENT and VOP.
(defun %emit-label (segment vop label)
  (when (segment-run-scheduler segment)
    (schedule-pending-instructions segment))
  (let ((postits (segment-postits segment)))
    (setf (segment-postits segment) nil)
    (dolist (postit postits)
      (emit-back-patch segment 0 postit)))
  (let ((hook (segment-inst-hook segment)))
    (when hook
      (funcall hook segment vop :label label)))
  (emit-annotation segment label))

;;; Called by the EMIT-ALIGNMENT macro to emit an alignment note. We check to
;;; see if we can guarantee the alignment restriction by just outputting a
;;; fixed number of bytes. If so, we do so. Otherwise, we create and emit an
;;; alignment note.
(defun %emit-alignment (segment vop bits &optional (fill-byte 0))
  (when (segment-run-scheduler segment)
    (schedule-pending-instructions segment))
  (let ((hook (segment-inst-hook segment)))
    (when hook
      (funcall hook segment vop :align bits)))
  (let ((alignment (segment-alignment segment))
        (offset (- (segment-current-posn segment)
                   (segment-sync-posn segment))))
    (cond ((> bits alignment)
           ;; We need more bits of alignment. First emit enough noise
           ;; to get back in sync with alignment, and then emit an
           ;; alignment note to cover the rest.
           (let ((slop (logand offset (1- (ash 1 alignment)))))
             (unless (zerop slop)
               (emit-skip segment (- (ash 1 alignment) slop) fill-byte)))
           (let ((size (logand (1- (ash 1 bits))
                               (lognot (1- (ash 1 alignment))))))
             (aver (> size 0))
             (emit-annotation segment (make-alignment bits size fill-byte))
             (emit-skip segment size fill-byte))
           (setf (segment-alignment segment) bits)
           (setf (segment-sync-posn segment) (segment-current-posn segment)))
          (t
           ;; The last alignment was more restrictive then this one.
           ;; So we can just figure out how much noise to emit
           ;; assuming the last alignment was met.
           (let* ((mask (1- (ash 1 bits)))
                  (new-offset (logand (+ offset mask) (lognot mask))))
             (emit-skip segment (- new-offset offset) fill-byte))
           ;; But we emit an alignment with size=0 so we can verify
           ;; that everything works.
           (emit-annotation segment (make-alignment bits 0 fill-byte)))))
  (values))

;;; This is used to find how ``aligned'' different offsets are.
;;; Returns the number of low-order 0 bits, up to MAX-ALIGNMENT.
(defun find-alignment (offset)
  (dotimes (i max-alignment max-alignment)
    (when (logbitp i offset)
      (return i))))

;;; Emit a postit. The function will be called as a back-patch with
;;; the position the following instruction is finally emitted. Postits
;;; do not interfere at all with scheduling.
(defun %emit-postit (segment function)
  (push function (segment-postits segment))
  (values))

;;;; output compression/position assignment stuff

;;; Grovel though all the annotations looking for choosers. When we
;;; find a chooser, invoke the maybe-shrink function. If it returns T,
;;; it output some other byte sequence.
(defun compress-output (segment)
  (dotimes (i 5) ; it better not take more than one or two passes.
    (let ((delta 0))
      (setf (segment-alignment segment) max-alignment)
      (setf (segment-sync-posn segment) 0)
      (do* ((prev nil)
            (remaining (segment-annotations segment) next)
            (next (cdr remaining) (cdr remaining)))
           ((null remaining))
        (let* ((note (car remaining))
               (posn (annotation-posn note)))
          (unless (zerop delta)
            (decf posn delta)
            (setf (annotation-posn note) posn))
          (cond
           ((chooser-p note)
            (with-modified-segment-index-and-posn (segment (chooser-index note)
                                                           posn)
              (setf (segment-last-annotation segment) prev)
              (cond
               ((funcall (chooser-maybe-shrink note) segment posn delta)
                ;; It emitted some replacement.
                (let ((new-size (- (segment-current-index segment)
                                   (chooser-index note)))
                      (old-size (chooser-size note)))
                  (when (> new-size old-size)
                    (error "~S emitted ~W bytes, but claimed its max was ~W."
                           note new-size old-size))
                  (let ((additional-delta (- old-size new-size)))
                    (when (< (find-alignment additional-delta)
                             (chooser-alignment note))
                      (error "~S shrunk by ~W bytes, but claimed that it ~
                              preserves ~W bits of alignment."
                             note additional-delta (chooser-alignment note)))
                    (incf delta additional-delta)
                    (emit-filler segment additional-delta))
                  (setf prev (segment-last-annotation segment))
                  (if prev
                      (setf (cdr prev) (cdr remaining))
                      (setf (segment-annotations segment)
                            (cdr remaining)))))
               (t
                ;; The chooser passed on shrinking. Make sure it didn't
                ;; emit anything.
                (unless (= (segment-current-index segment)
                           (chooser-index note))
                  (error "Chooser ~S passed, but not before emitting ~W bytes."
                         note
                         (- (segment-current-index segment)
                            (chooser-index note))))
                ;; Act like we just emitted this chooser.
                (let ((size (chooser-size note)))
                  (incf (segment-current-index segment) size)
                  (incf (segment-current-posn segment) size))
                ;; Adjust the alignment accordingly.
                (adjust-alignment-after-chooser segment note)
                ;; And keep this chooser for next time around.
                (setf prev remaining)))))
           ((alignment-p note)
            (unless (zerop (alignment-size note))
              ;; Re-emit the alignment, letting it collapse if we know
              ;; anything more about the alignment guarantees of the
              ;; segment.
              (let ((index (alignment-index note)))
                (with-modified-segment-index-and-posn (segment index posn)
                  (setf (segment-last-annotation segment) prev)
                  (%emit-alignment segment nil (alignment-bits note)
                                   (alignment-fill-byte note))
                  (let* ((new-index (segment-current-index segment))
                         (size (- new-index index))
                         (old-size (alignment-size note))
                         (additional-delta (- old-size size)))
                    (when (minusp additional-delta)
                      (error "Alignment ~S needs more space now?  It was ~W, ~
                              and is ~W now."
                             note old-size size))
                    (when (plusp additional-delta)
                      (emit-filler segment additional-delta)
                      (incf delta additional-delta)))
                  (setf prev (segment-last-annotation segment))
                  (if prev
                      (setf (cdr prev) (cdr remaining))
                      (setf (segment-annotations segment)
                            (cdr remaining)))))))
           (t
            (setf prev remaining)))))
      (when (zerop delta)
        (return))
      (decf (segment-final-posn segment) delta)))
  (values))

;;; We have run all the choosers we can, so now we have to figure out
;;; exactly how much space each alignment note needs.
(defun finalize-positions (segment)
  (let ((delta 0))
    (do* ((prev nil)
          (remaining (segment-annotations segment) next)
          (next (cdr remaining) (cdr remaining)))
         ((null remaining))
      (let* ((note (car remaining))
             (posn (- (annotation-posn note) delta)))
        (cond
         ((alignment-p note)
          (let* ((bits (alignment-bits note))
                 (mask (1- (ash 1 bits)))
                 (new-posn (logand (+ posn mask) (lognot mask)))
                 (size (- new-posn posn))
                 (old-size (alignment-size note))
                 (additional-delta (- old-size size)))
            (aver (<= 0 size old-size))
            (unless (zerop additional-delta)
              (setf (segment-last-annotation segment) prev)
              (incf delta additional-delta)
              (with-modified-segment-index-and-posn (segment
                                                     (alignment-index note)
                                                     posn)
                (emit-filler segment additional-delta)
                (setf prev (segment-last-annotation segment))
                (if prev
                    (setf (cdr prev) next)
                    (setf (segment-annotations segment) next))))))
         (t
          (setf (annotation-posn note) posn)
          (setf prev remaining)
          (setf next (cdr remaining))))))
    (unless (zerop delta)
      (decf (segment-final-posn segment) delta)))
  (values))

;;; Grovel over segment, filling in any backpatches. If any choosers
;;; are left over, we need to emit their worst case variant.
(defun process-back-patches (segment)
  (do* ((prev nil)
        (remaining (segment-annotations segment) next)
        (next (cdr remaining) (cdr remaining)))
      ((null remaining))
    (let ((note (car remaining)))
      (flet ((fill-in (function old-size)
               (let ((index (annotation-index note))
                     (posn (annotation-posn note)))
                 (with-modified-segment-index-and-posn (segment index posn)
                   (setf (segment-last-annotation segment) prev)
                   (funcall function segment posn)
                   (let ((new-size (- (segment-current-index segment) index)))
                     (unless (= new-size old-size)
                       (error "~S emitted ~W bytes, but claimed it was ~W."
                              note new-size old-size)))
                   (let ((tail (segment-last-annotation segment)))
                     (if tail
                         (setf (cdr tail) next)
                         (setf (segment-annotations segment) next)))
                   (setf next (cdr prev))))))
        (cond ((back-patch-p note)
               (fill-in (back-patch-fun note)
                        (back-patch-size note)))
              ((chooser-p note)
               (fill-in (chooser-worst-case-fun note)
                        (chooser-size note)))
              (t
               (setf prev remaining)))))))

;;;; interface to the rest of the compiler

;;; This holds the current segment while assembling. Use ASSEMBLE to
;;; change it.
;;;
;;; The double asterisks in the name are intended to suggest that this
;;; isn't just any old special variable, it's an extra-special
;;; variable, because sometimes MACROLET is used to bind it. So be
;;; careful out there..
;;;
;;; (This used to be called **CURRENT-SEGMENT** in SBCL until 0.7.3,
;;; and just *CURRENT-SEGMENT* in CMU CL. In both cases, the rebinding
;;; now done with MACROLET was done with SYMBOL-MACROLET instead. The
;;; rename-with-double-asterisks was because the SYMBOL-MACROLET made
;;; it an extra-special variable. The change over to
;;; %%CURRENT-SEGMENT%% was because ANSI forbids the use of
;;; SYMBOL-MACROLET on special variable names, and CLISP correctly
;;; complains about this when being used as a bootstrap host.)
(defmacro %%current-segment%% () '**current-segment**)
(defvar **current-segment**)

;;; Just like %%CURRENT-SEGMENT%%, except this holds the current vop.
;;; This is used only to keep track of which vops emit which insts.
;;;
;;; The double asterisks in the name are intended to suggest that this
;;; isn't just any old special variable, it's an extra-special
;;; variable, because sometimes MACROLET is used to bind it. So be
;;; careful out there..
(defmacro %%current-vop%% () '**current-vop**)
(defvar **current-vop** nil)

;;; We also MACROLET %%CURRENT-SEGMENT%% to a local holding the
;;; segment so uses of %%CURRENT-SEGMENT%% inside the body don't have
;;; to keep dereferencing the symbol. Given that ASSEMBLE is the only
;;; interface to **CURRENT-SEGMENT**, we don't have to worry about the
;;; special value becomming out of sync with the lexical value. Unless
;;; some bozo closes over it, but nobody does anything like that...
;;;
;;; FIXME: The way this macro uses MACROEXPAND internally breaks my
;;; old assumptions about macros which are needed both in the host and
;;; the target. (This is more or less the same way that PUSH-IN,
;;; DELETEF-IN, and !DEF-BOOLEAN-ATTRIBUTE break my old assumptions,
;;; except that they used GET-SETF-EXPANSION instead of MACROEXPAND to
;;; do the dirty deed.) The quick and dirty "solution" here is the
;;; same as there: use cut and paste to duplicate the defmacro in a
;;; (SB!INT:DEF!MACRO FOO (..) .. CL:MACROEXPAND ..) #+SB-XC-HOST
;;; (DEFMACRO FOO (..) .. SB!XC:MACROEXPAND ..) idiom. This is
;;; disgusting and unmaintainable, and there are obviously better
;;; solutions and maybe even good solutions, but I'm disinclined to
;;; hunt for good solutions until the system works and I can test them
;;; in isolation.
;;;
;;; The above comment remains true, except that instead of a cut-and-paste
;;; copy we now have a macrolet. This is charitably called progress.
;;; -- NS 2008-09-19
(macrolet
    ((def (defmacro macroexpand)
       `(,defmacro assemble ((&optional segment vop &key labels) &body body
                             &environment env)
          #!+sb-doc
          "Execute BODY (as a progn) with SEGMENT as the current segment."
          (flet ((label-name-p (thing)
                   (and thing (symbolp thing))))
            (let* ((seg-var (gensym "SEGMENT-"))
                   (vop-var (gensym "VOP-"))
                   (visible-labels (remove-if-not #'label-name-p body))
                   (inherited-labels
                    (multiple-value-bind (expansion expanded)
                        (,macroexpand '..inherited-labels.. env)
                      (if expanded expansion nil)))
                   (new-labels (append labels
                                       (set-difference visible-labels
                                                       inherited-labels)))
                   (nested-labels (set-difference (append inherited-labels new-labels)
                                                  visible-labels)))
              (when (intersection labels inherited-labels)
                (error "duplicate nested labels: ~S"
                       (intersection labels inherited-labels)))
              `(let* ((,seg-var ,(or segment '(%%current-segment%%)))
                      (,vop-var ,(or vop '(%%current-vop%%)))
                      ,@(when segment
                              `((**current-segment** ,seg-var)))
                      ,@(when vop
                              `((**current-vop** ,vop-var)))
                      ,@(mapcar (lambda (name)
                                  `(,name (gen-label)))
                                new-labels))
                 (declare (ignorable ,vop-var ,seg-var)
                          ;; Must be done so that contribs and user code doing
                          ;; low-level stuff don't need to worry about this.
                          (disable-package-locks %%current-segment%% %%current-vop%%))
                 (macrolet ((%%current-segment%% () ',seg-var)
                            (%%current-vop%% () ',vop-var))
                   ;; KLUDGE: Some host lisps (CMUCL 18e Sparc at least)
                   ;; can't deal with this declaration, so disable it on host.
                   ;; Ditto for later ENABLE-PACKAGE-LOCKS %%C-S%% declaration.
                   #-sb-xc-host
                   (declare (enable-package-locks %%current-segment%% %%current-vop%%))
                   (symbol-macrolet (,@(when (or inherited-labels nested-labels)
                                             `((..inherited-labels.. ,nested-labels))))
                     ,@(mapcar (lambda (form)
                                 (if (label-name-p form)
                                     `(emit-label ,form)
                                     form))
                               body)))))))))
  (def sb!int:def!macro macroexpand)
  #+sb-xc-host
  (def sb!xc:defmacro %macroexpand))

(defmacro inst (&whole whole instruction &rest args &environment env)
  #!+sb-doc
  "Emit the specified instruction to the current segment."
  (let ((inst (gethash (symbol-name instruction) *assem-instructions*)))
    (cond ((null inst)
           (error "unknown instruction: ~S" instruction))
          ((functionp inst)
           (funcall inst (cdr whole) env))
          (t
           `(,inst (%%current-segment%%) (%%current-vop%%) ,@args)))))

;;; Note: The need to capture MACROLET bindings of %%CURRENT-SEGMENT%%
;;; and %%CURRENT-VOP%% prevents this from being an ordinary function.
(defmacro emit-label (label)
  #!+sb-doc
  "Emit LABEL at this location in the current segment."
  `(%emit-label (%%current-segment%%) (%%current-vop%%) ,label))

;;; Note: The need to capture MACROLET bindings of
;;; %%CURRENT-SEGMENT%% prevents this from being an ordinary function.
(defmacro emit-postit (function)
  `(%emit-postit (%%current-segment%%) ,function))

;;; Note: The need to capture SYMBOL-MACROLET bindings of
;;; **CURRENT-SEGMENT* and (%%CURRENT-VOP%%) prevents this from being an
;;; ordinary function.
(defmacro emit-alignment (bits &optional (fill-byte 0))
  #!+sb-doc
  "Emit an alignment restriction to the current segment."
  `(%emit-alignment (%%current-segment%%) (%%current-vop%%) ,bits ,fill-byte))

(defun label-position (label &optional if-after delta)
  #!+sb-doc
  "Return the current position for LABEL. Chooser maybe-shrink functions
   should supply IF-AFTER and DELTA in order to ensure correct results."
  (let ((posn (label-posn label)))
    (if (and if-after (> posn if-after))
        (- posn delta)
        posn)))

(defun append-segment (segment other-segment)
  #!+sb-doc
  "Append OTHER-SEGMENT to the end of SEGMENT. Don't use OTHER-SEGMENT
   for anything after this."
  (when (segment-run-scheduler segment)
    (schedule-pending-instructions segment))
  (let ((postits (segment-postits segment)))
    (setf (segment-postits segment) (segment-postits other-segment))
    (dolist (postit postits)
      (emit-back-patch segment 0 postit)))
  #!-(or x86 x86-64)
  (%emit-alignment segment nil max-alignment)
  #!+(or x86 x86-64)
  (unless (eq :elsewhere (segment-type other-segment))
    (%emit-alignment segment nil max-alignment))
  (let ((segment-current-index-0 (segment-current-index segment))
        (segment-current-posn-0  (segment-current-posn  segment)))
    (incf (segment-current-index segment)
          (segment-current-index other-segment))
    (replace (segment-buffer segment)
             (segment-buffer other-segment)
             :start1 segment-current-index-0)
    (setf (segment-buffer other-segment) nil) ; to prevent accidental reuse
    (incf (segment-current-posn segment)
          (segment-current-posn other-segment))
    (let ((other-annotations (segment-annotations other-segment)))
      (when other-annotations
        (dolist (note other-annotations)
          (incf (annotation-index note) segment-current-index-0)
          (incf (annotation-posn note) segment-current-posn-0))
        ;; This SEGMENT-LAST-ANNOTATION code is confusing. Is it really
        ;; worth enough in efficiency to justify it? -- WHN 19990322
        (let ((last (segment-last-annotation segment)))
          (if last
              (setf (cdr last) other-annotations)
              (setf (segment-annotations segment) other-annotations)))
        (setf (segment-last-annotation segment)
              (segment-last-annotation other-segment)))))
  (values))

(defun finalize-segment (segment)
  #!+sb-doc
  "Do any final processing of SEGMENT and return the total number of bytes
   covered by this segment."
  (when (segment-run-scheduler segment)
    (schedule-pending-instructions segment))
  (setf (segment-run-scheduler segment) nil)
  (let ((postits (segment-postits segment)))
    (setf (segment-postits segment) nil)
    (dolist (postit postits)
      (emit-back-patch segment 0 postit)))
  (setf (segment-final-index segment) (segment-current-index segment))
  (setf (segment-final-posn segment) (segment-current-posn segment))
  (setf (segment-inst-hook segment) nil)
  (compress-output segment)
  (finalize-positions segment)
  (process-back-patches segment)
  (segment-final-posn segment))

;;; Call FUNCTION on all the stuff accumulated in SEGMENT. FUNCTION
;;; should accept a single vector argument. It will be called zero or
;;; more times on vectors of the appropriate byte type. The
;;; concatenation of the vector arguments from all the calls is the
;;; contents of SEGMENT.
;;;
;;; KLUDGE: This implementation is sort of slow and gross, calling
;;; FUNCTION repeatedly and consing a fresh vector for its argument
;;; each time. It might be possible to make a more efficient version
;;; by making FINALIZE-SEGMENT do all the compacting currently done by
;;; this function: then this function could become trivial and fast,
;;; calling FUNCTION once on the entire compacted segment buffer. --
;;; WHN 19990322
(defun on-segment-contents-vectorly (segment function)
  (declare (type function function))
  (let ((buffer (segment-buffer segment))
        (i0 0))
    (declare (type (simple-array (unsigned-byte 8)) buffer))
    (flet ((frob (i0 i1)
             (when (< i0 i1)
               (funcall function (subseq buffer i0 i1)))))
      (dolist (note (segment-annotations segment))
        (when (filler-p note)
          (let ((i1 (filler-index note)))
            (frob i0 i1)
            (setf i0 (+ i1 (filler-bytes note))))))
      (frob i0 (segment-final-index segment))))
  (values))

;;; Write the code accumulated in SEGMENT to STREAM, and return the
;;; number of bytes written.
(defun write-segment-contents (segment stream)
  (let ((result 0))
    (declare (type index result))
    (on-segment-contents-vectorly segment
                                  (lambda (v)
                                    (declare (type (vector assembly-unit) v))
                                    (incf result (length v))
                                    (write-sequence v stream)))
    result))

;;;; interface to the instruction set definition

;;; Define a function named NAME that merges its arguments into a
;;; single integer and then emits the bytes of that integer in the
;;; correct order based on the endianness of the target-backend.
(defmacro define-bitfield-emitter (name total-bits &rest byte-specs)
  (sb!int:collect ((arg-names) (arg-types))
    (let* ((total-bits (eval total-bits))
           (overall-mask (ash -1 total-bits))
           (num-bytes (multiple-value-bind (quo rem)
                          (truncate total-bits assembly-unit-bits)
                        (unless (zerop rem)
                          (error "~W isn't an even multiple of ~W."
                                 total-bits assembly-unit-bits))
                        quo))
           (bytes (make-array num-bytes :initial-element nil))
           (segment-arg (sb!xc:gensym "SEGMENT-")))
      (dolist (byte-spec-expr byte-specs)
        (let* ((byte-spec (eval byte-spec-expr))
               (byte-size (byte-size byte-spec))
               (byte-posn (byte-position byte-spec))
               (arg (sb!xc:gensym (format nil "~:@(ARG-FOR-~S-~)" byte-spec-expr))))
          (when (ldb-test (byte byte-size byte-posn) overall-mask)
            (error "The byte spec ~S either overlaps another byte spec, or ~
                    extends past the end."
                   byte-spec-expr))
          (setf (ldb byte-spec overall-mask) -1)
          (arg-names arg)
          (arg-types `(type (integer ,(ash -1 (1- byte-size))
                                     ,(1- (ash 1 byte-size)))
                            ,arg))
          (multiple-value-bind (start-byte offset)
              (floor byte-posn assembly-unit-bits)
            (let ((end-byte (floor (1- (+ byte-posn byte-size))
                                   assembly-unit-bits)))
              (flet ((maybe-ash (expr offset)
                       (if (zerop offset)
                           expr
                           `(ash ,expr ,offset))))
                (declare (inline maybe-ash))
                (cond ((zerop byte-size))
                      ((= start-byte end-byte)
                       (push (maybe-ash `(ldb (byte ,byte-size 0) ,arg)
                                        offset)
                             (svref bytes start-byte)))
                      (t
                       (push (maybe-ash
                              `(ldb (byte ,(- assembly-unit-bits offset) 0)
                                    ,arg)
                              offset)
                             (svref bytes start-byte))
                       (do ((index (1+ start-byte) (1+ index)))
                           ((>= index end-byte))
                         (push
                          `(ldb (byte ,assembly-unit-bits
                                      ,(- (* assembly-unit-bits
                                             (- index start-byte))
                                          offset))
                                ,arg)
                          (svref bytes index)))
                       (let ((len (rem (+ byte-size offset)
                                       assembly-unit-bits)))
                         (push
                          `(ldb (byte ,(if (zerop len)
                                           assembly-unit-bits
                                           len)
                                      ,(- (* assembly-unit-bits
                                             (- end-byte start-byte))
                                          offset))
                                ,arg)
                          (svref bytes end-byte))))))))))
      (unless (= overall-mask -1)
        (error "There are holes."))
      (let ((forms nil))
        (dotimes (i num-bytes)
          (let ((pieces (svref bytes i)))
            (aver pieces)
            (push `(emit-byte ,segment-arg
                              ,(if (cdr pieces)
                                   `(logior ,@pieces)
                                   (car pieces)))
                  forms)))
        `(defun ,name (,segment-arg ,@(arg-names))
           (declare (type segment ,segment-arg) ,@(arg-types))
           ,@(ecase sb!c:*backend-byte-order*
               (:little-endian (nreverse forms))
               (:big-endian forms))
           ',name)))))

(defun grovel-lambda-list (lambda-list vop-var)
  (let ((segment-name (car lambda-list))
        (vop-var (or vop-var (sb!xc:gensym "VOP"))))
    (sb!int:collect ((new-lambda-list))
      (new-lambda-list segment-name)
      (new-lambda-list vop-var)
      (labels
          ((grovel (state lambda-list)
             (when lambda-list
               (let ((param (car lambda-list)))
                 (cond
                  ((member param sb!xc:lambda-list-keywords)
                   (new-lambda-list param)
                   (grovel param (cdr lambda-list)))
                  (t
                   (ecase state
                     ((nil)
                      (new-lambda-list param)
                      `(cons ,param ,(grovel state (cdr lambda-list))))
                     (&optional
                      (multiple-value-bind (name default supplied-p)
                          (if (consp param)
                              (values (first param)
                                      (second param)
                                      (or (third param)
                                          (sb!xc:gensym "SUPPLIED-P-")))
                              (values param nil (sb!xc:gensym "SUPPLIED-P-")))
                        (new-lambda-list (list name default supplied-p))
                        `(and ,supplied-p
                              (cons ,(if (consp name)
                                         (second name)
                                         name)
                                    ,(grovel state (cdr lambda-list))))))
                     (&key
                      (multiple-value-bind (name default supplied-p)
                          (if (consp param)
                              (values (first param)
                                      (second param)
                                      (or (third param)
                                          (sb!xc:gensym "SUPPLIED-P-")))
                              (values param nil (sb!xc:gensym "SUPPLIED-P-")))
                        (new-lambda-list (list name default supplied-p))
                        (multiple-value-bind (key var)
                            (if (consp name)
                                (values (first name) (second name))
                                (values (keywordicate name) name))
                          `(append (and ,supplied-p (list ',key ,var))
                                   ,(grovel state (cdr lambda-list))))))
                     (&rest
                      (new-lambda-list param)
                      (grovel state (cdr lambda-list))
                      param))))))))
        (let ((reconstructor (grovel nil (cdr lambda-list))))
          (values (new-lambda-list)
                  segment-name
                  vop-var
                  reconstructor))))))

(defun extract-nths (index glue list-of-lists-of-lists)
  (mapcar (lambda (list-of-lists)
            (cons glue
                  (mapcar (lambda (list)
                            (nth index list))
                          list-of-lists)))
          list-of-lists-of-lists))

(defmacro define-instruction (name lambda-list &rest options)
  (let* ((sym-name (symbol-name name))
         (defun-name (sb!int:symbolicate sym-name "-INST-EMITTER"))
         (vop-var nil)
         (postits (gensym "POSTITS-"))
         (emitter nil)
         (decls nil)
         (attributes nil)
         (cost nil)
         (dependencies nil)
         (delay nil)
         (pinned nil)
         (pdefs nil))
    (sb!int:/noshow "entering DEFINE-INSTRUCTION" name lambda-list options)
    (dolist (option-spec options)
      (sb!int:/noshow option-spec)
      (multiple-value-bind (option args)
          (if (consp option-spec)
              (values (car option-spec) (cdr option-spec))
              (values option-spec nil))
        (sb!int:/noshow option args)
        (case option
          (:emitter
           (when emitter
             (error "You can only specify :EMITTER once per instruction."))
           (setf emitter args))
          (:declare
           (setf decls (append decls args)))
          (:attributes
           (setf attributes (append attributes args)))
          (:cost
           (setf cost (first args)))
          (:dependencies
           (setf dependencies (append dependencies args)))
          (:delay
           (when delay
             (error "You can only specify :DELAY once per instruction."))
           (setf delay args))
          (:pinned
           (setf pinned t))
          (:vop-var
           (if vop-var
               (error "You can only specify :VOP-VAR once per instruction.")
               (setf vop-var (car args))))
          (:printer
           (sb!int:/noshow "uniquifying :PRINTER with" args)
           (push (eval `(list (multiple-value-list
                               ,(sb!disassem:gen-printer-def-forms-def-form
                                 name
                                 (let ((*print-right-margin* 1000))
                                   (format nil "~@:(~A[~A]~)" name args))
                                 (cdr option-spec)))))
                 pdefs))
          (:printer-list
           ;; same as :PRINTER, but is EVALed first, and is a list of
           ;; printers
           (push
            (eval
             `(eval
               `(list ,@(mapcar (lambda (printer)
                                  `(multiple-value-list
                                    ,(sb!disassem:gen-printer-def-forms-def-form
                                      ',name
                                      (let ((*print-right-margin* 1000))
                                        (format nil "~@:(~A[~A]~)" ',name printer))
                                      printer
                                      nil)))
                                ,(cadr option-spec)))))
            pdefs))
          (t
           (error "unknown option: ~S" option)))))
    (sb!int:/noshow "done processing options")
    (setf pdefs (nreverse pdefs))
    (multiple-value-bind
        (new-lambda-list segment-name vop-name arg-reconstructor)
        (grovel-lambda-list lambda-list vop-var)
      (sb!int:/noshow new-lambda-list segment-name vop-name arg-reconstructor)
      (push `(let ((hook (segment-inst-hook ,segment-name)))
               (when hook
                 (funcall hook ,segment-name ,vop-name ,sym-name
                          ,arg-reconstructor)))
            emitter)
      (push `(dolist (postit ,postits)
               (emit-back-patch ,segment-name 0 postit))
            emitter)
      (unless cost (setf cost 1))
      #!+sb-dyncount
      (push `(when (segment-collect-dynamic-statistics ,segment-name)
               (let* ((info (sb!c:ir2-component-dyncount-info
                             (sb!c:component-info
                              sb!c:*component-being-compiled*)))
                      (costs (sb!c:dyncount-info-costs info))
                      (block-number (sb!c:block-number
                                     (sb!c:ir2-block-block
                                      (sb!c:vop-block ,vop-name)))))
                 (incf (aref costs block-number) ,cost)))
            emitter)
      (when *assem-scheduler-p*
        (if pinned
            (setf emitter
                  `((when (segment-run-scheduler ,segment-name)
                      (schedule-pending-instructions ,segment-name))
                    ,@emitter))
            (let ((flet-name
                   (gensym (concatenate 'string "EMIT-" sym-name "-INST-")))
                  (inst-name (gensym "INST-")))
              (setf emitter `((flet ((,flet-name (,segment-name)
                                       ,@emitter))
                                (if (segment-run-scheduler ,segment-name)
                                    (let ((,inst-name
                                           (make-instruction
                                            (incf (segment-inst-number
                                                   ,segment-name))
                                            #',flet-name
                                            (instruction-attributes
                                             ,@attributes)
                                            (progn ,@delay))))
                                      ,@(when dependencies
                                          `((note-dependencies
                                                (,segment-name ,inst-name)
                                              ,@dependencies)))
                                      (queue-inst ,segment-name ,inst-name))
                                    (,flet-name ,segment-name))))))))
      `(progn
         (defun ,defun-name ,new-lambda-list
           ,@(when decls
               `((declare ,@decls)))
           (let ((,postits (segment-postits ,segment-name)))
             ;; Must be done so that contribs and user code doing
             ;; low-level stuff don't need to worry about this.
             (declare (disable-package-locks %%current-segment%%))
             (setf (segment-postits ,segment-name) nil)
             (macrolet ((%%current-segment%% ()
                          (error "You can't use INST without an ~
                                  ASSEMBLE inside emitters.")))
               ;; KLUDGE: Some host lisps (CMUCL 18e Sparc at least)
               ;; can't deal with this declaration, so disable it on host
               ;; Ditto for earlier ENABLE-PACKAGE-LOCKS %%C-S%% %%C-V%%
               ;; declaration.
               #-sb-xc-host
               (declare (enable-package-locks %%current-segment%%))
               ,@emitter))
           (values))
         (eval-when (:compile-toplevel :load-toplevel :execute)
           (%define-instruction ,sym-name ',defun-name))
         ,@(extract-nths 1 'progn pdefs)
         ,@(when pdefs
             `((sb!disassem:install-inst-flavors
                ',name
                (append ,@(extract-nths 0 'list pdefs)))))))))

(defmacro define-instruction-macro (name lambda-list &body body)
  (with-unique-names (whole env)
    (multiple-value-bind (body local-defs)
        (sb!kernel:parse-defmacro lambda-list whole body name
                                  'instruction-macro
                                  :environment env)
      `(eval-when (:compile-toplevel :load-toplevel :execute)
         (%define-instruction ,(symbol-name name)
                              (lambda (,whole ,env)
                                ,@local-defs
                                (block ,name
                                  ,body)))))))

(defun %define-instruction (name defun)
  (setf (gethash name *assem-instructions*) defun)
  name)
