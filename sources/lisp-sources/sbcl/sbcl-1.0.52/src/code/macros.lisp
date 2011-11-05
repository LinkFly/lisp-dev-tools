;;;; lots of basic macros for the target SBCL

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; This software is derived from the CMU CL system, which was
;;;; written at Carnegie Mellon University and released into the
;;;; public domain. The software is in the public domain and is
;;;; provided with absolutely no warranty. See the COPYING and CREDITS
;;;; files for more information.

(in-package "SB!IMPL")

;;;; ASSERT and CHECK-TYPE

;;; ASSERT is written this way, to call ASSERT-ERROR, because of how
;;; closures are compiled. RESTART-CASE has forms with closures that
;;; the compiler causes to be generated at the top of any function
;;; using RESTART-CASE, regardless of whether they are needed. Thus if
;;; we just wrapped a RESTART-CASE around the call to ERROR, we'd have
;;; to do a significant amount of work at runtime allocating and
;;; deallocating the closures regardless of whether they were ever
;;; needed.
;;;
;;; ASSERT-ERROR isn't defined until a later file because it uses the
;;; macro RESTART-CASE, which isn't defined until a later file.
(defmacro-mundanely assert (test-form &optional places datum &rest arguments)
  #!+sb-doc
  "Signals an error if the value of test-form is nil. Continuing from this
   error using the CONTINUE restart will allow the user to alter the value of
   some locations known to SETF, starting over with test-form. Returns NIL."
  `(do () (,test-form)
     (assert-error ',test-form ',places ,datum ,@arguments)
     ,@(mapcar (lambda (place)
                 `(setf ,place (assert-prompt ',place ,place)))
               places)))

(defun assert-prompt (name value)
  (cond ((y-or-n-p "The old value of ~S is ~S.~
                    ~%Do you want to supply a new value? "
                   name value)
         (format *query-io* "~&Type a form to be evaluated:~%")
         (flet ((read-it () (eval (read *query-io*))))
           (if (symbolp name) ;help user debug lexical variables
               (progv (list name) (list value) (read-it))
               (read-it))))
        (t value)))

