;;;; This file implements local call analysis. A local call is a
;;;; function call between functions being compiled at the same time.
;;;; If we can tell at compile time that such a call is legal, then we
;;;; change the combination to call the correct lambda, mark it as
;;;; local, and add this link to our call graph. Once a call is local,
;;;; it is then eligible for let conversion, which places the body of
;;;; the function inline.
;;;;
;;;; We cannot always do a local call even when we do have the
;;;; function being called. Calls that cannot be shown to have legal
;;;; arg counts are not converted.

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; This software is derived from the CMU CL system, which was
;;;; written at Carnegie Mellon University and released into the
;;;; public domain. The software is in the public domain and is
;;;; provided with absolutely no warranty. See the COPYING and CREDITS
;;;; files for more information.

(in-package "SB!C")

;;; This function propagates information from the variables in the
;;; function FUN to the actual arguments in CALL. This is also called
;;; by the VALUES IR1 optimizer when it sleazily converts MV-BINDs to
;;; LETs.
;;;
;;; We flush all arguments to CALL that correspond to unreferenced
;;; variables in FUN. We leave NILs in the COMBINATION-ARGS so that
;;; the remaining args still match up with their vars.
;;;
;;; We also apply the declared variable type assertion to the argument
;;; lvars.
(defun propagate-to-args (call fun)
  (declare (type combination call) (type clambda fun))
  (loop with policy = (lexenv-policy (node-lexenv call))
        for args on (basic-combination-args call)
        and var in (lambda-vars fun)
        do (assert-lvar-type (car args) (leaf-type var) policy)
        do (unless (leaf-refs var)
             (flush-dest (car args))
             (setf (car args) nil)))
  (values))

(defun recognize-dynamic-extent-lvars (call fun)
  (declare (type combination call) (type clambda fun))
  (loop for arg in (basic-combination-args call)
        for var in (lambda-vars fun)
        for dx = (leaf-dynamic-extent var)
        when (and dx arg (not (lvar-dynamic-extent arg)))
        append (handle-nested-dynamic-extent-lvars dx arg) into dx-lvars
        finally (when dx-lvars
                  ;; Stack analysis requires that the CALL ends the block, so
                  ;; that MAP-BLOCK-NLXES sees the cleanup we insert here.
                  (node-ends-block call)
                  (let* ((entry (with-ir1-environment-from-node call
                                  (make-entry)))
                         (cleanup (make-cleanup :kind :dynamic-extent
                                                :mess-up entry
                                                :info dx-lvars)))
                    (setf (entry-cleanup entry) cleanup)
                    (insert-node-before call entry)
                    (setf (node-lexenv call)
                          (make-lexenv :default (node-lexenv call)
                                       :cleanup cleanup))
                    (push entry (lambda-entries (node-home-lambda entry)))
                    (dolist (cell dx-lvars)
                      (setf (lvar-dynamic-extent (cdr cell)) cleanup)))))
  (values))

;;; This function handles merging the tail sets if CALL is potentially
;;; tail-recursive, and is a call to a function with a different
;;; TAIL-SET than CALL's FUN. This must be called whenever we alter
;;; IR1 so as to place a local call in what might be a tail-recursive
;;; context. Note that any call which returns its value to a RETURN is
;;; considered potentially tail-recursive, since any implicit MV-PROG1
;;; might be optimized away.
;;;
;;; We destructively modify the set for the calling function to
;;; represent both, and then change all the functions in callee's set
;;; to reference the first. If we do merge, we reoptimize the
;;; RETURN-RESULT lvar to cause IR1-OPTIMIZE-RETURN to recompute the
;;; tail set type.
(defun merge-tail-sets (call &optional (new-fun (combination-lambda call)))
  (declare (type basic-combination call) (type clambda new-fun))
  (let ((return (node-dest call)))
    (when (return-p return)
      (let ((call-set (lambda-tail-set (node-home-lambda call)))
            (fun-set (lambda-tail-set new-fun)))
        (unless (eq call-set fun-set)
          (let ((funs (tail-set-funs fun-set)))
            (dolist (fun funs)
              (setf (lambda-tail-set fun) call-set))
            (setf (tail-set-funs call-set)
                  (nconc (tail-set-funs call-set) funs)))
          (reoptimize-lvar (return-result return))
          t)))))

;;; Convert a combination into a local call. We PROPAGATE-TO-ARGS, set
;;; the combination kind to :LOCAL, add FUN to the CALLS of the
;;; function that the call is in, call MERGE-TAIL-SETS, then replace
;;; the function in the REF node with the new function.
;;;
;;; We change the REF last, since changing the reference can trigger
;;; LET conversion of the new function, but will only do so if the
;;; call is local. Note that the replacement may trigger LET
;;; conversion or other changes in IR1. We must call MERGE-TAIL-SETS
;;; with NEW-FUN before the substitution, since after the substitution
;;; (and LET conversion), the call may no longer be recognizable as
;;; tail-recursive.
(defun convert-call (ref call fun)
  (declare (type ref ref) (type combination call) (type clambda fun))
  (propagate-to-args call fun)
  (setf (basic-combination-kind call) :local)
  (unless (call-full-like-p call)
    (dolist (arg (basic-combination-args call))
      (when arg
        (flush-lvar-externally-checkable-type arg))))
  (sset-adjoin fun (lambda-calls-or-closes (node-home-lambda call)))
  (recognize-dynamic-extent-lvars call fun)
  (merge-tail-sets call fun)
  (change-ref-leaf ref fun)
  (values))

;;;; external entry point creation

