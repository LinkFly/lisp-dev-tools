;;;; This file implements type check generation. This is a phase that
;;;; runs at the very end of IR1. If a type check is too complex for
;;;; the back end to directly emit in-line, then we transform the check
;;;; into an explicit conditional using TYPEP.

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; This software is derived from the CMU CL system, which was
;;;; written at Carnegie Mellon University and released into the
;;;; public domain. The software is in the public domain and is
;;;; provided with absolutely no warranty. See the COPYING and CREDITS
;;;; files for more information.

(in-package "SB!C")

;;;; cost estimation

;;; Return some sort of guess about the cost of a call to a function.
;;; If the function has some templates, we return the cost of the
;;; cheapest one, otherwise we return the cost of CALL-NAMED. Calling
;;; this with functions that have transforms can result in relatively
;;; meaningless results (exaggerated costs.)
;;;
;;; We special-case NULL, since it does have a source tranform and is
;;; interesting to us.
(defun fun-guessed-cost (name)
  (declare (symbol name))
  (let ((info (info :function :info name))
        (call-cost (template-cost (template-or-lose 'call-named))))
    (if info
        (let ((templates (fun-info-templates info)))
          (if templates
              (template-cost (first templates))
              (case name
                (null (template-cost (template-or-lose 'if-eq)))
                (t call-cost))))
        call-cost)))

;;; Return some sort of guess for the cost of doing a test against
;;; TYPE. The result need not be precise as long as it isn't way out
;;; in space. The units are based on the costs specified for various
;;; templates in the VM definition.
(defun type-test-cost (type)
  (declare (type ctype type))
  (or (when (eq type *universal-type*)
        0)
      (when (eq type *empty-type*)
        0)
      (let ((check (type-check-template type)))
        (if check
            (template-cost check)
            (let ((found (cdr (assoc type *backend-type-predicates*
                                     :test #'type=))))
              (if found
                  (+ (fun-guessed-cost found) (fun-guessed-cost 'eq))
                  nil))))
      (typecase type
        (compound-type
         (reduce #'+ (compound-type-types type) :key 'type-test-cost))
        (member-type
         (* (member-type-size type)
            (fun-guessed-cost 'eq)))
        (numeric-type
         (* (if (numeric-type-complexp type) 2 1)
            (fun-guessed-cost
             (if (csubtypep type (specifier-type 'fixnum)) 'fixnump 'numberp))
            (+ 1
               (if (numeric-type-low type) 1 0)
               (if (numeric-type-high type) 1 0))))
        (cons-type
         (+ (type-test-cost (specifier-type 'cons))
            (fun-guessed-cost 'car)
            (type-test-cost (cons-type-car-type type))
            (fun-guessed-cost 'cdr)
            (type-test-cost (cons-type-cdr-type type))))
        (t
         (fun-guessed-cost 'typep)))))

(defun weaken-integer-type (type)
  (cond ((union-type-p type)
         (let* ((types (union-type-types type))
                (one (pop types))
                (low (numeric-type-low one))
                (high (numeric-type-high one)))
           (flet ((maximize (bound)
                    (if (and bound high)
                        (setf high (max high bound))
                        (setf high nil)))
                  (minimize (bound)
                    (if (and bound low)
                        (setf low (min low bound))
                        (setf low nil))))
             (dolist (a types)
               (minimize (numeric-type-low a))
               (maximize (numeric-type-high a))))
           (specifier-type `(integer ,(or low '*) ,(or high '*)))))
        (t
         (aver (integer-type-p type))
         type)))

(defun-cached
    (weaken-type :hash-bits 8
                 :hash-function (lambda (x)
                                  (logand (type-hash-value x) #xFF)))
    ((type eq))
  (declare (type ctype type))
  (cond ((named-type-p type)
         type)
        ((csubtypep type (specifier-type 'integer))
         ;; KLUDGE: Simple range checks are not that expensive, and we *don't*
         ;; want to accidentally lose eg. array bounds checks due to weakening,
         ;; so for integer types we simply collapse all ranges into one.
         (weaken-integer-type type))
        (t
         (let ((min-cost (type-test-cost type))
               (min-type type)
               (found-super nil))
           (dolist (x *backend-type-predicates*)
             (let* ((stype (car x))
                    (samep (type= stype type)))
               (when (or samep
                         (and (csubtypep type stype)
                              (not (union-type-p stype))))
                 (let ((stype-cost (type-test-cost stype)))
                   (when (or (< stype-cost min-cost)
                             samep)
                     ;; If the supertype is equal in cost to the type, we
                     ;; prefer the supertype. This produces a closer
                     ;; approximation of the right thing in the presence of
                     ;; poor cost info.
                     (setq found-super t
                           min-type stype
                           min-cost stype-cost))))))
           ;; This used to return the *UNIVERSAL-TYPE* if no supertype was found,
           ;; but that's too liberal: it's far too easy for the user to create
           ;; a union type (which are excluded above), and then trick the compiler
           ;; into trusting the union type... and finally ending up corrupting the
           ;; heap once a bad object sneaks past the missing type check.
           (if found-super
               min-type
               type)))))

(defun weaken-values-type (type)
  (declare (type ctype type))
  (cond ((eq type *wild-type*) type)
        ((not (values-type-p type))
         (weaken-type type))
        (t
         (make-values-type :required (mapcar #'weaken-type
                                             (values-type-required type))
                           :optional (mapcar #'weaken-type
                                             (values-type-optional type))
                           :rest (acond ((values-type-rest type)
                                         (weaken-type it)))))))

;;;; checking strategy determination

;;; Return the type we should test for when we really want to check
;;; for TYPE. If type checking policy is "fast", then we return a
;;; weaker type if it is easier to check. First we try the defined
;;; type weakenings, then look for any predicate that is cheaper.
(defun maybe-weaken-check (type policy)
  (declare (type ctype type))
  (ecase (policy policy type-check)
    (0 *wild-type*)
    (2 (weaken-values-type type))
    (3 type)))

;;; This is like VALUES-TYPES, only we mash any complex function types
;;; to FUNCTION.
(defun no-fun-values-types (type)
  (declare (type ctype type))
  (multiple-value-bind (res count) (values-types type)
    (values (mapcar (lambda (type)
                      (if (fun-type-p type)
                          (specifier-type 'function)
                          type))
                    res)
            count)))

;;; Switch to disable check complementing, for evaluation.
(defvar *complement-type-checks* t)

;;; LVAR is an lvar we are doing a type check on and TYPES is a list
;;; of types that we are checking its values against. If we have
;;; proven that LVAR generates a fixed number of values, then for each
;;; value, we check whether it is cheaper to then difference between
;;; the proven type and the corresponding type in TYPES. If so, we opt
;;; for a :HAIRY check with that test negated. Otherwise, we try to do
;;; a simple test, and if that is impossible, we do a hairy test with
;;; non-negated types. If true, FORCE-HAIRY forces a hairy type check.
(defun maybe-negate-check (lvar types original-types force-hairy n-required)
  (declare (type lvar lvar) (list types original-types))
  (let ((ptypes (values-type-out (lvar-derived-type lvar) (length types))))
    (multiple-value-bind (hairy-res simple-res)
        (loop for p in ptypes
              and c in types
              and a in original-types
              and i from 0
              for cc = (if (>= i n-required)
                           (type-union c (specifier-type 'null))
                           c)
              for diff = (type-difference p cc)
              collect (if (and diff
                               (< (type-test-cost diff)
                                  (type-test-cost cc))
                               *complement-type-checks*)
                          (list t diff a)
                          (list nil cc a))
              into hairy-res
              collect cc into simple-res
              finally (return (values hairy-res simple-res)))
      (cond ((or force-hairy (find-if #'first hairy-res))
             (values :hairy hairy-res))
            ((every #'type-check-template simple-res)
             (values :simple simple-res))
            (t
             (values :hairy hairy-res))))))

;;; Determines whether CAST's assertion is:
;;;  -- checkable by the back end (:SIMPLE), or
;;;  -- not checkable by the back end, but checkable via an explicit
;;;     test in type check conversion (:HAIRY), or
;;;  -- not reasonably checkable at all (:TOO-HAIRY).
;;;
;;; We may check only fixed number of values; in any case the number
;;; of generated values is trusted. If we know the number of produced
;;; values, all of them are checked; otherwise if we know the number
;;; of consumed -- only they are checked; otherwise the check is not
;;; performed.
;;;
;;; A type is simply checkable if all the type assertions have a
;;; TYPE-CHECK-TEMPLATE. In this :SIMPLE case, the second value is a
;;; list of the type restrictions specified for the leading positional
;;; values.
;;;
;;; Old comment:
;;;
;;;    We force a check to be hairy even when there are fixed values
;;;    if we are in a context where we may be forced to use the
;;;    unknown values convention anyway. This is because IR2tran can't
;;;    generate type checks for unknown values lvars but people could
;;;    still be depending on the check being done. We only care about
;;;    EXIT and RETURN (not MV-COMBINATION) since these are the only
;;;    contexts where the ultimate values receiver
;;;
;;; In the :HAIRY case, the second value is a list of triples of
;;; the form:
;;;    (NOT-P TYPE ORIGINAL-TYPE)
;;;
;;; If true, the NOT-P flag indicates a test that the corresponding
;;; value is *not* of the specified TYPE. ORIGINAL-TYPE is the type
;;; asserted on this value in the lvar, for use in error
;;; messages. When NOT-P is true, this will be different from TYPE.
;;;
;;; This allows us to take what has been proven about CAST's argument
;;; type into consideration. If it is cheaper to test for the
;;; difference between the derived type and the asserted type, then we
;;; check for the negation of this type instead.
(defun cast-check-types (cast force-hairy)
  (declare (type cast cast))
  (let* ((ctype (coerce-to-values (cast-type-to-check cast)))
         (atype (coerce-to-values (cast-asserted-type cast)))
         (dtype (node-derived-type cast))
         (value (cast-value cast))
         (lvar (node-lvar cast))
         (dest (and lvar (lvar-dest lvar)))
         (n-consumed (cond ((not lvar)
                            nil)
                           ((lvar-single-value-p lvar)
                            1)
                           ((and (mv-combination-p dest)
                                 (eq (mv-combination-kind dest) :local))
                            (let ((fun-ref (lvar-use (mv-combination-fun dest))))
                              (length (lambda-vars (ref-leaf fun-ref)))))))
         (n-required (length (values-type-required dtype))))
    (aver (not (eq ctype *wild-type*)))
    (cond ((and (null (values-type-optional dtype))
                (not (values-type-rest dtype)))
           ;; we [almost] know how many values are produced
           (maybe-negate-check value
                               (values-type-out ctype n-required)
                               (values-type-out atype n-required)
                               ;; backend checks only consumed values
                               (not (eql n-required n-consumed))
                               n-required))
          ((lvar-single-value-p lvar)
           ;; exactly one value is consumed
           (principal-lvar-single-valuify lvar)
           (flet ((get-type (type)
                    (acond ((args-type-required type)
                            (car it))
                           ((args-type-optional type)
                            (car it))
                           (t (bug "type ~S is too hairy" type)))))
             (multiple-value-bind (ctype atype)
                 (values (get-type ctype) (get-type atype))
               (maybe-negate-check value
                                   (list ctype) (list atype)
                                   force-hairy
                                   n-required))))
          ((and (mv-combination-p dest)
                (eq (mv-combination-kind dest) :local))
           ;; we know the number of consumed values
           (maybe-negate-check value
                               (adjust-list (values-type-types ctype)
                                            n-consumed
                                            *universal-type*)
                               (adjust-list (values-type-types atype)
                                            n-consumed
                                            *universal-type*)
                               force-hairy
                               n-required))
          (t
           (values :too-hairy nil)))))

;;; Return T is the cast appears to be from the declaration of the callee,
;;; and should be checked externally -- that is, by the callee and not the caller.
(defun cast-externally-checkable-p (cast)
  (declare (type cast cast))
  (let* ((lvar (node-lvar cast))
         (dest (and lvar (lvar-dest lvar))))
    (and (combination-p dest)
         ;; The theory is that the type assertion is from a declaration on the
         ;; callee, so the callee should be able to do the check. We want to
         ;; let the callee do the check, because it is possible that by the
         ;; time of call that declaration will be changed and we do not want
         ;; to make people recompile all calls to a function when they were
         ;; originally compiled with a bad declaration.
         ;;
         ;; ALMOST-IMMEDIATELY-USED-P ensures that we don't delegate casts
         ;; that occur before nodes that can cause observable side effects --
         ;; most commonly other non-external casts: so the order in which
         ;; possible type errors are signalled matches with the evaluation
         ;; order.
         ;;
         ;; FIXME: We should let more cases be handled by the callee then we
         ;; currently do, see: https://bugs.launchpad.net/sbcl/+bug/309104
         ;; This is not fixable quite here, though, because flow-analysis has
         ;; deleted the LVAR of the cast by the time we get here, so there is
         ;; no destination. Perhaps we should mark cases inserted by
         ;; ASSERT-CALL-TYPE explicitly, and delete those whose destination is
         ;; deemed unreachable?
         (almost-immediately-used-p lvar cast)
         (values (values-subtypep (lvar-externally-checkable-type lvar)
                                  (cast-type-to-check cast))))))

;;; Return true if CAST's value is an lvar whose type the back end is
;;; likely to be able to check (see GENERATE-TYPE-CHECKS). Since we
;;; don't know what template the back end is going to choose to
;;; implement the continuation's DEST, we use a heuristic.
;;;
;;; We always return T unless nobody uses the value (the backend
;;; cannot check unused LVAR chains).
;;;
;;; The logic used to be more complex, but most of the cases that used
;;; to be checked here are now dealt with differently . FIXME: but
;;; here's one we used to do, don't anymore, but could still benefit
;;; from, if we reimplemented it (elsewhere):
;;;
;;;  -- If the lvar is an argument to a known function that has
;;;     no IR2-CONVERT method or :FAST-SAFE templates that are
;;;     compatible with the call's type: return NIL.
;;;
;;; The code used to look like something like this:
;;;   ...
;;;   (:known
;;;    (let ((info (basic-combination-fun-info dest)))
;;;      (if (fun-info-ir2-convert info)
;;;          t
;;;          (dolist (template (fun-info-templates info) nil)
;;;            (when (eq (template-ltn-policy template)
;;;                      :fast-safe)
;;;              (multiple-value-bind (val win)
;;;                  (valid-fun-use dest (template-type template))
;;;                (when (or val (not win)) (return t)))))))))))))
;;;
;;; ADP says: It is still interesting. When we have a :SAFE template
;;; and the type assertion is derived from the destination function
;;; type, the check is unneccessary. We cannot return NIL here (the
;;; whole function has changed its meaning, and here NIL *forces*
;;; hairy check), but the functionality is interesting.
(defun probable-type-check-p (cast)
  (declare (type cast cast))
  (let* ((lvar (node-lvar cast))
         (dest (and lvar (lvar-dest lvar))))
    (cond ((not dest) nil)
          (t t))))

;;; Return a lambda form that we can convert to do a hairy type check
;;; of the specified TYPES. TYPES is a list of the format returned by
;;; LVAR-CHECK-TYPES in the :HAIRY case.
;;;
;;; Note that we don't attempt to check for required values being
;;; unsupplied. Such checking is impossible to efficiently do at the
;;; source level because our fixed-values conventions are optimized
;;; for the common MV-BIND case.
(defun make-type-check-form (types)
  (let ((temps (make-gensym-list (length types))))
    `(multiple-value-bind ,temps
         'dummy
       ,@(mapcar (lambda (temp type)
                   (let* ((spec
                           (let ((*unparse-fun-type-simplify* t))
                             (type-specifier (second type))))
                          (test (if (first type) `(not ,spec) spec)))
                     `(unless (typep ,temp ',test)
                        (%type-check-error
                         ,temp
                         ',(type-specifier (third type))))))
                 temps
                 types)
       (values ,@temps))))

;;; Splice in explicit type check code immediately before CAST. This
;;; code receives the value(s) that were being passed to CAST-VALUE,
;;; checks the type(s) of the value(s), then passes them further.
(defun convert-type-check (cast types)
  (declare (type cast cast) (type list types))
  (let ((value (cast-value cast))
        (length (length types)))
    (filter-lvar value (make-type-check-form types))
    (reoptimize-lvar (cast-value cast))
    (setf (cast-type-to-check cast) *wild-type*)
    (setf (cast-%type-check cast) nil)
    (let* ((atype (cast-asserted-type cast))
           (atype (cond ((not (values-type-p atype))
                         atype)
                        ((= length 1)
                         (single-value-type atype))
                        (t
                         (make-values-type
                          :required (values-type-out atype length)))))
           (dtype (node-derived-type cast))
           (dtype (make-values-type
                   :required (values-type-out dtype length))))
      (setf (cast-asserted-type cast) atype)
      (setf (node-derived-type cast) dtype)))

  (values))

;;; Check all possible arguments of CAST and emit type warnings for
;;; those with type errors. If the value of USE is being used for a
;;; variable binding, we figure out which one for source context. If
;;; the value is a constant, we print it specially.
(defun cast-check-uses (cast)
  (declare (type cast cast))
  (let* ((lvar (node-lvar cast))
         (dest (and lvar (lvar-dest lvar)))
         (value (cast-value cast))
         (atype (cast-asserted-type cast))
         (condition 'type-warning)
         (not-ok-uses '()))
    (do-uses (use value)
      (let ((dtype (node-derived-type use)))
        (if (values-types-equal-or-intersect dtype atype)
            (setf condition 'type-style-warning)
            (push use not-ok-uses))))
    (dolist (use (nreverse not-ok-uses))
      (let* ((*compiler-error-context* use)
             (dtype      (node-derived-type use))
             (atype-spec (type-specifier atype))
             (what (when (and (combination-p dest)
                              (eq (combination-kind dest) :local))
                     (let ((lambda (combination-lambda dest))
                           (pos (position-or-lose
                                 lvar (combination-args dest))))
                       (format nil "~:[A possible~;The~] binding of ~S"
                               (and (lvar-has-single-use-p lvar)
                                    (eq (functional-kind lambda) :let))
                               (leaf-source-name (elt (lambda-vars lambda)
                                                      pos)))))))
        (cond ((and (ref-p use) (constant-p (ref-leaf use)))
               (warn condition
                     :format-control
                     "~:[This~;~:*~A~] is not a ~<~%~9T~:;~S:~>~%  ~S"
                     :format-arguments
                     (list what atype-spec
                           (constant-value (ref-leaf use)))))
              (t
               (warn condition
                     :format-control
                     "~:[Result~;~:*~A~] is a ~S, ~<~%~9T~:;not a ~S.~>"
                     :format-arguments
                     (list what (type-specifier dtype) atype-spec)))))))
  (values))

;;; Loop over all blocks in COMPONENT that have TYPE-CHECK set,
;;; looking for CASTs with TYPE-CHECK T. We do two mostly unrelated
;;; things: detect compile-time type errors and determine if and how
;;; to do run-time type checks.
;;;
;;; If there is a compile-time type error, then we mark the CAST and
;;; emit a warning if appropriate. This part loops over all the uses
;;; of the continuation, since after we convert the check, the
;;; :DELETED kind will inhibit warnings about the types of other uses.
;;;
;;; If the cast is too complex to be checked by the back end, or is
;;; better checked with explicit code, then convert to an explicit
;;; test. Assertions that can checked by the back end are passed
;;; through. Assertions that can't be tested are flamed about and
;;; marked as not needing to be checked.
;;;
;;; If we determine that a type check won't be done, then we set
;;; TYPE-CHECK to :NO-CHECK. In the non-hairy cases, this is just to
;;; prevent us from wasting time coming to the same conclusion again
;;; on a later iteration. In the hairy case, we must indicate to LTN
;;; that it must choose a safe implementation, since IR2 conversion
;;; will choke on the check.
;;;
;;; The generation of the type checks is delayed until all the type
;;; check decisions have been made because the generation of the type
;;; checks creates new nodes whose derived types aren't always updated
;;; which may lead to inappropriate template choices due to the
;;; modification of argument types.
(defun generate-type-checks (component)
  (collect ((casts))
    (do-blocks (block component)
      (when (block-type-check block)
        ;; CAST-EXTERNALLY-CHECKABLE-P wants the backward pass
        (do-nodes-backwards (node nil block)
          (when (and (cast-p node)
                     (cast-type-check node))
            (cast-check-uses node)
            (cond ((cast-externally-checkable-p node)
                   (setf (cast-%type-check node) :external))
                  (t
                   ;; it is possible that NODE was marked :EXTERNAL by
                   ;; the previous pass
                   (setf (cast-%type-check node) t)
                   (casts (cons node (not (probable-type-check-p node))))))))
        (setf (block-type-check block) nil)))
    (dolist (cast (casts))
      (destructuring-bind (cast . force-hairy) cast
        (multiple-value-bind (check types)
            (cast-check-types cast force-hairy)
          (ecase check
            (:simple)
            (:hairy
             (convert-type-check cast types))
            (:too-hairy
             (let ((*compiler-error-context* cast))
               (when (policy cast (>= safety inhibit-warnings))
                 (compiler-notify
                  "type assertion too complex to check:~% ~S."
                  (type-specifier (coerce-to-values (cast-asserted-type cast))))))
             (setf (cast-type-to-check cast) *wild-type*)
             (setf (cast-%type-check cast) nil)))))))
  (values))