;;; CHECK-TYPE is written this way, to call CHECK-TYPE-ERROR, because
;;; of how closures are compiled. RESTART-CASE has forms with closures
;;; that the compiler causes to be generated at the top of any
;;; function using RESTART-CASE, regardless of whether they are
;;; needed. Because it would be nice if CHECK-TYPE were cheap to use,
;;; and some things (e.g., READ-CHAR) can't afford this excessive
;;; consing, we bend backwards a little.
;;;
;;; CHECK-TYPE-ERROR isn't defined until a later file because it uses
;;; the macro RESTART-CASE, which isn't defined until a later file.
(defmacro-mundanely check-type (place type &optional type-string
                                &environment env)
  #!+sb-doc
  "Signal a restartable error of type TYPE-ERROR if the value of PLACE
is not of the specified type. If an error is signalled and the restart
is used to return, this can only return if the STORE-VALUE restart is
invoked. In that case it will store into PLACE and start over."
  ;; Detect a common user-error.
  (when (and (consp type) (eq 'quote (car type)))
    (error 'simple-reference-error
           :format-control "Quoted type specifier in ~S: ~S"
           :format-arguments (list 'check-type type)
           :references (list '(:ansi-cl :macro check-type))))
  ;; KLUDGE: We use a simpler form of expansion if PLACE is just a
  ;; variable to work around Python's blind spot in type derivation.
  ;; For more complex places getting the type derived should not
  ;; matter so much anyhow.
  (let ((expanded (%macroexpand place env)))
    (if (symbolp expanded)
        `(do ()
             ((typep ,place ',type))
          (setf ,place (check-type-error ',place ,place ',type ,type-string)))
        (let ((value (gensym)))
          `(do ((,value ,place ,place))
               ((typep ,value ',type))
            (setf ,place
                  (check-type-error ',place ,value ',type ,type-string)))))))

;;;; DEFINE-SYMBOL-MACRO

(defmacro-mundanely define-symbol-macro (name expansion)
  `(eval-when (:compile-toplevel :load-toplevel :execute)
    (sb!c::%define-symbol-macro ',name ',expansion (sb!c:source-location))))

(defun sb!c::%define-symbol-macro (name expansion source-location)
  (unless (symbolp name)
    (error 'simple-type-error :datum name :expected-type 'symbol
           :format-control "Symbol macro name is not a symbol: ~S."
           :format-arguments (list name)))
  (with-single-package-locked-error
      (:symbol name "defining ~A as a symbol-macro"))
  (sb!c:with-source-location (source-location)
    (setf (info :source-location :symbol-macro name) source-location))
  (let ((kind (info :variable :kind name)))
    (ecase kind
     ((:macro :unknown)
      (setf (info :variable :kind name) :macro)
      (setf (info :variable :macro-expansion name) expansion))
     ((:special :global)
      (error 'simple-program-error
             :format-control "Symbol macro name already declared ~A: ~S."
             :format-arguments (list kind name)))
     (:constant
      (error 'simple-program-error
             :format-control "Symbol macro name already defined as a constant: ~S."
             :format-arguments (list name)))))
  name)

;;;; DEFINE-COMPILER-MACRO

(defmacro-mundanely define-compiler-macro (name lambda-list &body body)
  #!+sb-doc
  "Define a compiler-macro for NAME."
  (legal-fun-name-or-type-error name)
  (when (and (symbolp name) (special-operator-p name))
    (error 'simple-program-error
           :format-control "cannot define a compiler-macro for a special operator: ~S"
           :format-arguments (list name)))
  (with-unique-names (whole environment)
    (multiple-value-bind (body local-decs doc)
        (parse-defmacro lambda-list whole body name 'define-compiler-macro
                        :environment environment)
      (let ((def `(lambda (,whole ,environment)
                    ,@local-decs
                    ,body))
            (debug-name (sb!c::debug-name 'compiler-macro-function name)))
        `(eval-when (:compile-toplevel :load-toplevel :execute)
           (sb!c::%define-compiler-macro ',name
                                         #',def
                                         ',lambda-list
                                         ,doc
                                         ',debug-name))))))

;;; FIXME: This will look remarkably similar to those who have already
;;; seen the code for %DEFMACRO in src/code/defmacro.lisp.  Various
;;; bits of logic should be shared (notably arglist setting).
(macrolet
    ((def (times set-p)
         `(eval-when (,@times)
           (defun sb!c::%define-compiler-macro
               (name definition lambda-list doc debug-name)
             ,@(unless set-p
                 '((declare (ignore lambda-list debug-name))))
             ;; FIXME: warn about incompatible lambda list with
             ;; respect to parent function?
             (setf (sb!xc:compiler-macro-function name) definition)
             ,(when set-p
                    `(setf (%fun-doc definition) doc
                           (%fun-lambda-list definition) lambda-list
                           (%fun-name definition) debug-name))
             name))))
  (progn
    (def (:load-toplevel :execute) #-sb-xc-host t #+sb-xc-host nil)
    #-sb-xc (def (:compile-toplevel) nil)))

;;;; CASE, TYPECASE, and friends

(eval-when (#-sb-xc :compile-toplevel :load-toplevel :execute)

;;; Make this a full warning during SBCL build.
(define-condition duplicate-case-key-warning (#-sb-xc-host style-warning #+sb-xc-host warning)
  ((key :initarg :key
        :reader case-warning-key)
   (case-kind :initarg :case-kind
              :reader case-warning-case-kind)
   (occurrences :initarg :occurrences
                :type list
                :reader duplicate-case-key-warning-occurrences))
  (:report
    (lambda (condition stream)
      (format stream
        "Duplicate key ~S in ~S form, ~
         occurring in~{~#[~; and~]~{ the ~:R clause:~%~<  ~S~:>~}~^,~}."
        (case-warning-key condition)
        (case-warning-case-kind condition)
        (duplicate-case-key-warning-occurrences condition)))))

;;; CASE-BODY returns code for all the standard "case" macros. NAME is
;;; the macro name, and KEYFORM is the thing to case on. MULTI-P
;;; indicates whether a branch may fire off a list of keys; otherwise,
;;; a key that is a list is interpreted in some way as a single key.
;;; When MULTI-P, TEST is applied to the value of KEYFORM and each key
;;; for a given branch; otherwise, TEST is applied to the value of
;;; KEYFORM and the entire first element, instead of each part, of the
;;; case branch. When ERRORP, no OTHERWISE-CLAUSEs are recognized,
;;; and an ERROR form is generated where control falls off the end
;;; of the ordinary clauses. When PROCEEDP, it is an error to
;;; omit ERRORP, and the ERROR form generated is executed within a
;;; RESTART-CASE allowing KEYFORM to be set and retested.
(defun case-body (name keyform cases multi-p test errorp proceedp needcasesp)
  (unless (or cases (not needcasesp))
    (warn "no clauses in ~S" name))
  (let ((keyform-value (gensym))
        (clauses ())
        (keys ())
        (keys-seen (make-hash-table :test #'eql)))
    (do* ((cases cases (cdr cases))
          (case (car cases) (car cases))
          (case-position 1 (1+ case-position)))
         ((null cases) nil)
      (flet ((check-clause (case-keys)
               (loop for k in case-keys
                     for existing = (gethash k keys-seen)
                     do (when existing
                          (let ((sb!c::*current-path*
                                 (when (boundp 'sb!c::*source-paths*)
                                   (or (sb!c::get-source-path case)
                                       sb!c::*current-path*))))
                            (warn 'duplicate-case-key-warning
                                  :key k
                                  :case-kind name
                                  :occurrences `(,existing (,case-position (,case)))))))
               (let ((record (list case-position (list case))))
                 (dolist (k case-keys)
                   (setf (gethash k keys-seen) record)))))
        (unless (list-of-length-at-least-p case 1)
          (error "~S -- bad clause in ~S" case name))
        (destructuring-bind (keyoid &rest forms) case
          (cond (;; an OTHERWISE-CLAUSE
                 ;;
                 ;; By the way... The old code here tried gave
                 ;; STYLE-WARNINGs for normal-clauses which looked as
                 ;; though they might've been intended to be
                 ;; otherwise-clauses. As Tony Martinez reported on
                 ;; sbcl-devel 2004-11-09 there are sometimes good
                 ;; reasons to write clauses like that; and as I noticed
                 ;; when trying to understand the old code so I could
                 ;; understand his patch, trying to guess which clauses
                 ;; don't have good reasons is fundamentally kind of a
                 ;; mess. SBCL does issue style warnings rather
                 ;; enthusiastically, and I have often justified that by
                 ;; arguing that we're doing that to detect issues which
                 ;; are tedious for programmers to detect for by
                 ;; proofreading (like small typoes in long symbol
                 ;; names, or duplicate function definitions in large
                 ;; files). This doesn't seem to be an issue like that,
                 ;; and I can't think of a comparably good justification
                 ;; for giving STYLE-WARNINGs for legal code here, so
                 ;; now we just hope the programmer knows what he's
                 ;; doing. -- WHN 2004-11-20
                 (and (not errorp) ; possible only in CASE or TYPECASE,
                                   ; not in [EC]CASE or [EC]TYPECASE
                      (memq keyoid '(t otherwise))
                      (null (cdr cases)))
                 (push `(t nil ,@forms) clauses))
                ((and multi-p (listp keyoid))
                 (setf keys (append keyoid keys))
                 (check-clause keyoid)
                 (push `((or ,@(mapcar (lambda (key)
                                         `(,test ,keyform-value ',key))
                                       keyoid))
                         nil
                         ,@forms)
                       clauses))
                (t
                 (push keyoid keys)
                 (check-clause (list keyoid))
                 (push `((,test ,keyform-value ',keyoid)
                         nil
                         ,@forms)
                       clauses))))))
    (case-body-aux name keyform keyform-value clauses keys errorp proceedp
                   `(,(if multi-p 'member 'or) ,@keys))))

;;; CASE-BODY-AUX provides the expansion once CASE-BODY has groveled
;;; all the cases. Note: it is not necessary that the resulting code
;;; signal case-failure conditions, but that's what KMP's prototype
;;; code did. We call CASE-BODY-ERROR, because of how closures are
;;; compiled. RESTART-CASE has forms with closures that the compiler
;;; causes to be generated at the top of any function using the case
;;; macros, regardless of whether they are needed.
;;;
;;; The CASE-BODY-ERROR function is defined later, when the
;;; RESTART-CASE macro has been defined.
(defun case-body-aux (name keyform keyform-value clauses keys
                      errorp proceedp expected-type)
  (if proceedp
      (let ((block (gensym))
            (again (gensym)))
        `(let ((,keyform-value ,keyform))
           (block ,block
             (tagbody
              ,again
              (return-from
               ,block
               (cond ,@(nreverse clauses)
                     (t
                      (setf ,keyform-value
                            (setf ,keyform
                                  (case-body-error
                                   ',name ',keyform ,keyform-value
                                   ',expected-type ',keys)))
                      (go ,again))))))))
      `(let ((,keyform-value ,keyform))
         (declare (ignorable ,keyform-value)) ; e.g. (CASE KEY (T))
         (cond
          ,@(nreverse clauses)
          ,@(if errorp
                `((t (case-failure ',name ,keyform-value ',keys))))))))
) ; EVAL-WHEN

(defmacro-mundanely case (keyform &body cases)
  #!+sb-doc
  "CASE Keyform {({(Key*) | Key} Form*)}*
  Evaluates the Forms in the first clause with a Key EQL to the value of
  Keyform. If a singleton key is T then the clause is a default clause."
  (case-body 'case keyform cases t 'eql nil nil nil))

(defmacro-mundanely ccase (keyform &body cases)
  #!+sb-doc
  "CCASE Keyform {({(Key*) | Key} Form*)}*
  Evaluates the Forms in the first clause with a Key EQL to the value of
  Keyform. If none of the keys matches then a correctable error is
  signalled."
  (case-body 'ccase keyform cases t 'eql t t t))

(defmacro-mundanely ecase (keyform &body cases)
  #!+sb-doc
  "ECASE Keyform {({(Key*) | Key} Form*)}*
  Evaluates the Forms in the first clause with a Key EQL to the value of
  Keyform. If none of the keys matches then an error is signalled."
  (case-body 'ecase keyform cases t 'eql t nil t))

(defmacro-mundanely typecase (keyform &body cases)
  #!+sb-doc
  "TYPECASE Keyform {(Type Form*)}*
  Evaluates the Forms in the first clause for which TYPEP of Keyform and Type
  is true."
  (case-body 'typecase keyform cases nil 'typep nil nil nil))

(defmacro-mundanely ctypecase (keyform &body cases)
  #!+sb-doc
  "CTYPECASE Keyform {(Type Form*)}*
  Evaluates the Forms in the first clause for which TYPEP of Keyform and Type
  is true. If no form is satisfied then a correctable error is signalled."
  (case-body 'ctypecase keyform cases nil 'typep t t t))

(defmacro-mundanely etypecase (keyform &body cases)
  #!+sb-doc
  "ETYPECASE Keyform {(Type Form*)}*
  Evaluates the Forms in the first clause for which TYPEP of Keyform and Type
  is true. If no form is satisfied then an error is signalled."
  (case-body 'etypecase keyform cases nil 'typep t nil t))

;;;; WITH-FOO i/o-related macros

(defmacro-mundanely with-open-stream ((var stream) &body forms-decls)
  (multiple-value-bind (forms decls)
      (parse-body forms-decls :doc-string-allowed nil)
    (let ((abortp (gensym)))
      `(let ((,var ,stream)
             (,abortp t))
         ,@decls
         (unwind-protect
             (multiple-value-prog1
              (progn ,@forms)
              (setq ,abortp nil))
           (when ,var
             (close ,var :abort ,abortp)))))))

(defmacro-mundanely with-open-file ((stream filespec &rest options)
                                    &body body)
  `(with-open-stream (,stream (open ,filespec ,@options))
     ,@body))

(defmacro-mundanely with-input-from-string ((var string &key index start end)
                                            &body forms-decls)
  (multiple-value-bind (forms decls)
      (parse-body forms-decls :doc-string-allowed nil)
    ;; The ONCE-ONLY inhibits compiler note for unreachable code when
    ;; END is true.
    (once-only ((string string))
      `(let ((,var
              ,(cond ((null end)
                      `(make-string-input-stream ,string ,(or start 0)))
                     ((symbolp end)
                      `(if ,end
                           (make-string-input-stream ,string
                                                     ,(or start 0)
                                                     ,end)
                           (make-string-input-stream ,string
                                                     ,(or start 0))))
                     (t
                      `(make-string-input-stream ,string
                                                 ,(or start 0)
                                                 ,end)))))
         ,@decls
         (multiple-value-prog1
             (unwind-protect
                  (progn ,@forms)
               (close ,var))
           ,@(when index
               `((setf ,index (string-input-stream-current ,var)))))))))

(defmacro-mundanely with-output-to-string
    ((var &optional string &key (element-type ''character))
     &body forms-decls)
  (multiple-value-bind (forms decls)
      (parse-body forms-decls :doc-string-allowed nil)
    (if string
        (let ((element-type-var (gensym)))
          `(let ((,var (make-fill-pointer-output-stream ,string))
                 ;; ELEMENT-TYPE isn't currently used for anything
                 ;; (see FILL-POINTER-OUTPUT-STREAM FIXME in stream.lisp),
                 ;; but it still has to be evaluated for side-effects.
                 (,element-type-var ,element-type))
            (declare (ignore ,element-type-var))
            ,@decls
            (unwind-protect
                 (progn ,@forms)
              (close ,var))))
      `(let ((,var (make-string-output-stream :element-type ,element-type)))
         ,@decls
         (unwind-protect
             (progn ,@forms)
           (close ,var))
         (get-output-stream-string ,var)))))

;;;; miscellaneous macros

(defmacro-mundanely nth-value (n form)
  #!+sb-doc
  "Evaluate FORM and return the Nth value (zero based). This involves no
  consing when N is a trivial constant integer."
  ;; FIXME: The above is true, if slightly misleading.  The
  ;; MULTIPLE-VALUE-BIND idiom [ as opposed to MULTIPLE-VALUE-CALL
  ;; (LAMBDA (&REST VALUES) (NTH N VALUES)) ] does indeed not cons at
  ;; runtime.  However, for large N (say N = 200), COMPILE on such a
  ;; form will take longer than can be described as adequate, as the
  ;; optional dispatch mechanism for the M-V-B gets increasingly
  ;; hairy.
  (if (integerp n)
      (let ((dummy-list (make-gensym-list n))
            (keeper (sb!xc:gensym "KEEPER")))
        `(multiple-value-bind (,@dummy-list ,keeper) ,form
           (declare (ignore ,@dummy-list))
           ,keeper))
      (once-only ((n n))
        `(case (the fixnum ,n)
           (0 (nth-value 0 ,form))
           (1 (nth-value 1 ,form))
           (2 (nth-value 2 ,form))
           (t (nth (the fixnum ,n) (multiple-value-list ,form)))))))

(defmacro-mundanely declaim (&rest specs)
  #!+sb-doc
  "DECLAIM Declaration*
  Do a declaration or declarations for the global environment."
  `(eval-when (:compile-toplevel :load-toplevel :execute)
     ,@(mapcar (lambda (spec) `(sb!xc:proclaim ',spec))
               specs)))

(defmacro-mundanely print-unreadable-object ((object stream &key type identity)
                                             &body body)
  "Output OBJECT to STREAM with \"#<\" prefix, \">\" suffix, optionally
  with object-type prefix and object-identity suffix, and executing the
  code in BODY to provide possible further output."
  `(%print-unreadable-object ,object ,stream ,type ,identity
                             ,(if body
                                  `(lambda () ,@body)
                                  nil)))

(defmacro-mundanely ignore-errors (&rest forms)
  #!+sb-doc
  "Execute FORMS handling ERROR conditions, returning the result of the last
  form, or (VALUES NIL the-ERROR-that-was-caught) if an ERROR was handled."
  `(handler-case (progn ,@forms)
     (error (condition) (values nil condition))))