;;; Return a LAMBDA form that can be used as the definition of the XEP
;;; for FUN.
;;;
;;; If FUN is a LAMBDA, then we check the number of arguments
;;; (conditional on policy) and call FUN with all the arguments.
;;;
;;; If FUN is an OPTIONAL-DISPATCH, then we dispatch off of the number
;;; of supplied arguments by doing do an = test for each entry-point,
;;; calling the entry with the appropriate prefix of the passed
;;; arguments.
;;;
;;; If there is a &MORE arg, then there are a couple of optimizations
;;; that we make (more for space than anything else):
;;; -- If MIN-ARGS is 0, then we make the more entry a T clause, since
;;;    no argument count error is possible.
;;; -- We can omit the = clause for the last entry-point, allowing the
;;;    case of 0 more args to fall through to the more entry.
;;;
;;; We don't bother to policy conditionalize wrong arg errors in
;;; optional dispatches, since the additional overhead is negligible
;;; compared to the cost of everything else going on.
;;;
;;; Note that if policy indicates it, argument type declarations in
;;; FUN will be verified. Since nothing is known about the type of the
;;; XEP arg vars, type checks will be emitted when the XEP's arg vars
;;; are passed to the actual function.
(defun make-xep-lambda-expression (fun)
  (declare (type functional fun))
  (etypecase fun
    (clambda
     (let ((nargs (length (lambda-vars fun)))
           (n-supplied (gensym))
           (temps (make-gensym-list (length (lambda-vars fun)))))
       `(lambda (,n-supplied ,@temps)
          (declare (type index ,n-supplied))
          ,(if (policy *lexenv* (zerop verify-arg-count))
               `(declare (ignore ,n-supplied))
               `(%verify-arg-count ,n-supplied ,nargs))
          (locally
            (declare (optimize (merge-tail-calls 3)))
            (%funcall ,fun ,@temps)))))
    (optional-dispatch
     (let* ((min (optional-dispatch-min-args fun))
            (max (optional-dispatch-max-args fun))
            (more (optional-dispatch-more-entry fun))
            (n-supplied (gensym))
            (temps (make-gensym-list max)))
       (collect ((entries))
         ;; Force convertion of all entries
         (optional-dispatch-entry-point-fun fun 0)
         (loop for ep in (optional-dispatch-entry-points fun)
               and n from min
               do (entries `((eql ,n-supplied ,n)
                             (%funcall ,(force ep) ,@(subseq temps 0 n)))))
         `(lambda (,n-supplied ,@temps)
            (declare (type index ,n-supplied))
            (cond
             ,@(if more (butlast (entries)) (entries))
             ,@(when more
                 ;; KLUDGE: (NOT (< ...)) instead of >= avoids one round of
                 ;; deftransforms and lambda-conversion.
                 `((,(if (zerop min) t `(not (< ,n-supplied ,max)))
                    ,(with-unique-names (n-context n-count)
                       `(multiple-value-bind (,n-context ,n-count)
                            (%more-arg-context ,n-supplied ,max)
                          (locally
                            (declare (optimize (merge-tail-calls 3)))
                            (%funcall ,more ,@temps ,n-context ,n-count)))))))
             (t
              (%arg-count-error ,n-supplied)))))))))

;;; Make an external entry point (XEP) for FUN and return it. We
;;; convert the result of MAKE-XEP-LAMBDA in the correct environment,
;;; then associate this lambda with FUN as its XEP. After the
;;; conversion, we iterate over the function's associated lambdas,
;;; redoing local call analysis so that the XEP calls will get
;;; converted.
;;;
;;; We set REANALYZE and REOPTIMIZE in the component, just in case we
;;; discover an XEP after the initial local call analyze pass.
(defun make-xep (fun)
  (declare (type functional fun))
  (aver (null (functional-entry-fun fun)))
  (with-ir1-environment-from-node (lambda-bind (main-entry fun))
    (let ((xep (ir1-convert-lambda (make-xep-lambda-expression fun)
                                   :debug-name (debug-name
                                                'xep (leaf-debug-name fun))
                                   :system-lambda t)))
      (setf (functional-kind xep) :external
            (leaf-ever-used xep) t
            (functional-entry-fun xep) fun
            (functional-entry-fun fun) xep
            (component-reanalyze *current-component*) t)
      (reoptimize-component *current-component* :maybe)
      (locall-analyze-xep-entry-point fun)
      xep)))

(defun locall-analyze-xep-entry-point (fun)
  (declare (type functional fun))
  (etypecase fun
    (clambda
     (locall-analyze-fun-1 fun))
    (optional-dispatch
     (dolist (ep (optional-dispatch-entry-points fun))
       (locall-analyze-fun-1 (force ep)))
     (when (optional-dispatch-more-entry fun)
       (locall-analyze-fun-1 (optional-dispatch-more-entry fun))))))

;;; Notice a REF that is not in a local-call context. If the REF is
;;; already to an XEP, then do nothing, otherwise change it to the
;;; XEP, making an XEP if necessary.
;;;
;;; If REF is to a special :CLEANUP or :ESCAPE function, then we treat
;;; it as though it was not an XEP reference (i.e. leave it alone).
(defun reference-entry-point (ref)
  (declare (type ref ref))
  (let ((fun (ref-leaf ref)))
    (unless (or (xep-p fun)
                (member (functional-kind fun) '(:escape :cleanup)))
      (change-ref-leaf ref (or (functional-entry-fun fun)
                               (make-xep fun))))))

;;; Attempt to convert all references to FUN to local calls. The
;;; reference must be the function for a call, and the function lvar
;;; must be used only once, since otherwise we cannot be sure what
;;; function is to be called. The call lvar would be multiply used if
;;; there is hairy stuff such as conditionals in the expression that
;;; computes the function.
;;;
;;; If we cannot convert a reference, then we mark the referenced
;;; function as an entry-point, creating a new XEP if necessary. We
;;; don't try to convert calls that are in error (:ERROR kind.)
;;;
;;; This is broken off from LOCALL-ANALYZE-COMPONENT so that people
;;; can force analysis of newly introduced calls. Note that we don't
;;; do LET conversion here.
(defun locall-analyze-fun-1 (fun)
  (declare (type functional fun))
  (let ((refs (leaf-refs fun))
        (local-p t))
    (dolist (ref refs)
      (let* ((lvar (node-lvar ref))
             (dest (when lvar (lvar-dest lvar))))
        (unless (node-to-be-deleted-p ref)
          (cond ((and (basic-combination-p dest)
                      (eq (basic-combination-fun dest) lvar)
                      (eq (lvar-uses lvar) ref))

                 (convert-call-if-possible ref dest)

                 (unless (eq (basic-combination-kind dest) :local)
                   (reference-entry-point ref)
                   (setq local-p nil)))
                (t
                 (reference-entry-point ref)
                 (setq local-p nil))))))
    (when local-p (note-local-functional fun)))

  (values))

;;; We examine all NEW-FUNCTIONALS in COMPONENT, attempting to convert
;;; calls into local calls when it is legal. We also attempt to
;;; convert each LAMBDA to a LET. LET conversion is also triggered by
;;; deletion of a function reference, but functions that start out
;;; eligible for conversion must be noticed sometime.
;;;
;;; Note that there is a lot of action going on behind the scenes
;;; here, triggered by reference deletion. In particular, the
;;; COMPONENT-LAMBDAS are being hacked to remove newly deleted and LET
;;; converted LAMBDAs, so it is important that the LAMBDA is added to
;;; the COMPONENT-LAMBDAS when it is. Also, the
;;; COMPONENT-NEW-FUNCTIONALS may contain all sorts of drivel, since
;;; it is not updated when we delete functions, etc. Only
;;; COMPONENT-LAMBDAS is updated.
;;;
;;; COMPONENT-REANALYZE-FUNCTIONALS is treated similarly to
;;; COMPONENT-NEW-FUNCTIONALS, but we don't add lambdas to the
;;; LAMBDAS.
(defun locall-analyze-component (component)
  (declare (type component component))
  (aver-live-component component)
  (loop
    (let* ((new-functional (pop (component-new-functionals component)))
           (functional (or new-functional
                           (pop (component-reanalyze-functionals component)))))
      (unless functional
        (return))
      (let ((kind (functional-kind functional)))
        (cond ((or (functional-somewhat-letlike-p functional)
                   (memq kind '(:deleted :zombie)))
               (values)) ; nothing to do
              ((and (null (leaf-refs functional)) (eq kind nil)
                    (not (functional-entry-fun functional)))
               (delete-functional functional))
              (t
               ;; Fix/check FUNCTIONAL's relationship to COMPONENT-LAMDBAS.
               (cond ((not (lambda-p functional))
                      ;; Since FUNCTIONAL isn't a LAMBDA, this doesn't
                      ;; apply: no-op.
                      (values))
                     (new-functional ; FUNCTIONAL came from
                                     ; NEW-FUNCTIONALS, hence is new.
                      ;; FUNCTIONAL becomes part of COMPONENT-LAMBDAS now.
                      (aver (not (member functional
                                         (component-lambdas component))))
                      (push functional (component-lambdas component)))
                     (t ; FUNCTIONAL is old.
                      ;; FUNCTIONAL should be in COMPONENT-LAMBDAS already.
                      (aver (member functional (component-lambdas
                                                component)))))
               (locall-analyze-fun-1 functional)
               (when (lambda-p functional)
                 (maybe-let-convert functional)))))))
  (values))

(defun locall-analyze-clambdas-until-done (clambdas)
  (loop
   (let ((did-something nil))
     (dolist (clambda clambdas)
       (let ((component (lambda-component clambda)))
         ;; The original CMU CL code seemed to implicitly assume that
         ;; COMPONENT is the only one here. Let's make that explicit.
         (aver (= 1 (length (functional-components clambda))))
         (aver (eql component (first (functional-components clambda))))
         (when (or (component-new-functionals component)
                   (component-reanalyze-functionals component))
           (setf did-something t)
           (locall-analyze-component component))))
     (unless did-something
       (return))))
  (values))

;;; If policy is auspicious and CALL is not in an XEP and we don't seem
;;; to be in an infinite recursive loop, then change the reference to
;;; reference a fresh copy. We return whichever function we decide to
;;; reference.
(defun maybe-expand-local-inline (original-functional ref call)
  (if (and (policy call
                   (and (>= speed space)
                        (>= speed compilation-speed)))
           (not (eq (functional-kind (node-home-lambda call)) :external))
           (inline-expansion-ok call))
      (let* ((end (component-last-block (node-component call)))
             (pred (block-prev end)))
        (multiple-value-bind (losing-local-object converted-lambda)
            (catch 'locall-already-let-converted
              (with-ir1-environment-from-node call
                (let ((*lexenv* (functional-lexenv original-functional)))
                  (values nil
                          (ir1-convert-lambda
                           (functional-inline-expansion original-functional)
                           :debug-name (debug-name 'local-inline
                                                   (leaf-debug-name
                                                    original-functional)))))))
          (cond (losing-local-object
                 (if (functional-p losing-local-object)
                     (let ((*compiler-error-context* call))
                       (compiler-notify "couldn't inline expand because expansion ~
                                         calls this LET-converted local function:~
                                         ~%  ~S"
                                        (leaf-debug-name losing-local-object)))
                     (let ((*compiler-error-context* call))
                       (compiler-notify "implementation limitation: couldn't inline ~
                                         expand because expansion refers to ~
                                         the optimized away object ~S."
                                        losing-local-object)))
                 (loop for block = (block-next pred) then (block-next block)
                       until (eq block end)
                       do (setf (block-delete-p block) t))
                 (loop for block = (block-next pred) then (block-next block)
                       until (eq block end)
                       do (delete-block block t))
                 original-functional)
                (t
                 (change-ref-leaf ref converted-lambda)
                 converted-lambda))))
      original-functional))

;;; Dispatch to the appropriate function to attempt to convert a call.
;;; REF must be a reference to a FUNCTIONAL. This is called in IR1
;;; optimization as well as in local call analysis. If the call is is
;;; already :LOCAL, we do nothing. If the call is already scheduled
;;; for deletion, also do nothing (in addition to saving time, this
;;; also avoids some problems with optimizing collections of functions
;;; that are partially deleted.)
;;;
;;; This is called both before and after FIND-INITIAL-DFO runs. When
;;; called on a :INITIAL component, we don't care whether the caller
;;; and callee are in the same component. Afterward, we must stick
;;; with whatever component division we have chosen.
;;;
;;; Before attempting to convert a call, we see whether the function
;;; is supposed to be inline expanded. Call conversion proceeds as
;;; before after any expansion.
;;;
;;; We bind *COMPILER-ERROR-CONTEXT* to the node for the call so that
;;; warnings will get the right context.
(defun convert-call-if-possible (ref call)
  (declare (type ref ref) (type basic-combination call))
  (let* ((block (node-block call))
         (component (block-component block))
         (original-fun (ref-leaf ref)))
    (aver (functional-p original-fun))
    (unless (or (member (basic-combination-kind call) '(:local :error))
                (node-to-be-deleted-p call)
                (member (functional-kind original-fun)
                        '(:toplevel-xep :deleted))
                (not (or (eq (component-kind component) :initial)
                         (eq (block-component
                              (node-block
                               (lambda-bind (main-entry original-fun))))
                             component))))
      (let ((fun (if (xep-p original-fun)
                     (functional-entry-fun original-fun)
                     original-fun))
            (*compiler-error-context* call))

        (when (and (eq (functional-inlinep fun) :inline)
                   (rest (leaf-refs original-fun)))
          (setq fun (maybe-expand-local-inline fun ref call)))

        (aver (member (functional-kind fun)
                      '(nil :escape :cleanup :optional)))
        (cond ((mv-combination-p call)
               (convert-mv-call ref call fun))
              ((lambda-p fun)
               (convert-lambda-call ref call fun))
              (t
               (convert-hairy-call ref call fun))))))

  (values))

;;; Attempt to convert a multiple-value call. The only interesting
;;; case is a call to a function that LOOKS-LIKE-AN-MV-BIND, has
;;; exactly one reference and no XEP, and is called with one values
;;; lvar.
;;;
;;; We change the call to be to the last optional entry point and
;;; change the call to be local. Due to our preconditions, the call
;;; should eventually be converted to a let, but we can't do that now,
;;; since there may be stray references to the e-p lambda due to
;;; optional defaulting code.
;;;
;;; We also use variable types for the called function to construct an
;;; assertion for the values lvar.
;;;
;;; See CONVERT-CALL for additional notes on MERGE-TAIL-SETS, etc.
(defun convert-mv-call (ref call fun)
  (declare (type ref ref) (type mv-combination call) (type functional fun))
  (when (and (looks-like-an-mv-bind fun)
             (singleton-p (leaf-refs fun))
             (singleton-p (basic-combination-args call))
             (not (functional-entry-fun fun)))
    (let* ((*current-component* (node-component ref))
           (ep (optional-dispatch-entry-point-fun
                fun (optional-dispatch-max-args fun))))
      (when (null (leaf-refs ep))
        (aver (= (optional-dispatch-min-args fun) 0))
        (setf (basic-combination-kind call) :local)
        (sset-adjoin ep (lambda-calls-or-closes (node-home-lambda call)))
        (merge-tail-sets call ep)
        (change-ref-leaf ref ep)

        (assert-lvar-type
         (first (basic-combination-args call))
         (make-short-values-type (mapcar #'leaf-type (lambda-vars ep)))
         (lexenv-policy (node-lexenv call))))))
  (values))

;;; Attempt to convert a call to a lambda. If the number of args is
;;; wrong, we give a warning and mark the call as :ERROR to remove it
;;; from future consideration. If the argcount is O.K. then we just
;;; convert it.
(defun convert-lambda-call (ref call fun)
  (declare (type ref ref) (type combination call) (type clambda fun))
  (let ((nargs (length (lambda-vars fun)))
        (n-call-args (length (combination-args call))))
    (cond ((= n-call-args nargs)
           (convert-call ref call fun))
          (t
           (warn
            'local-argument-mismatch
            :format-control
            "function called with ~R argument~:P, but wants exactly ~R"
            :format-arguments (list n-call-args nargs))
           (setf (basic-combination-kind call) :error)))))

;;;; &OPTIONAL, &MORE and &KEYWORD calls

;;; This is similar to CONVERT-LAMBDA-CALL, but deals with
;;; OPTIONAL-DISPATCHes. If only fixed args are supplied, then convert
;;; a call to the correct entry point. If &KEY args are supplied, then
;;; dispatch to a subfunction. We don't convert calls to functions
;;; that have a &MORE (or &REST) arg.
(defun convert-hairy-call (ref call fun)
  (declare (type ref ref) (type combination call)
           (type optional-dispatch fun))
  (let ((min-args (optional-dispatch-min-args fun))
        (max-args (optional-dispatch-max-args fun))
        (call-args (length (combination-args call))))
    (cond ((< call-args min-args)
           (warn
            'local-argument-mismatch
            :format-control
            "function called with ~R argument~:P, but wants at least ~R"
            :format-arguments (list call-args min-args))
           (setf (basic-combination-kind call) :error))
          ((<= call-args max-args)
           (convert-call ref call
                         (let ((*current-component* (node-component ref)))
                           (optional-dispatch-entry-point-fun
                            fun (- call-args min-args)))))
          ((optional-dispatch-more-entry fun)
           (convert-more-call ref call fun))
          (t
           (warn
            'local-argument-mismatch
            :format-control
            "function called with ~R argument~:P, but wants at most ~R"
            :format-arguments
            (list call-args max-args))
           (setf (basic-combination-kind call) :error))))
  (values))

;;; This function is used to convert a call to an entry point when
;;; complex transformations need to be done on the original arguments.
;;; ENTRY is the entry point function that we are calling. VARS is a
;;; list of variable names which are bound to the original call
;;; arguments. IGNORES is the subset of VARS which are ignored. ARGS
;;; is the list of arguments to the entry point function.
;;;
;;; In order to avoid gruesome graph grovelling, we introduce a new
;;; function that rearranges the arguments and calls the entry point.
;;; We analyze the new function and the entry point immediately so
;;; that everything gets converted during the single pass.
(defun convert-hairy-fun-entry (ref call entry vars ignores args indef)
  (declare (list vars ignores args) (type ref ref) (type combination call)
           (type clambda entry))
  (let ((new-fun
         (with-ir1-environment-from-node call
           (ir1-convert-lambda
            `(lambda ,vars
               (declare (ignorable ,@ignores)
                        (indefinite-extent ,@indef))
               (%funcall ,entry ,@args))
            :debug-name (debug-name 'hairy-function-entry
                                    (lvar-fun-debug-name
                                     (basic-combination-fun call)))
            :system-lambda t))))
    (convert-call ref call new-fun)
    (dolist (ref (leaf-refs entry))
      (convert-call-if-possible ref (lvar-dest (node-lvar ref))))))

;;; Use CONVERT-HAIRY-FUN-ENTRY to convert a &MORE-arg call to a known
;;; function into a local call to the MAIN-ENTRY.
;;;
;;; First we verify that all keywords are constant and legal. If there
;;; aren't, then we warn the user and don't attempt to convert the call.
;;;
;;; We massage the supplied &KEY arguments into the order expected
;;; by the main entry. This is done by binding all the arguments to
;;; the keyword call to variables in the introduced lambda, then
;;; passing these values variables in the correct order when calling
;;; the main entry. Unused arguments (such as the keywords themselves)
;;; are discarded simply by not passing them along.
;;;
;;; If there is a &REST arg, then we bundle up the args and pass them
;;; to LIST.
(defun convert-more-call (ref call fun)
  (declare (type ref ref) (type combination call) (type optional-dispatch fun))
  (let* ((max (optional-dispatch-max-args fun))
         (arglist (optional-dispatch-arglist fun))
         (args (combination-args call))
         (more (nthcdr max args))
         (flame (policy call (or (> speed inhibit-warnings)
                                 (> space inhibit-warnings))))
         (loser nil)
         (allowp nil)
         (allow-found nil)
         (temps (make-gensym-list max))
         (more-temps (make-gensym-list (length more))))
    (collect ((ignores)
              (supplied)
              (key-vars))

      (dolist (var arglist)
        (let ((info (lambda-var-arg-info var)))
          (when info
            (ecase (arg-info-kind info)
              (:keyword
               (key-vars var))
              ((:rest :optional))
              ((:more-context :more-count)
               (compiler-warn "can't local-call functions with &MORE args")
               (setf (basic-combination-kind call) :error)
               (return-from convert-more-call))))))

      (when (optional-dispatch-keyp fun)
        (when (oddp (length more))
          (compiler-warn "function called with odd number of ~
                          arguments in keyword portion")
          (setf (basic-combination-kind call) :error)
          (return-from convert-more-call))

        (do ((key more (cddr key))
             (temp more-temps (cddr temp)))
            ((null key))
          (let ((lvar (first key)))
            (unless (constant-lvar-p lvar)
              (when flame
                (compiler-notify "non-constant keyword in keyword call"))
              (setf (basic-combination-kind call) :error)
              (return-from convert-more-call))

            (let ((name (lvar-value lvar))
                  (dummy (first temp))
                  (val (second temp)))
              (when (and (eq name :allow-other-keys) (not allow-found))
                (let ((val (second key)))
                  (cond ((constant-lvar-p val)
                         (setq allow-found t
                               allowp (lvar-value val)))
                        (t (when flame
                             (compiler-notify "non-constant :ALLOW-OTHER-KEYS value"))
                           (setf (basic-combination-kind call) :error)
                           (return-from convert-more-call)))))
              (dolist (var (key-vars)
                           (progn
                             (ignores dummy val)
                             (unless (eq name :allow-other-keys)
                               (setq loser (list name)))))
                (let ((info (lambda-var-arg-info var)))
                  (when (eq (arg-info-key info) name)
                      (ignores dummy)
                      (if (member var (supplied) :key #'car)
                          (ignores val)
                          (supplied (cons var val)))
                      (return)))))))

        (when (and loser (not (optional-dispatch-allowp fun)) (not allowp))
          (compiler-warn "function called with unknown argument keyword ~S"
                         (car loser))
          (setf (basic-combination-kind call) :error)
          (return-from convert-more-call)))

      (collect ((call-args))
        (do ((var arglist (cdr var))
             (temp temps (cdr temp)))
            ((null var))
          (let ((info (lambda-var-arg-info (car var))))
            (if info
                (ecase (arg-info-kind info)
                  (:optional
                   (call-args (car temp))
                   (when (arg-info-supplied-p info)
                     (call-args t)))
                  (:rest
                   (call-args `(list ,@more-temps))
                   ;; &REST arguments may be accompanied by extra
                   ;; context and count arguments. We know this by
                   ;; the ARG-INFO-DEFAULT. Supply NIL and 0 or
                   ;; don't convert at all depending.
                   (let ((more (arg-info-default info)))
                     (when more
                       (unless (eq t more)
                         (destructuring-bind (context count &optional used) more
                           (declare (ignore context count))
                           (when used
                             ;; We've already converted to use the more context
                             ;; instead of the rest list.
                             (return-from convert-more-call))))
                       (call-args nil)
                       (call-args 0)
                       (setf (arg-info-default info) t)))
                   (return))
                  (:keyword
                   (return)))
                (call-args (car temp)))))

        (dolist (var (key-vars))
          (let ((info (lambda-var-arg-info var))
                (temp (cdr (assoc var (supplied)))))
            (if temp
                (call-args temp)
                (call-args (arg-info-default info)))
            (when (arg-info-supplied-p info)
              (call-args (not (null temp))))))

        (convert-hairy-fun-entry ref call (optional-dispatch-main-entry fun)
                                 (append temps more-temps)
                                 (ignores) (call-args)
                                 more-temps))))

  (values))

;;;; LET conversion
;;;;
;;;; Converting to a LET has differing significance to various parts
;;;; of the compiler:
;;;; -- The body of a LET is spliced in immediately after the
;;;;    corresponding combination node, making the control transfer
;;;;    explicit and allowing LETs to be mashed together into a single
;;;;    block. The value of the LET is delivered directly to the
;;;;    original lvar for the call, eliminating the need to
;;;;    propagate information from the dummy result lvar.
;;;; -- As far as IR1 optimization is concerned, it is interesting in
;;;;    that there is only one expression that the variable can be bound
;;;;    to, and this is easily substituted for.
;;;; -- LETs are interesting to environment analysis and to the back
;;;;    end because in most ways a LET can be considered to be "the
;;;;    same function" as its home function.
;;;; -- LET conversion has dynamic scope implications, since control
;;;;    transfers within the same environment are local. In a local
;;;;    control transfer, cleanup code must be emitted to remove
;;;;    dynamic bindings that are no longer in effect.

;;; Set up the control transfer to the called CLAMBDA. We split the
;;; call block immediately after the call, and link the head of
;;; CLAMBDA to the call block. The successor block after splitting
;;; (where we return to) is returned.
;;;
;;; If the lambda is is a different component than the call, then we
;;; call JOIN-COMPONENTS. This only happens in block compilation
;;; before FIND-INITIAL-DFO.
(defun insert-let-body (clambda call)
  (declare (type clambda clambda) (type basic-combination call))
  (let* ((call-block (node-block call))
         (bind-block (node-block (lambda-bind clambda)))
         (component (block-component call-block)))
    (aver-live-component component)
    (let ((clambda-component (block-component bind-block)))
      (unless (eq clambda-component component)
        (aver (eq (component-kind component) :initial))
        (join-components component clambda-component)))
    (let ((*current-component* component))
      (node-ends-block call))
    (destructuring-bind (next-block)
        (block-succ call-block)
      (unlink-blocks call-block next-block)
      (link-blocks call-block bind-block)
      next-block)))

;;; Remove CLAMBDA from the tail set of anything it used to be in the
;;; same set as; but leave CLAMBDA with a valid tail set value of
;;; its own, for the benefit of code which might try to pull
;;; something out of it (e.g. return type).
(defun depart-from-tail-set (clambda)
  ;; Until sbcl-0.pre7.37.flaky5.2, we did
  ;;   (LET ((TAILS (LAMBDA-TAIL-SET CLAMBDA)))
  ;;     (SETF (TAIL-SET-FUNS TAILS)
  ;;           (DELETE CLAMBDA (TAIL-SET-FUNS TAILS))))
  ;;   (SETF (LAMBDA-TAIL-SET CLAMBDA) NIL)
  ;; here. Apparently the idea behind the (SETF .. NIL) was that since
  ;; TAIL-SET-FUNS no longer thinks we're in the tail set, it's
  ;; inconsistent, and perhaps unsafe, for us to think we're in the
  ;; tail set. Unfortunately..
  ;;
  ;; The (SETF .. NIL) caused problems in sbcl-0.pre7.37.flaky5.2 when
  ;; I was trying to get Python to emit :EXTERNAL LAMBDAs directly
  ;; (instead of only being able to emit funny little :TOPLEVEL stubs
  ;; which you called in order to get the address of an external LAMBDA):
  ;; the external function was defined in terms of internal function,
  ;; which was LET-converted, and then things blew up downstream when
  ;; FINALIZE-XEP-DEFINITION tried to find out its DEFINED-TYPE from
  ;; the now-NILed-out TAIL-SET. So..
  ;;
  ;; To deal with this problem, we no longer NIL out
  ;; (LAMBDA-TAIL-SET CLAMBDA) here. Instead:
  ;;   * If we're the only function in TAIL-SET-FUNS, it should
  ;;     be safe to leave ourself linked to it, and it to you.
  ;;   * If there are other functions in TAIL-SET-FUNS, then we're
  ;;     afraid of future optimizations on those functions causing
  ;;     the TAIL-SET object no longer to be valid to describe our
  ;;     return value. Thus, we delete ourselves from that object;
  ;;     but we save a newly-allocated tail-set, derived from the old
  ;;     one, for ourselves, for the use of later code (e.g.
  ;;     FINALIZE-XEP-DEFINITION) which might want to
  ;;     know about our return type.
  (let* ((old-tail-set (lambda-tail-set clambda))
         (old-tail-set-funs (tail-set-funs old-tail-set)))
    (unless (= 1 (length old-tail-set-funs))
      (setf (tail-set-funs old-tail-set)
            (delete clambda old-tail-set-funs))
      (let ((new-tail-set (copy-tail-set old-tail-set)))
        (setf (lambda-tail-set clambda) new-tail-set
              (tail-set-funs new-tail-set) (list clambda)))))
  ;; The documentation on TAIL-SET-INFO doesn't tell whether it could
  ;; remain valid in this case, so we nuke it on the theory that
  ;; missing information tends to be less dangerous than incorrect
  ;; information.
  (setf (tail-set-info (lambda-tail-set clambda)) nil))

;;; Handle the PHYSENV semantics of LET conversion. We add CLAMBDA and
;;; its LETs to LETs for the CALL's home function. We merge the calls
;;; for CLAMBDA with the calls for the home function, removing CLAMBDA
;;; in the process. We also merge the ENTRIES.
;;;
;;; We also unlink the function head from the component head and set
;;; COMPONENT-REANALYZE to true to indicate that the DFO should be
;;; recomputed.
(defun merge-lets (clambda call)

  (declare (type clambda clambda) (type basic-combination call))

  (let ((component (node-component call)))
    (unlink-blocks (component-head component) (lambda-block clambda))
    (setf (component-lambdas component)
          (delete clambda (component-lambdas component)))
    (setf (component-reanalyze component) t))
  (setf (lambda-call-lexenv clambda) (node-lexenv call))

  (depart-from-tail-set clambda)

  (let* ((home (node-home-lambda call))
         (home-physenv (lambda-physenv home))
         (physenv (lambda-physenv clambda)))

    (aver (not (eq home clambda)))

    ;; CLAMBDA belongs to HOME now.
    (push clambda (lambda-lets home))
    (setf (lambda-home clambda) home)
    (setf (lambda-physenv clambda) home-physenv)

    (when physenv
      (unless home-physenv
        (setf home-physenv (get-lambda-physenv home)))
      (setf (physenv-nlx-info home-physenv)
            (nconc (physenv-nlx-info physenv)
                   (physenv-nlx-info home-physenv))))

    ;; All of CLAMBDA's LETs belong to HOME now.
    (let ((lets (lambda-lets clambda)))
      (dolist (let lets)
        (setf (lambda-home let) home)
        (setf (lambda-physenv let) home-physenv))
      (setf (lambda-lets home) (nconc lets (lambda-lets home))))
    ;; CLAMBDA no longer has an independent existence as an entity
    ;; which has LETs.
    (setf (lambda-lets clambda) nil)

    ;; HOME no longer calls CLAMBDA, and owns all of CLAMBDA's old
    ;; DFO dependencies.
    (sset-union (lambda-calls-or-closes home)
                (lambda-calls-or-closes clambda))
    (sset-delete clambda (lambda-calls-or-closes home))
    ;; CLAMBDA no longer has an independent existence as an entity
    ;; which calls things or has DFO dependencies.
    (setf (lambda-calls-or-closes clambda) nil)

    ;; All of CLAMBDA's ENTRIES belong to HOME now.
    (setf (lambda-entries home)
          (nconc (lambda-entries clambda)
                 (lambda-entries home)))
    ;; CLAMBDA no longer has an independent existence as an entity
    ;; with ENTRIES.
    (setf (lambda-entries clambda) nil))

  (values))

;;; Handle the value semantics of LET conversion. Delete FUN's return
;;; node, and change the control flow to transfer to NEXT-BLOCK
;;; instead. Move all the uses of the result lvar to CALL's lvar.
(defun move-return-uses (fun call next-block)
  (declare (type clambda fun) (type basic-combination call)
           (type cblock next-block))
  (let* ((return (lambda-return fun))
         (return-block (progn
                         (ensure-block-start (node-prev return))
                         (node-block return))))
    (unlink-blocks return-block
                   (component-tail (block-component return-block)))
    (link-blocks return-block next-block)
    (unlink-node return)
    (delete-return return)
    (let ((result (return-result return))
          (lvar (if (node-tail-p call)
                    (return-result (lambda-return (node-home-lambda call)))
                    (node-lvar call)))
          (call-type (node-derived-type call)))
      (unless (eq call-type *wild-type*)
        ;; FIXME: Replace the call with unsafe CAST. -- APD, 2003-01-26
        (do-uses (use result)
          (derive-node-type use call-type)))
      (substitute-lvar-uses lvar result
                            (and lvar (eq (lvar-uses lvar) call)))))
  (values))

;;; We are converting FUN to be a LET when the call is in a non-tail
;;; position. Any previously tail calls in FUN are no longer tail
;;; calls, and must be restored to normal calls which transfer to
;;; NEXT-BLOCK (FUN's return point.) We can't do this by DO-USES on
;;; the RETURN-RESULT, because the return might have been deleted (if
;;; all calls were TR.)
(defun unconvert-tail-calls (fun call next-block)
  (do-sset-elements (called (lambda-calls-or-closes fun))
    (when (lambda-p called)
      (dolist (ref (leaf-refs called))
        (let ((this-call (node-dest ref)))
          (when (and this-call
                     (node-tail-p this-call)
                     (eq (node-home-lambda this-call) fun))
            (setf (node-tail-p this-call) nil)
            (ecase (functional-kind called)
              ((nil :cleanup :optional)
               (let ((block (node-block this-call))
                     (lvar (node-lvar call)))
                 (unlink-blocks block (first (block-succ block)))
                 (link-blocks block next-block)
                 (aver (not (node-lvar this-call)))
                 (add-lvar-use this-call lvar)))
              (:deleted)
              ;; The called function might be an assignment in the
              ;; case where we are currently converting that function.
              ;; In steady-state, assignments never appear as a called
              ;; function.
              (:assignment
               (aver (eq called fun)))))))))
  (values))

;;; Deal with returning from a LET or assignment that we are
;;; converting. FUN is the function we are calling, CALL is a call to
;;; FUN, and NEXT-BLOCK is the return point for a non-tail call, or
;;; NULL if call is a tail call.
;;;
;;; If the call is not a tail call, then we must do
;;; UNCONVERT-TAIL-CALLS, since a tail call is a call which returns
;;; its value out of the enclosing non-let function. When call is
;;; non-TR, we must convert it back to an ordinary local call, since
;;; the value must be delivered to the receiver of CALL's value.
;;;
;;; We do different things depending on whether the caller and callee
;;; have returns left:

;;; -- If the callee has no return we just do MOVE-LET-CALL-CONT.
;;;    Either the function doesn't return, or all returns are via
;;;    tail-recursive local calls.
;;; -- If CALL is a non-tail call, or if both have returns, then
;;;    we delete the callee's return, move its uses to the call's
;;;    result lvar, and transfer control to the appropriate
;;;    return point.
;;; -- If the callee has a return, but the caller doesn't, then we
;;;    move the return to the caller.
(defun move-return-stuff (fun call next-block)
  (declare (type clambda fun) (type basic-combination call)
           (type (or cblock null) next-block))
  (when next-block
    (unconvert-tail-calls fun call next-block))
  (let* ((return (lambda-return fun))
         (call-fun (node-home-lambda call))
         (call-return (lambda-return call-fun)))
    (when (and call-return
               (block-delete-p (node-block call-return)))
      (delete-return call-return)
      (unlink-node call-return)
      (setq call-return nil))
    (cond ((not return))
          ((or next-block call-return)
           (unless (block-delete-p (node-block return))
             (unless next-block
               (ensure-block-start (node-prev call-return))
               (setq next-block (node-block call-return)))
             (move-return-uses fun call next-block)))
          (t
           (aver (node-tail-p call))
           (setf (lambda-return call-fun) return)
           (setf (return-lambda return) call-fun)
           (setf (lambda-return fun) nil))))
  (%delete-lvar-use call) ; LET call does not have value semantics
  (values))

;;; Actually do LET conversion. We call subfunctions to do most of the
;;; work. We do REOPTIMIZE-LVAR on the args and CALL's lvar so that
;;; LET-specific IR1 optimizations get a chance. We blow away any
;;; entry for the function in *FREE-FUNS* so that nobody will create
;;; new references to it.
(defun let-convert (fun call)
  (declare (type clambda fun) (type basic-combination call))
  (let* ((next-block (insert-let-body fun call))
         (next-block (if (node-tail-p call)
                         nil
                         next-block)))
    (move-return-stuff fun call next-block)
    (merge-lets fun call)
    (setf (node-tail-p call) nil)
    ;; If CALL has a derive type NIL, it means that "its return" is
    ;; unreachable, but the next BIND is still reachable; in order to
    ;; not confuse MAYBE-TERMINATE-BLOCK...
    (setf (node-derived-type call) *wild-type*)))

;;; Reoptimize all of CALL's args and its result.
(defun reoptimize-call (call)
  (declare (type basic-combination call))
  (dolist (arg (basic-combination-args call))
    (when arg
      (reoptimize-lvar arg)))
  (reoptimize-lvar (node-lvar call))
  (values))

;;; Are there any declarations in force to say CLAMBDA shouldn't be
;;; LET converted?
(defun declarations-suppress-let-conversion-p (clambda)
  ;; From the user's point of view, LET-converting something that
  ;; has a name is inlining it. (The user can't see what we're doing
  ;; with anonymous things, and suppressing inlining
  ;; for such things can easily give Python acute indigestion, so
  ;; we don't.)
  (when (leaf-has-source-name-p clambda)
    ;; ANSI requires that explicit NOTINLINE be respected.
    (or (eq (lambda-inlinep clambda) :notinline)
        ;; If (= LET-CONVERSION 0) we can guess that inlining
        ;; generally won't be appreciated, but if the user
        ;; specifically requests inlining, that takes precedence over
        ;; our general guess.
        (and (policy clambda (= let-conversion 0))
             (not (eq (lambda-inlinep clambda) :inline))))))

;;; We also don't convert calls to named functions which appear in the
;;; initial component, delaying this until optimization. This
;;; minimizes the likelihood that we will LET-convert a function which
;;; may have references added due to later local inline expansion.
(defun ok-initial-convert-p (fun)
  (not (and (leaf-has-source-name-p fun)
            (or (declarations-suppress-let-conversion-p fun)
                (eq (component-kind (lambda-component fun))
                    :initial)))))

;;; This function is called when there is some reason to believe that
;;; CLAMBDA might be converted into a LET. This is done after local
;;; call analysis, and also when a reference is deleted. We return
;;; true if we converted.
(defun maybe-let-convert (clambda)
  (declare (type clambda clambda))
  (unless (or (declarations-suppress-let-conversion-p clambda)
              (functional-has-external-references-p clambda))
    ;; We only convert to a LET when the function is a normal local
    ;; function, has no XEP, and is referenced in exactly one local
    ;; call. Conversion is also inhibited if the only reference is in
    ;; a block about to be deleted.
    ;;
    ;; These rules limiting LET conversion may seem unnecessarily
    ;; restrictive, since there are some cases where we could do the
    ;; return with a jump that don't satisfy these requirements. The
    ;; reason for doing things this way is that it makes the concept
    ;; of a LET much more useful at the level of IR1 semantics. The
    ;; :ASSIGNMENT function kind provides another way to optimize
    ;; calls to single-return/multiple call functions.
    ;;
    ;; We don't attempt to convert calls to functions that have an
    ;; XEP, since we might be embarrassed later when we want to
    ;; convert a newly discovered local call. Also, see
    ;; OK-INITIAL-CONVERT-P.
    (let ((refs (leaf-refs clambda)))
      (when (and refs
                 (null (rest refs))
                 (memq (functional-kind clambda) '(nil :assignment))
                 (not (functional-entry-fun clambda)))
        (binding* ((ref (first refs))
                   (ref-lvar (node-lvar ref) :exit-if-null)
                   (dest (lvar-dest ref-lvar)))
          (when (and (basic-combination-p dest)
                     (eq (basic-combination-fun dest) ref-lvar)
                     (eq (basic-combination-kind dest) :local)
                     (not (node-to-be-deleted-p dest))
                     (not (block-delete-p (lambda-block clambda)))
                     (cond ((ok-initial-convert-p clambda) t)
                           (t
                            (reoptimize-lvar ref-lvar)
                            nil)))
            (when (eq clambda (node-home-lambda dest))
              (delete-lambda clambda)
              (return-from maybe-let-convert nil))
            (unless (eq (functional-kind clambda) :assignment)
              (let-convert clambda dest))
            (reoptimize-call dest)
            (setf (functional-kind clambda)
                  (if (mv-combination-p dest) :mv-let :let))))
        t))))

;;;; tail local calls and assignments

;;; Return T if there are no cleanups between BLOCK1 and BLOCK2, or if
;;; they definitely won't generate any cleanup code. Currently we
;;; recognize lexical entry points that are only used locally (if at
;;; all).
(defun only-harmless-cleanups (block1 block2)
  (declare (type cblock block1 block2))
  (or (eq block1 block2)
      (let ((cleanup2 (block-start-cleanup block2)))
        (do ((cleanup (block-end-cleanup block1)
                      (node-enclosing-cleanup (cleanup-mess-up cleanup))))
            ((eq cleanup cleanup2) t)
          (case (cleanup-kind cleanup)
            ((:block :tagbody)
             (unless (null (entry-exits (cleanup-mess-up cleanup)))
               (return nil)))
            (t (return nil)))))))

;;; If a potentially TR local call really is TR, then convert it to
;;; jump directly to the called function. We also call
;;; MAYBE-CONVERT-TO-ASSIGNMENT. The first value is true if we
;;; tail-convert. The second is the value of M-C-T-A.
(defun maybe-convert-tail-local-call (call)
  (declare (type combination call))
  (let ((return (lvar-dest (node-lvar call)))
        (fun (combination-lambda call)))
    (aver (return-p return))
    (when (and (not (node-tail-p call)) ; otherwise already converted
               ;; this is a tail call
               (immediately-used-p (return-result return) call)
               (only-harmless-cleanups (node-block call)
                                       (node-block return))
               ;; If the call is in an XEP, we might decide to make it
               ;; non-tail so that we can use known return inside the
               ;; component.
               (not (eq (functional-kind (node-home-lambda call))
                        :external))
               (not (block-delete-p (lambda-block fun))))
      (node-ends-block call)
      (let ((block (node-block call)))
        (setf (node-tail-p call) t)
        (unlink-blocks block (first (block-succ block)))
        (link-blocks block (lambda-block fun))
        (delete-lvar-use call)
        (values t (maybe-convert-to-assignment fun))))))

;;; This is called when we believe it might make sense to convert
;;; CLAMBDA to an assignment. All this function really does is
;;; determine when a function with more than one call can still be
;;; combined with the calling function's environment. We can convert
;;; when:
;;; -- The function is a normal, non-entry function, and
;;; -- Except for one call, all calls must be tail recursive calls
;;;    in the called function (i.e. are self-recursive tail calls)
;;; -- OK-INITIAL-CONVERT-P is true.
;;;
;;; There may be one outside call, and it need not be tail-recursive.
;;; Since all tail local calls have already been converted to direct
;;; transfers, the only control semantics needed are to splice in the
;;; body at the non-tail call. If there is no non-tail call, then we
;;; need only merge the environments. Both cases are handled by
;;; LET-CONVERT.
;;;
;;; ### It would actually be possible to allow any number of outside
;;; calls as long as they all return to the same place (i.e. have the
;;; same conceptual continuation.) A special case of this would be
;;; when all of the outside calls are tail recursive.
(defun maybe-convert-to-assignment (clambda)
  (declare (type clambda clambda))
  (when (and (not (functional-kind clambda))
             (not (functional-entry-fun clambda))
             (not (functional-has-external-references-p clambda)))
    (let ((outside-non-tail-call nil)
          (outside-call nil))
      (when (and (dolist (ref (leaf-refs clambda) t)
                   (let ((dest (node-dest ref)))
                     (when (or (not dest)
                               (block-delete-p (node-block dest)))
                       (return nil))
                     (let ((home (node-home-lambda ref)))
                       (unless (eq home clambda)
                         (when outside-call
                           (return nil))
                         (setq outside-call dest))
                       (unless (node-tail-p dest)
                         (when (or outside-non-tail-call (eq home clambda))
                           (return nil))
                         (setq outside-non-tail-call dest)))))
                 (ok-initial-convert-p clambda))
        (cond (outside-call (setf (functional-kind clambda) :assignment)
                            (let-convert clambda outside-call)
                            (when outside-non-tail-call
                              (reoptimize-call outside-non-tail-call))
                            t)
              (t (delete-lambda clambda)
                 nil))))))
