;;;; This software is part of the SBCL system. See the README file for
;;;; more information.

;;;; This software is derived from software originally released by Xerox
;;;; Corporation. Copyright and release statements follow. Later modifications
;;;; to the software are in the public domain and are provided with
;;;; absolutely no warranty. See the COPYING and CREDITS files for more
;;;; information.

;;;; copyright information from original PCL sources:
;;;;
;;;; Copyright (c) 1985, 1986, 1987, 1988, 1989, 1990 Xerox Corporation.
;;;; All rights reserved.
;;;;
;;;; Use and copying of this software and preparation of derivative works based
;;;; upon this software are permitted. Any distribution of this software or
;;;; derivative works must comply with all applicable United States export
;;;; control laws.
;;;;
;;;; This software is made available AS IS, and Xerox Corporation makes no
;;;; warranty about the software, its performance or its conformity to any
;;;; specification.

(in-package "SB-PCL")

;;; methods
;;;
;;; Methods themselves are simple inanimate objects. Most properties of
;;; methods are immutable, methods cannot be reinitialized. The following
;;; properties of methods can be changed:
;;;   METHOD-GENERIC-FUNCTION

;;; initialization
;;;
;;; Error checking is done in before methods. Because of the simplicity of
;;; standard method objects the standard primary method can fill the slots.
;;;
;;; Methods are not reinitializable.

(define-condition metaobject-initialization-violation
    (reference-condition simple-error)
  ())

(macrolet ((def (name args control)
               `(defmethod ,name ,args
                 (declare (ignore initargs))
                 (error 'metaobject-initialization-violation
                  :format-control ,(format nil "~@<~A~@:>" control)
                  :format-arguments (list ',name)
                  :references (list '(:amop :initialization method))))))
  (def reinitialize-instance ((method method) &rest initargs)
    "Method objects cannot be redefined by ~S.")
  (def change-class ((method method) new &rest initargs)
    "Method objects cannot be redefined by ~S.")
  ;; NEW being a subclass of method is dealt with in the general
  ;; method of CHANGE-CLASS
  (def update-instance-for-redefined-class ((method method) added discarded
                                            plist &rest initargs)
    "No behaviour specified for ~S on method objects.")
  (def update-instance-for-different-class (old (new method) &rest initargs)
    "No behaviour specified for ~S on method objects.")
  (def update-instance-for-different-class ((old method) new &rest initargs)
    "No behaviour specified for ~S on method objects."))

(define-condition invalid-method-initarg (simple-program-error)
  ((method :initarg :method :reader invalid-method-initarg-method))
  (:report
   (lambda (c s)
     (format s "~@<In initialization of ~S:~2I~_~?~@:>"
             (invalid-method-initarg-method c)
             (simple-condition-format-control c)
             (simple-condition-format-arguments c)))))

(defun invalid-method-initarg (method format-control &rest args)
  (error 'invalid-method-initarg :method method
         :format-control format-control :format-arguments args))

(defun check-documentation (method doc)
  (unless (or (null doc) (stringp doc))
    (invalid-method-initarg method "~@<~S of ~S is neither ~S nor a ~S.~@:>"
                            :documentation doc 'null 'string)))
(defun check-lambda-list (method ll)
  nil)

(defun check-method-function (method fun)
  (unless (functionp fun)
    (invalid-method-initarg method "~@<~S of ~S is not a ~S.~@:>"
                            :function fun 'function)))

(defun check-qualifiers (method qualifiers)
  (flet ((improper-list ()
           (invalid-method-initarg method
                                   "~@<~S of ~S is an improper list.~@:>"
                                   :qualifiers qualifiers)))
    (dolist-carefully (q qualifiers improper-list)
      (unless (and q (atom q))
        (invalid-method-initarg method
                                "~@<~S, in ~S ~S, is not a non-~S atom.~@:>"
                                q :qualifiers qualifiers 'null)))))

(defun check-slot-name (method name)
  (unless (symbolp name)
    (invalid-method-initarg "~@<~S of ~S is not a ~S.~@:>"
                            :slot-name name 'symbol)))

(defun check-specializers (method specializers)
  (flet ((improper-list ()
           (invalid-method-initarg method
                                   "~@<~S of ~S is an improper list.~@:>"
                                   :specializers specializers)))
    (dolist-carefully (s specializers improper-list)
      (unless (specializerp s)
        (invalid-method-initarg method
                                "~@<~S, in ~S ~S, is not a ~S.~@:>"
                                s :specializers specializers 'specializer)))
    ;; KLUDGE: ANSI says that it's not valid to have methods
    ;; specializing on classes which are "not defined", leaving
    ;; unclear what the definedness of a class is; AMOP suggests that
    ;; forward-referenced-classes, since they have proper names and
    ;; all, are at least worthy of some level of definition.  We allow
    ;; methods specialized on forward-referenced-classes, but it's
    ;; non-portable and potentially dubious, so
    (let ((frcs (remove-if-not #'forward-referenced-class-p specializers)))
      (unless (null frcs)
        (style-warn "~@<Defining a method using ~
                     ~V[~;~1{~S~}~;~1{~S and ~S~}~:;~{~#[~;and ~]~S~^, ~}~] ~
                     as ~2:*~V[~;a specializer~:;specializers~].~@:>"
                    (length frcs) frcs)))))

(defmethod shared-initialize :before
    ((method standard-method) slot-names &key
     qualifiers lambda-list specializers function documentation)
  (declare (ignore slot-names))
  ;; FIXME: it's not clear to me (CSR, 2006-08-09) why methods get
  ;; this extra paranoia and nothing else does; either everything
  ;; should be aggressively checking initargs, or nothing much should.
  ;; In either case, it would probably be better to have :type
  ;; declarations in slots, which would then give a suitable type
  ;; error (if we implement type-checking for slots...) rather than
  ;; this hand-crafted thing.
  (check-qualifiers method qualifiers)
  (check-lambda-list method lambda-list)
  (check-specializers method specializers)
  (check-method-function method function)
  (check-documentation method documentation))

(defmethod shared-initialize :before
    ((method standard-accessor-method) slot-names &key
     slot-name slot-definition)
  (declare (ignore slot-names))
  (unless slot-definition
    (check-slot-name method slot-name)))

(defmethod shared-initialize :after ((method standard-method) slot-names
                                     &rest initargs &key ((method-cell method-cell)))
  (declare (ignore slot-names method-cell))
  (initialize-method-function initargs method))

(defvar *the-class-generic-function*
  (find-class 'generic-function))
(defvar *the-class-standard-generic-function*
  (find-class 'standard-generic-function))

(defmethod shared-initialize :before
           ((generic-function standard-generic-function)
            slot-names
            &key (name nil namep)
                 (lambda-list () lambda-list-p)
                 argument-precedence-order
                 declarations
                 documentation
                 (method-class nil method-class-supplied-p)
                 (method-combination nil method-combination-supplied-p))
  (declare (ignore slot-names
                   declarations argument-precedence-order documentation
                   lambda-list lambda-list-p))

  (when namep
    (set-fun-name generic-function name))

  (flet ((initarg-error (initarg value string)
           (error "when initializing the generic function ~S:~%~
                   The ~S initialization argument was: ~A.~%~
                   It must be ~A."
                  generic-function initarg value string)))
    (cond (method-class-supplied-p
           (when (symbolp method-class)
             (setq method-class (find-class method-class)))
           (unless (and (classp method-class)
                        (*subtypep (class-eq-specializer method-class)
                                   *the-class-method*))
             (initarg-error :method-class
                            method-class
                            "a subclass of the class METHOD"))
           (setf (slot-value generic-function 'method-class) method-class))
          ((slot-boundp generic-function 'method-class))
          (t
           (initarg-error :method-class
                          "not supplied"
                          "a subclass of the class METHOD")))
    (cond (method-combination-supplied-p
           (unless (method-combination-p method-combination)
             (initarg-error :method-combination
                            method-combination
                            "a method combination object")))
          ((slot-boundp generic-function '%method-combination))
          (t
           (initarg-error :method-combination
                          "not supplied"
                          "a method combination object")))))

(defun find-generic-function (name &optional (errorp t))
  (let ((fun (and (fboundp name) (fdefinition name))))
    (cond
      ((and fun (typep fun 'generic-function)) fun)
      (errorp (error "No generic function named ~S." name))
      (t nil))))

(defun real-add-named-method (generic-function-name qualifiers
                              specializers lambda-list &rest other-initargs)
  (unless (and (fboundp generic-function-name)
               (typep (fdefinition generic-function-name) 'generic-function))
    (warn 'implicit-generic-function-warning :name generic-function-name))
  (let* ((existing-gf (find-generic-function generic-function-name nil))
         (generic-function
          (if existing-gf
              (ensure-generic-function
               generic-function-name
               :generic-function-class (class-of existing-gf))
              (ensure-generic-function generic-function-name)))
         (proto (method-prototype-for-gf generic-function-name)))
    ;; FIXME: Destructive modification of &REST list.
    (setf (getf (getf other-initargs 'plist) :name)
          (make-method-spec generic-function qualifiers specializers))
    (let ((new (apply #'make-instance (class-of proto)
                      :qualifiers qualifiers :specializers specializers
                      :lambda-list lambda-list other-initargs)))
      (add-method generic-function new)
      new)))

(define-condition find-method-length-mismatch
    (reference-condition simple-error)
  ()
  (:default-initargs :references (list '(:ansi-cl :function find-method))))

(defun real-get-method (generic-function qualifiers specializers
                        &optional (errorp t)
                        always-check-specializers)
  (let ((lspec (length specializers))
        (methods (generic-function-methods generic-function)))
    (when (or methods always-check-specializers)
      (let ((nreq (length (arg-info-metatypes (gf-arg-info
                                               generic-function)))))
        ;; Since we internally bypass FIND-METHOD by using GET-METHOD
        ;; instead we need to to this here or users may get hit by a
        ;; failed AVER instead of a sensible error message.
        (when (/= lspec nreq)
          (error
           'find-method-length-mismatch
           :format-control
           "~@<The generic function ~S takes ~D required argument~:P; ~
            was asked to find a method with specializers ~S~@:>"
           :format-arguments (list generic-function nreq specializers)))))
    (let ((hit
           (dolist (method methods)
             (let ((mspecializers (method-specializers method)))
               (aver (= lspec (length mspecializers)))
               (when (and (equal qualifiers (safe-method-qualifiers method))
                          (every #'same-specializer-p specializers
                                 (method-specializers method)))
                 (return method))))))
      (cond (hit hit)
            ((null errorp) nil)
            (t
             (error "~@<There is no method on ~S with ~
                    ~:[no qualifiers~;~:*qualifiers ~S~] ~
                    and specializers ~S.~@:>"
                    generic-function qualifiers specializers))))))

(defmethod find-method ((generic-function standard-generic-function)
                        qualifiers specializers &optional (errorp t))
  ;; ANSI about FIND-METHOD: "The specializers argument contains the
  ;; parameter specializers for the method. It must correspond in
  ;; length to the number of required arguments of the generic
  ;; function, or an error is signaled."
  ;;
  ;; This error checking is done by REAL-GET-METHOD.
  (real-get-method
   generic-function qualifiers
   ;; ANSI for FIND-METHOD seems to imply that in fact specializers
   ;; should always be passed in parsed form instead of being parsed
   ;; at this point.  Since there's no ANSI-blessed way of getting an
   ;; EQL specializer, that seems unnecessarily painful, so we are
   ;; nice to our users.  -- CSR, 2007-06-01
   (parse-specializers generic-function specializers) errorp t))

;;; Compute various information about a generic-function's arglist by looking
;;; at the argument lists of the methods. The hair for trying not to use
;;; &REST arguments lives here.
;;;  The values returned are:
;;;    number-of-required-arguments
;;;       the number of required arguments to this generic-function's
;;;       discriminating function
;;;    &rest-argument-p
;;;       whether or not this generic-function's discriminating
;;;       function takes an &rest argument.
;;;    specialized-argument-positions
;;;       a list of the positions of the arguments this generic-function
;;;       specializes (e.g. for a classical generic-function this is the
;;;       list: (1)).
(defmethod compute-discriminating-function-arglist-info
           ((generic-function standard-generic-function))
  ;;(declare (values number-of-required-arguments &rest-argument-p
  ;;             specialized-argument-postions))
  (let ((number-required nil)
        (restp nil)
        (specialized-positions ())
        (methods (generic-function-methods generic-function)))
    (dolist (method methods)
      (multiple-value-setq (number-required restp specialized-positions)
        (compute-discriminating-function-arglist-info-internal
         generic-function method number-required restp specialized-positions)))
    (values number-required restp (sort specialized-positions #'<))))

(defun compute-discriminating-function-arglist-info-internal
       (generic-function method number-of-requireds restp
        specialized-argument-positions)
  (declare (ignore generic-function)
           (type (or null fixnum) number-of-requireds))
  (let ((requireds 0))
    (declare (fixnum requireds))
    ;; Go through this methods arguments seeing how many are required,
    ;; and whether there is an &rest argument.
    (dolist (arg (method-lambda-list method))
      (cond ((eq arg '&aux) (return))
            ((memq arg '(&optional &rest &key))
             (return (setq restp t)))
            ((memq arg lambda-list-keywords))
            (t (incf requireds))))
    ;; Now go through this method's type specifiers to see which
    ;; argument positions are type specified. Treat T specially
    ;; in the usual sort of way. For efficiency don't bother to
    ;; keep specialized-argument-positions sorted, rather depend
    ;; on our caller to do that.
    (let ((pos 0))
      (dolist (type-spec (method-specializers method))
        (unless (eq type-spec *the-class-t*)
          (pushnew pos specialized-argument-positions :test #'eq))
        (incf pos)))
    ;; Finally merge the values for this method into the values
    ;; for the exisiting methods and return them. Note that if
    ;; num-of-requireds is NIL it means this is the first method
    ;; and we depend on that.
    (values (min (or number-of-requireds requireds) requireds)
            (or restp
                (and number-of-requireds (/= number-of-requireds requireds)))
            specialized-argument-positions)))

(defun make-discriminating-function-arglist (number-required-arguments restp)
  (nconc (let ((args nil))
           (dotimes (i number-required-arguments)
             (push (format-symbol *package* ;; ! is this right?
                                  "Discriminating Function Arg ~D"
                                  i)
                   args))
           (nreverse args))
         (when restp
               `(&rest ,(format-symbol *package*
                                       "Discriminating Function &rest Arg")))))

(defmethod generic-function-argument-precedence-order
    ((gf standard-generic-function))
  (aver (eq **boot-state** 'complete))
  (loop with arg-info = (gf-arg-info gf)
        with lambda-list = (arg-info-lambda-list arg-info)
        for argument-position in (arg-info-precedence arg-info)
        collect (nth argument-position lambda-list)))

(defmethod generic-function-lambda-list ((gf generic-function))
  (gf-lambda-list gf))

(defmethod gf-fast-method-function-p ((gf standard-generic-function))
  (gf-info-fast-mf-p (slot-value gf 'arg-info)))

(defmethod initialize-instance :after ((gf standard-generic-function)
                                       &key (lambda-list nil lambda-list-p)
                                       argument-precedence-order)
  (with-slots (arg-info) gf
    (if lambda-list-p
        (set-arg-info gf
                      :lambda-list lambda-list
                      :argument-precedence-order argument-precedence-order)
        (set-arg-info gf))
    (when (arg-info-valid-p arg-info)
      (update-dfun gf))))

(defmethod reinitialize-instance :around
    ((gf standard-generic-function) &rest args &key
     (lambda-list nil lambda-list-p) (argument-precedence-order nil apo-p))
  (let ((old-mc (generic-function-method-combination gf)))
    (prog1 (call-next-method)
      ;; KLUDGE: EQ is too strong a test.
      (unless (eq old-mc (generic-function-method-combination gf))
        (flush-effective-method-cache gf))
      (cond
        ((and lambda-list-p apo-p)
         (set-arg-info gf
                       :lambda-list lambda-list
                       :argument-precedence-order argument-precedence-order))
        (lambda-list-p (set-arg-info gf :lambda-list lambda-list))
        (t (set-arg-info gf)))
      (when (arg-info-valid-p (gf-arg-info gf))
        (update-dfun gf))
      (map-dependents gf (lambda (dependent)
                           (apply #'update-dependent gf dependent args))))))

(declaim (special *lazy-dfun-compute-p*))

(defun set-methods (gf methods)
  (setf (generic-function-methods gf) nil)
  (loop (when (null methods) (return gf))
        (real-add-method gf (pop methods) methods)))

(define-condition new-value-specialization (reference-condition error)
  ((%method :initarg :method :reader new-value-specialization-method))
  (:report
   (lambda (c s)
     (format s "~@<Cannot add method ~S to ~S, as it specializes the ~
                new-value argument.~@:>"
             (new-value-specialization-method c)
             #'(setf slot-value-using-class))))
  (:default-initargs :references
      (list '(:sbcl :node "Metaobject Protocol")
            '(:amop :generic-function (setf slot-value-using-class)))))

(defgeneric values-for-add-method (gf method)
  (:method ((gf standard-generic-function) (method standard-method))
    ;; KLUDGE: Just a single generic dispatch, and everything else
    ;; comes from permutation vectors. Would be nicer to define
    ;; REAL-ADD-METHOD with a proper method so that we could efficiently
    ;; use SLOT-VALUE there.
    ;;
    ;; Optimization note: REAL-ADD-METHOD has a lot of O(N) stuff in it (as
    ;; does PCL as a whole). It should not be too hard to internally store
    ;; many of the things we now keep in lists as either purely functional
    ;; O(log N) sets, or --if we don't mind the memory cost-- using
    ;; specialized hash-tables: most things are used to answer questions about
    ;; set-membership, not ordering.
    (values (slot-value gf '%lock)
            (slot-value method 'qualifiers)
            (slot-value method 'specializers)
            (slot-value method 'lambda-list)
            (slot-value method '%generic-function)
            (slot-value gf 'name))))

(define-condition print-object-stream-specializer (reference-condition simple-warning)
  ()
  (:default-initargs
   :references (list '(:ansi-cl :function print-object))
   :format-control "~@<Specializing on the second argument to ~S has ~
                    unportable effects, and also interferes with ~
                    precomputation of print functions for exceptional ~
                    situations.~@:>"
   :format-arguments (list 'print-object)))

(defun real-add-method (generic-function method &optional skip-dfun-update-p)
  (flet ((similar-lambda-lists-p (old-method new-lambda-list)
           (multiple-value-bind (a-nreq a-nopt a-keyp a-restp)
               (analyze-lambda-list (method-lambda-list old-method))
             (multiple-value-bind (b-nreq b-nopt b-keyp b-restp)
                 (analyze-lambda-list new-lambda-list)
               (and (= a-nreq b-nreq)
                    (= a-nopt b-nopt)
                    (eq (or a-keyp a-restp)
                        (or b-keyp b-restp)))))))
    (multiple-value-bind (lock qualifiers specializers new-lambda-list
                          method-gf name)
        (values-for-add-method generic-function method)
      (when method-gf
        (error "~@<The method ~S is already part of the generic ~
                function ~S; it can't be added to another generic ~
                function until it is removed from the first one.~@:>"
               method method-gf))
      (when (and (eq name 'print-object) (not (eq (second specializers) *the-class-t*)))
        (warn 'print-object-stream-specializer))
      (handler-case
          ;; System lock because interrupts need to be disabled as
          ;; well: it would be bad to unwind and leave the gf in an
          ;; inconsistent state.
          (sb-thread::with-recursive-system-spinlock (lock)
            (let ((existing (get-method generic-function
                                        qualifiers
                                        specializers
                                        nil)))

              ;; If there is already a method like this one then we must get
              ;; rid of it before proceeding.  Note that we call the generic
              ;; function REMOVE-METHOD to remove it rather than doing it in
              ;; some internal way.
              (when (and existing (similar-lambda-lists-p existing new-lambda-list))
                (remove-method generic-function existing))

              ;; KLUDGE: We have a special case here, as we disallow
              ;; specializations of the NEW-VALUE argument to (SETF
              ;; SLOT-VALUE-USING-CLASS).  GET-ACCESSOR-METHOD-FUNCTION is
              ;; the optimizing function here: it precomputes the effective
              ;; method, assuming that there is no dispatch to be done on
              ;; the new-value argument.
              (when (and (eq generic-function #'(setf slot-value-using-class))
                         (not (eq *the-class-t* (first specializers))))
                (error 'new-value-specialization :method  method))

              (setf (method-generic-function method) generic-function)
              (pushnew method (generic-function-methods generic-function) :test #'eq)
              (dolist (specializer specializers)
                (add-direct-method specializer method))

              ;; KLUDGE: SET-ARG-INFO contains the error-detecting logic for
              ;; detecting attempts to add methods with incongruent lambda
              ;; lists.  However, according to Gerd Moellmann on cmucl-imp,
              ;; it also depends on the new method already having been added
              ;; to the generic function.  Therefore, we need to remove it
              ;; again on error:
              (let ((remove-again-p t))
                (unwind-protect
                     (progn
                       (set-arg-info generic-function :new-method method)
                       (setq remove-again-p nil))
                  (when remove-again-p
                    (remove-method generic-function method))))

              ;; KLUDGE II: ANSI saith that it is not an error to add a
              ;; method with invalid qualifiers to a generic function of the
              ;; wrong kind; it's only an error at generic function
              ;; invocation time; I dunno what the rationale was, and it
              ;; sucks.  Nevertheless, it's probably a programmer error, so
              ;; let's warn anyway. -- CSR, 2003-08-20
              (let ((mc (generic-function-method-combination generic-functioN)))
                (cond
                  ((eq mc *standard-method-combination*)
                   (when (and qualifiers
                              (or (cdr qualifiers)
                                  (not (memq (car qualifiers)
                                             '(:around :before :after)))))
                     (warn "~@<Invalid qualifiers for standard method ~
                            combination in method ~S:~2I~_~S.~@:>"
                           method qualifiers)))
                  ((short-method-combination-p mc)
                   (let ((mc-name (method-combination-type-name mc)))
                     (when (or (null qualifiers)
                               (cdr qualifiers)
                               (and (neq (car qualifiers) :around)
                                    (neq (car qualifiers) mc-name)))
                       (warn "~@<Invalid qualifiers for ~S method combination ~
                              in method ~S:~2I~_~S.~@:>"
                             mc-name method qualifiers))))))
              (unless skip-dfun-update-p
                (update-ctors 'add-method
                              :generic-function generic-function
                              :method method)
                (update-dfun generic-function))
              (setf (gf-info-needs-update generic-function) t)
              (map-dependents generic-function
                              (lambda (dep)
                                (update-dependent generic-function
                                                  dep 'add-method method)))))
        (serious-condition (c)
          (error c)))))
  generic-function)

(defun real-remove-method (generic-function method)
  (when (eq generic-function (method-generic-function method))
    (let ((lock (gf-lock generic-function)))
      ;; System lock because interrupts need to be disabled as well:
      ;; it would be bad to unwind and leave the gf in an inconsistent
      ;; state.
      (sb-thread::with-recursive-system-spinlock (lock)
        (let* ((specializers (method-specializers method))
               (methods (generic-function-methods generic-function))
               (new-methods (remove method methods)))
          (setf (method-generic-function method) nil
                (generic-function-methods generic-function) new-methods)
          (dolist (specializer (method-specializers method))
            (remove-direct-method specializer method))
          (set-arg-info generic-function)
          (update-ctors 'remove-method
                        :generic-function generic-function
                        :method method)
          (update-dfun generic-function)
          (setf (gf-info-needs-update generic-function) t)
          (map-dependents generic-function
                          (lambda (dep)
                            (update-dependent generic-function
                                              dep 'remove-method method)))))))
  generic-function)


;; Tell INFO about the generic function's methods' keys so that the
;; compiler doesn't complain that the keys defined for some method are
;; unrecognized.
(sb-ext:without-package-locks
  (defun sb-c::maybe-update-info-for-gf (name)
    (let ((gf (if (fboundp name) (fdefinition name))))
      (when (and gf (generic-function-p gf) (not (early-gf-p gf))
                 (not (eq :declared (info :function :where-from name)))
                 (gf-info-needs-update gf))
        (let* ((methods (generic-function-methods gf))
               (gf-lambda-list (generic-function-lambda-list gf))
               (tfun (constantly t))
               keysp)
          (multiple-value-bind (gf.required gf.optional gf.restp gf.rest
                                            gf.keyp gf.keys gf.allowp)
              (parse-lambda-list gf-lambda-list)
            (declare (ignore gf.rest))
            ;; 7.6.4 point 5 probably entails that if any method says
            ;; &allow-other-keys then the gf should be construed to
            ;; accept any key.
            (let* ((allowp (or gf.allowp
                               (find '&allow-other-keys methods
                                     :test #'find
                                     :key #'method-lambda-list)))
                   (ftype
                    (specifier-type
                     `(function
                       (,@(mapcar tfun gf.required)
                          ,@(if gf.optional
                                `(&optional ,@(mapcar tfun gf.optional)))
                          ,@(if gf.restp
                                `(&rest t))
                          ,@(when gf.keyp
                              (let ((all-keys
                                     (mapcar
                                      (lambda (x)
                                        (list x t))
                                      (remove-duplicates
                                       (nconc
                                        (mapcan #'function-keywords methods)
                                        (mapcar #'keywordicate gf.keys))))))
                                (when all-keys
                                  (setq keysp t)
                                  `(&key ,@all-keys))))
                          ,@(when (and (not keysp) allowp)
                              `(&key))
                          ,@(when allowp
                              `(&allow-other-keys)))
                       *))))
              (setf (info :function :type name) ftype
                    (info :function :where-from name) :defined-method
                    (gf-info-needs-update gf) nil)
              ftype)))))))

(defun compute-applicable-methods-function (generic-function arguments)
  (values (compute-applicable-methods-using-types
           generic-function
           (types-from-args generic-function arguments 'eql))))

(defmethod compute-applicable-methods
    ((generic-function generic-function) arguments)
  (values (compute-applicable-methods-using-types
           generic-function
           (types-from-args generic-function arguments 'eql))))

(defmethod compute-applicable-methods-using-classes
    ((generic-function generic-function) classes)
  (compute-applicable-methods-using-types
   generic-function
   (types-from-args generic-function classes 'class-eq)))

(defun proclaim-incompatible-superclasses (classes)
  (setq classes (mapcar (lambda (class)
                          (if (symbolp class)
                              (find-class class)
                              class))
                        classes))
  (dolist (class classes)
    (dolist (other-class classes)
      (unless (eq class other-class)
        (pushnew other-class (class-incompatible-superclass-list class) :test #'eq)))))

(defun superclasses-compatible-p (class1 class2)
  (let ((cpl1 (cpl-or-nil class1))
        (cpl2 (cpl-or-nil class2)))
    (dolist (sc1 cpl1 t)
      (dolist (ic (class-incompatible-superclass-list sc1))
        (when (memq ic cpl2)
          (return-from superclasses-compatible-p nil))))))

(mapc
 #'proclaim-incompatible-superclasses
 '(;; superclass class
   (built-in-class std-class structure-class) ; direct subclasses of pcl-class
   (standard-class funcallable-standard-class)
   ;; superclass metaobject
   (class eql-specializer class-eq-specializer method method-combination
    generic-function slot-definition)
   ;; metaclass built-in-class
   (number sequence character           ; direct subclasses of t, but not array
    standard-object structure-object)   ;                        or symbol
   (number array character symbol       ; direct subclasses of t, but not
    standard-object structure-object)   ;                        sequence
   (complex float rational)             ; direct subclasses of number
   (integer ratio)                      ; direct subclasses of rational
   (list vector)                        ; direct subclasses of sequence
   (cons null)                          ; direct subclasses of list
   (string bit-vector)                  ; direct subclasses of vector
   ))

(defmethod same-specializer-p ((specl1 specializer) (specl2 specializer))
  (eql specl1 specl2))

(defmethod same-specializer-p ((specl1 class) (specl2 class))
  (eq specl1 specl2))

(defmethod specializer-class ((specializer class))
  specializer)

(defmethod same-specializer-p ((specl1 class-eq-specializer)
                               (specl2 class-eq-specializer))
  (eq (specializer-class specl1) (specializer-class specl2)))

(defmethod same-specializer-p ((specl1 eql-specializer)
                               (specl2 eql-specializer))
  (eq (specializer-object specl1) (specializer-object specl2)))

(defmethod specializer-class ((specializer eql-specializer))
  (class-of (slot-value specializer 'object)))

(defun specializer-class-or-nil (specializer)
  (and (standard-specializer-p specializer)
       (specializer-class specializer)))

(defun error-need-at-least-n-args (function n)
  (error 'simple-program-error
         :format-control "~@<The function ~2I~_~S ~I~_requires ~
                          at least ~W argument~:P.~:>"
         :format-arguments (list function n)))

(defun types-from-args (generic-function arguments &optional type-modifier)
  (multiple-value-bind (nreq applyp metatypes nkeys arg-info)
      (get-generic-fun-info generic-function)
    (declare (ignore applyp metatypes nkeys))
    (let ((types-rev nil))
      (dotimes-fixnum (i nreq)
        i
        (unless arguments
          (error-need-at-least-n-args (generic-function-name generic-function)
                                      nreq))
        (let ((arg (pop arguments)))
          (push (if type-modifier `(,type-modifier ,arg) arg) types-rev)))
      (values (nreverse types-rev) arg-info))))

(defun get-wrappers-from-classes (nkeys wrappers classes metatypes)
  (let* ((w wrappers) (w-tail w) (mt-tail metatypes))
    (dolist (class (if (listp classes) classes (list classes)))
      (unless (eq t (car mt-tail))
        (let ((c-w (class-wrapper class)))
          (unless c-w (return-from get-wrappers-from-classes nil))
          (if (eql nkeys 1)
              (setq w c-w)
              (setf (car w-tail) c-w
                    w-tail (cdr w-tail)))))
      (setq mt-tail (cdr mt-tail)))
    w))

(defun sdfun-for-caching (gf classes)
  (let ((types (mapcar #'class-eq-type classes)))
    (multiple-value-bind (methods all-applicable-and-sorted-p)
        (compute-applicable-methods-using-types gf types)
      (let ((generator (get-secondary-dispatch-function1
                        gf methods types nil t all-applicable-and-sorted-p)))
        (make-callable gf methods generator
                       nil (mapcar #'class-wrapper classes))))))

(defun value-for-caching (gf classes)
  (let ((methods (compute-applicable-methods-using-types
                   gf (mapcar #'class-eq-type classes))))
    (method-plist-value (car methods) :constant-value)))

(defun default-secondary-dispatch-function (generic-function)
  (lambda (&rest args)
    (let ((methods (compute-applicable-methods generic-function args)))
      (if methods
          (let ((emf (get-effective-method-function generic-function
                                                    methods)))
            (invoke-emf emf args))
          (call-no-applicable-method generic-function args)))))

(defun list-eq (x y)
  (loop (when (atom x) (return (eq x y)))
        (when (atom y) (return nil))
        (unless (eq (car x) (car y)) (return nil))
        (setq x (cdr x)
              y (cdr y))))

(defvar *std-cam-methods* nil)

(defun compute-applicable-methods-emf (generic-function)
  (if (eq **boot-state** 'complete)
      (let* ((cam (gdefinition 'compute-applicable-methods))
             (cam-methods (compute-applicable-methods-using-types
                           cam (list `(eql ,generic-function) t))))
        (values (get-effective-method-function cam cam-methods)
                (list-eq cam-methods
                         (or *std-cam-methods*
                             (setq *std-cam-methods*
                                   (compute-applicable-methods-using-types
                                    cam (list `(eql ,cam) t)))))))
      (values #'compute-applicable-methods-function t)))

(defun compute-applicable-methods-emf-std-p (gf)
  (gf-info-c-a-m-emf-std-p (gf-arg-info gf)))

(defvar *old-c-a-m-gf-methods* nil)

(defun update-all-c-a-m-gf-info (c-a-m-gf)
  (let ((methods (generic-function-methods c-a-m-gf)))
    (if (and *old-c-a-m-gf-methods*
             (every (lambda (old-method)
                      (member old-method methods :test #'eq))
                    *old-c-a-m-gf-methods*))
        (let ((gfs-to-do nil)
              (gf-classes-to-do nil))
          (dolist (method methods)
            (unless (member method *old-c-a-m-gf-methods* :test #'eq)
              (let ((specl (car (method-specializers method))))
                (if (eql-specializer-p specl)
                    (pushnew (specializer-object specl) gfs-to-do :test #'eq)
                    (pushnew (specializer-class specl) gf-classes-to-do :test #'eq)))))
          (map-all-generic-functions
           (lambda (gf)
             (when (or (member gf gfs-to-do :test #'eq)
                       (dolist (class gf-classes-to-do nil)
                         (member class
                                 (class-precedence-list (class-of gf))
                                 :test #'eq)))
               (update-c-a-m-gf-info gf)))))
        (map-all-generic-functions #'update-c-a-m-gf-info))
    (setq *old-c-a-m-gf-methods* methods)))

(defun update-gf-info (gf)
  (update-c-a-m-gf-info gf)
  (update-gf-simple-accessor-type gf))

(defun update-c-a-m-gf-info (gf)
  (unless (early-gf-p gf)
    (multiple-value-bind (c-a-m-emf std-p)
        (compute-applicable-methods-emf gf)
      (let ((arg-info (gf-arg-info gf)))
        (setf (gf-info-static-c-a-m-emf arg-info) c-a-m-emf)
        (setf (gf-info-c-a-m-emf-std-p arg-info) std-p)))))

(defun update-gf-simple-accessor-type (gf)
  (let ((arg-info (gf-arg-info gf)))
    (setf (gf-info-simple-accessor-type arg-info)
          (let* ((methods (generic-function-methods gf))
                 (class (and methods (class-of (car methods))))
                 (type
                  (and class
                       (cond ((or (eq class *the-class-standard-reader-method*)
                                  (eq class *the-class-global-reader-method*))
                              'reader)
                             ((or (eq class *the-class-standard-writer-method*)
                                  (eq class *the-class-global-writer-method*))
                              'writer)
                             ((or (eq class *the-class-standard-boundp-method*)
                                  (eq class *the-class-global-boundp-method*))
                              'boundp)))))
            (when (and (gf-info-c-a-m-emf-std-p arg-info)
                       type
                       (dolist (method (cdr methods) t)
                         (unless (eq class (class-of method)) (return nil)))
                       (eq (generic-function-method-combination gf)
                           *standard-method-combination*))
              type)))))


;;; CMUCL (Gerd's PCL, 2002-04-25) comment:
;;;
;;; Return two values.  First value is a function to be stored in
;;; effective slot definition SLOTD for reading it with
;;; SLOT-VALUE-USING-CLASS, setting it with (SETF
;;; SLOT-VALUE-USING-CLASS) or testing it with
;;; SLOT-BOUNDP-USING-CLASS.  GF is one of these generic functions,
;;; TYPE is one of the symbols READER, WRITER, BOUNDP.  CLASS is
;;; SLOTD's class.
;;;
;;; Second value is true if the function returned is one of the
;;; optimized standard functions for the purpose, which are used
;;; when only standard methods are applicable.
;;;
;;; FIXME: Change all these wacky function names to something sane.
(defun get-accessor-method-function (gf type class slotd)
  (let* ((std-method (standard-svuc-method type))
         (str-method (structure-svuc-method type))
         (types1 `((eql ,class) (class-eq ,class) (eql ,slotd)))
         (types (if (eq type 'writer) `(t ,@types1) types1))
         (methods (compute-applicable-methods-using-types gf types))
         (std-p (null (cdr methods))))
    (values
     (if std-p
         (get-optimized-std-accessor-method-function class slotd type)
         (let* ((optimized-std-fun
                 (get-optimized-std-slot-value-using-class-method-function
                  class slotd type))
                (method-alist
                 `((,(car (or (member std-method methods :test #'eq)
                              (member str-method methods :test #'eq)
                              (bug "error in ~S"
                                   'get-accessor-method-function)))
                    ,optimized-std-fun)))
                (wrappers
                 (let ((wrappers (list (wrapper-of class)
                                       (class-wrapper class)
                                       (wrapper-of slotd))))
                   (if (eq type 'writer)
                       (cons (class-wrapper *the-class-t*) wrappers)
                       wrappers)))
                (sdfun (get-secondary-dispatch-function
                        gf methods types method-alist wrappers)))
           (get-accessor-from-svuc-method-function class slotd sdfun type)))
     std-p)))

;;; used by OPTIMIZE-SLOT-VALUE-BY-CLASS-P (vector.lisp)
(defun update-slot-value-gf-info (gf type)
  (unless *new-class*
    (update-std-or-str-methods gf type))
  (when (and (standard-svuc-method type) (structure-svuc-method type))
    (flet ((update-accessor-info (class)
             (when (class-finalized-p class)
               (dolist (slotd (class-slots class))
                 (compute-slot-accessor-info slotd type gf)))))
      (if *new-class*
          (update-accessor-info *new-class*)
          (map-all-classes #'update-accessor-info 'slot-object)))))

(defvar *standard-slot-value-using-class-method* nil)
(defvar *standard-setf-slot-value-using-class-method* nil)
(defvar *standard-slot-boundp-using-class-method* nil)
(defvar *condition-slot-value-using-class-method* nil)
(defvar *condition-setf-slot-value-using-class-method* nil)
(defvar *condition-slot-boundp-using-class-method* nil)
(defvar *structure-slot-value-using-class-method* nil)
(defvar *structure-setf-slot-value-using-class-method* nil)
(defvar *structure-slot-boundp-using-class-method* nil)

(defun standard-svuc-method (type)
  (case type
    (reader *standard-slot-value-using-class-method*)
    (writer *standard-setf-slot-value-using-class-method*)
    (boundp *standard-slot-boundp-using-class-method*)))

(defun set-standard-svuc-method (type method)
  (case type
    (reader (setq *standard-slot-value-using-class-method* method))
    (writer (setq *standard-setf-slot-value-using-class-method* method))
    (boundp (setq *standard-slot-boundp-using-class-method* method))))

(defun condition-svuc-method (type)
  (case type
    (reader *condition-slot-value-using-class-method*)
    (writer *condition-setf-slot-value-using-class-method*)
    (boundp *condition-slot-boundp-using-class-method*)))

(defun set-condition-svuc-method (type method)
  (case type
    (reader (setq *condition-slot-value-using-class-method* method))
    (writer (setq *condition-setf-slot-value-using-class-method* method))
    (boundp (setq *condition-slot-boundp-using-class-method* method))))

(defun structure-svuc-method (type)
  (case type
    (reader *structure-slot-value-using-class-method*)
    (writer *structure-setf-slot-value-using-class-method*)
    (boundp *structure-slot-boundp-using-class-method*)))

(defun set-structure-svuc-method (type method)
  (case type
    (reader (setq *structure-slot-value-using-class-method* method))
    (writer (setq *structure-setf-slot-value-using-class-method* method))
    (boundp (setq *structure-slot-boundp-using-class-method* method))))

(defun update-std-or-str-methods (gf type)
  (dolist (method (generic-function-methods gf))
    (let ((specls (method-specializers method)))
      (when (and (or (not (eq type 'writer))
                     (eq (pop specls) *the-class-t*))
                 (every #'classp specls))
        (cond ((and (eq (class-name (car specls)) 'std-class)
                    (eq (class-name (cadr specls)) 'standard-object)
                    (eq (class-name (caddr specls))
                        'standard-effective-slot-definition))
               (set-standard-svuc-method type method))
              ((and (eq (class-name (car specls)) 'condition-class)
                    (eq (class-name (cadr specls)) 'condition)
                    (eq (class-name (caddr specls))
                        'condition-effective-slot-definition))
               (set-condition-svuc-method type method))
              ((and (eq (class-name (car specls)) 'structure-class)
                    (eq (class-name (cadr specls)) 'structure-object)
                    (eq (class-name (caddr specls))
                        'structure-effective-slot-definition))
               (set-structure-svuc-method type method)))))))

(defun mec-all-classes-internal (spec precompute-p)
  (let ((wrapper (class-wrapper (specializer-class spec))))
    (unless (or (not wrapper) (invalid-wrapper-p wrapper))
      (cons (specializer-class spec)
            (and (classp spec)
                 precompute-p
                 (not (or (eq spec *the-class-t*)
                          (eq spec *the-class-slot-object*)
                          (eq spec *the-class-standard-object*)
                          (eq spec *the-class-structure-object*)))
                 (let ((sc (class-direct-subclasses spec)))
                   (when sc
                     (mapcan (lambda (class)
                               (mec-all-classes-internal class precompute-p))
                             sc))))))))

(defun mec-all-classes (spec precompute-p)
  (let ((classes (mec-all-classes-internal spec precompute-p)))
    (if (null (cdr classes))
        classes
        (let* ((a-classes (cons nil classes))
               (tail classes))
          (loop (when (null (cdr tail))
                  (return (cdr a-classes)))
                (let ((class (cadr tail))
                      (ttail (cddr tail)))
                  (if (dolist (c ttail nil)
                        (when (eq class c) (return t)))
                      (setf (cdr tail) (cddr tail))
                      (setf tail (cdr tail)))))))))

(defun mec-all-class-lists (spec-list precompute-p)
  (if (null spec-list)
      (list nil)
      (let* ((car-all-classes (mec-all-classes (car spec-list)
                                               precompute-p))
             (all-class-lists (mec-all-class-lists (cdr spec-list)
                                                   precompute-p)))
        (mapcan (lambda (list)
                  (mapcar (lambda (c) (cons c list)) car-all-classes))
                all-class-lists))))

(defun make-emf-cache (generic-function valuep cache classes-list new-class)
  (let* ((arg-info (gf-arg-info generic-function))
         (nkeys (arg-info-nkeys arg-info))
         (metatypes (arg-info-metatypes arg-info))
         (wrappers (unless (eq nkeys 1) (make-list nkeys)))
         (precompute-p (gf-precompute-dfun-and-emf-p arg-info)))
    (flet ((add-class-list (classes)
             (when (or (null new-class) (memq new-class classes))
               (let ((%wrappers (get-wrappers-from-classes
                                 nkeys wrappers classes metatypes)))
                 (when (and %wrappers (not (probe-cache cache %wrappers)))
                   (let ((value (cond ((eq valuep t)
                                       (sdfun-for-caching generic-function
                                                          classes))
                                      ((eq valuep :constant-value)
                                       (value-for-caching generic-function
                                                          classes)))))
                     ;; need to get them again, as finalization might
                     ;; have happened in between, which would
                     ;; invalidate wrappers.
                     (let ((wrappers (get-wrappers-from-classes
                                      nkeys wrappers classes metatypes)))
                       (when (if (atom wrappers)
                                 (not (invalid-wrapper-p wrappers))
                                 (every (complement #'invalid-wrapper-p)
                                        wrappers))
                         (setq cache (fill-cache cache wrappers value))))))))))
      (if classes-list
          (mapc #'add-class-list classes-list)
          (dolist (method (generic-function-methods generic-function))
            (mapc #'add-class-list
                  (mec-all-class-lists (method-specializers method)
                                       precompute-p))))
      cache)))

(defmacro class-test (arg class)
  (cond
    ((eq class *the-class-t*) t)
    ((eq class *the-class-slot-object*)
     `(not (typep (classoid-of ,arg) 'built-in-classoid)))
    ((eq class *the-class-standard-object*)
     `(or (std-instance-p ,arg) (fsc-instance-p ,arg)))
    ((eq class *the-class-funcallable-standard-object*)
     `(fsc-instance-p ,arg))
    (t
     `(typep ,arg ',(class-name class)))))

(defmacro class-eq-test (arg class)
  `(eq (class-of ,arg) ',class))

(defmacro eql-test (arg object)
  `(eql ,arg ',object))

(defun dnet-methods-p (form)
  (and (consp form)
       (or (eq (car form) 'methods)
           (eq (car form) 'unordered-methods))))

;;; This is CASE, but without gensyms.
(defmacro scase (arg &rest clauses)
  `(let ((.case-arg. ,arg))
     (cond ,@(mapcar (lambda (clause)
                       (list* (cond ((null (car clause))
                                     nil)
                                    ((consp (car clause))
                                     (if (null (cdar clause))
                                         `(eql .case-arg.
                                               ',(caar clause))
                                         `(member .case-arg.
                                                  ',(car clause))))
                                    ((member (car clause) '(t otherwise))
                                     `t)
                                    (t
                                     `(eql .case-arg. ',(car clause))))
                              nil
                              (cdr clause)))
                     clauses))))

(defmacro mcase (arg &rest clauses) `(scase ,arg ,@clauses))

(defun generate-discrimination-net (generic-function methods types sorted-p)
  (let* ((arg-info (gf-arg-info generic-function))
         (c-a-m-emf-std-p (gf-info-c-a-m-emf-std-p arg-info))
         (precedence (arg-info-precedence arg-info)))
    (generate-discrimination-net-internal
     generic-function methods types
     (lambda (methods known-types)
       (if (or sorted-p
               (and c-a-m-emf-std-p
                    (block one-order-p
                      (let ((sorted-methods nil))
                        (map-all-orders
                         (copy-list methods) precedence
                         (lambda (methods)
                           (when sorted-methods (return-from one-order-p nil))
                           (setq sorted-methods methods)))
                        (setq methods sorted-methods))
                      t)))
           `(methods ,methods ,known-types)
           `(unordered-methods ,methods ,known-types)))
     (lambda (position type true-value false-value)
       (let ((arg (dfun-arg-symbol position)))
         (if (eq (car type) 'eql)
             (let* ((false-case-p (and (consp false-value)
                                       (or (eq (car false-value) 'scase)
                                           (eq (car false-value) 'mcase))
                                       (eq arg (cadr false-value))))
                    (false-clauses (if false-case-p
                                       (cddr false-value)
                                       `((t ,false-value))))
                    (case-sym (if (and (dnet-methods-p true-value)
                                       (if false-case-p
                                           (eq (car false-value) 'mcase)
                                           (dnet-methods-p false-value)))
                                  'mcase
                                  'scase))
                    (type-sym `(,(cadr type))))
               `(,case-sym ,arg
                           (,type-sym ,true-value)
                           ,@false-clauses))
             `(if ,(let ((arg (dfun-arg-symbol position)))
                     (case (car type)
                       (class    `(class-test    ,arg ,(cadr type)))
                       (class-eq `(class-eq-test ,arg ,(cadr type)))))
                  ,true-value
                  ,false-value))))
     #'identity)))

(defun class-from-type (type)
  (if (or (atom type) (eq (car type) t))
      *the-class-t*
      (case (car type)
        (and (dolist (type (cdr type) *the-class-t*)
               (when (and (consp type) (not (eq (car type) 'not)))
                 (return (class-from-type type)))))
        (not *the-class-t*)
        (eql (class-of (cadr type)))
        (class-eq (cadr type))
        (class (cadr type)))))

;;; We know that known-type implies neither new-type nor `(not ,new-type).
(defun augment-type (new-type known-type)
  (if (or (eq known-type t)
          (eq (car new-type) 'eql))
      new-type
      (let ((so-far (if (and (consp known-type) (eq (car known-type) 'and))
                        (cdr known-type)
                        (list known-type))))
        (unless (eq (car new-type) 'not)
          (setq so-far
                (mapcan (lambda (type)
                          (unless (*subtypep new-type type)
                            (list type)))
                        so-far)))
        (if (null so-far)
            new-type
            `(and ,new-type ,@so-far)))))

(defun generate-discrimination-net-internal
    (gf methods types methods-function test-fun type-function)
  (let* ((arg-info (gf-arg-info gf))
         (precedence (arg-info-precedence arg-info))
         (nreq (arg-info-number-required arg-info))
         (metatypes (arg-info-metatypes arg-info)))
    (labels ((do-column (p-tail contenders known-types)
               (if p-tail
                   (let* ((position (car p-tail))
                          (known-type (or (nth position types) t)))
                     (if (eq (nth position metatypes) t)
                         (do-column (cdr p-tail) contenders
                                    (cons (cons position known-type)
                                          known-types))
                         (do-methods p-tail contenders
                                     known-type () known-types)))
                   (funcall methods-function contenders
                            (let ((k-t (make-list nreq)))
                              (dolist (index+type known-types)
                                (setf (nth (car index+type) k-t)
                                      (cdr index+type)))
                              k-t))))
             (do-methods (p-tail contenders known-type winners known-types)
               ;; CONTENDERS
               ;;   is a (sorted) list of methods that must be discriminated.
               ;; KNOWN-TYPE
               ;;   is the type of this argument, constructed from tests
               ;;   already made.
               ;; WINNERS
               ;;   is a (sorted) list of methods that are potentially
               ;;   applicable after the discrimination has been made.
               (if (null contenders)
                   (do-column (cdr p-tail)
                              winners
                              (cons (cons (car p-tail) known-type)
                                    known-types))
                   (let* ((position (car p-tail))
                          (method (car contenders))
                          (specl (nth position (method-specializers method)))
                          (type (funcall type-function
                                         (type-from-specializer specl))))
                     (multiple-value-bind (app-p maybe-app-p)
                         (specializer-applicable-using-type-p type known-type)
                       (flet ((determined-to-be (truth-value)
                                (if truth-value app-p (not maybe-app-p)))
                              (do-if (truth &optional implied)
                                (let ((ntype (if truth type `(not ,type))))
                                  (do-methods p-tail
                                    (cdr contenders)
                                    (if implied
                                        known-type
                                        (augment-type ntype known-type))
                                    (if truth
                                        (append winners `(,method))
                                        winners)
                                    known-types))))
                         (cond ((determined-to-be nil) (do-if nil t))
                               ((determined-to-be t)   (do-if t   t))
                               (t (funcall test-fun position type
                                           (do-if t) (do-if nil))))))))))
      (do-column precedence methods ()))))

(defun compute-secondary-dispatch-function (generic-function net &optional
                                            method-alist wrappers)
  (function-funcall (compute-secondary-dispatch-function1 generic-function net)
                    method-alist wrappers))

(defvar *eq-case-table-limit* 15)
(defvar *case-table-limit* 10)

(defun compute-mcase-parameters (case-list)
  (unless (eq t (caar (last case-list)))
    (error "The key for the last case arg to mcase was not T"))
  (let* ((eq-p (dolist (case case-list t)
                 (unless (or (eq (car case) t)
                             (symbolp (caar case)))
                   (return nil))))
         (len (1- (length case-list)))
         (type (cond ((= len 1)
                      :simple)
                     ((<= len
                          (if eq-p
                              *eq-case-table-limit*
                              *case-table-limit*))
                      :assoc)
                     (t
                      :hash-table))))
    (list eq-p type)))

(defmacro mlookup (key info default &optional eq-p type)
  (unless (or (eq eq-p t) (null eq-p))
    (bug "Invalid eq-p argument: ~S" eq-p))
  (ecase type
    (:simple
     `(if (locally
            (declare (optimize (inhibit-warnings 3)))
            (,(if eq-p 'eq 'eql) ,key (car ,info)))
          (cdr ,info)
          ,default))
    (:assoc
     `(dolist (e ,info ,default)
        (when (locally
                (declare (optimize (inhibit-warnings 3)))
                (,(if eq-p 'eq 'eql) (car e) ,key))
          (return (cdr e)))))
    (:hash-table
     `(gethash ,key ,info ,default))))

(defun net-test-converter (form)
  (if (atom form)
      (default-test-converter form)
      (case (car form)
        ((invoke-effective-method-function invoke-fast-method-call
          invoke-effective-narrow-method-function)
         '.call.)
        (methods
         '.methods.)
        (unordered-methods
         '.umethods.)
        (mcase
         `(mlookup ,(cadr form)
                   nil
                   nil
                   ,@(compute-mcase-parameters (cddr form))))
        (t (default-test-converter form)))))

(defun net-code-converter (form)
  (if (atom form)
      (default-code-converter form)
      (case (car form)
        ((methods unordered-methods)
         (let ((gensym (gensym)))
           (values gensym
                   (list gensym))))
        (mcase
         (let ((mp (compute-mcase-parameters (cddr form)))
               (gensym (gensym)) (default (gensym)))
           (values `(mlookup ,(cadr form) ,gensym ,default ,@mp)
                   (list gensym default))))
        (t
         (default-code-converter form)))))

(defun net-constant-converter (form generic-function)
  (or (let ((c (methods-converter form generic-function)))
        (when c (list c)))
      (if (atom form)
          (default-constant-converter form)
          (case (car form)
            (mcase
             (let* ((mp (compute-mcase-parameters (cddr form)))
                    (list (mapcar (lambda (clause)
                                    (let ((key (car clause))
                                          (meth (cadr clause)))
                                      (cons (if (consp key) (car key) key)
                                            (methods-converter
                                             meth generic-function))))
                                  (cddr form)))
                    (default (car (last list))))
               (list (list* :mcase mp (nbutlast list))
                     (cdr default))))
            (t
             (default-constant-converter form))))))

(defun methods-converter (form generic-function)
  (cond ((and (consp form) (eq (car form) 'methods))
         (cons '.methods.
               (get-effective-method-function1 generic-function (cadr form))))
        ((and (consp form) (eq (car form) 'unordered-methods))
         (default-secondary-dispatch-function generic-function))))

(defun convert-methods (constant method-alist wrappers)
  (if (and (consp constant)
           (eq (car constant) '.methods.))
      (funcall (cdr constant) method-alist wrappers)
      constant))

(defun convert-table (constant method-alist wrappers)
  (cond ((and (consp constant)
              (eq (car constant) :mcase))
         (let ((alist (mapcar (lambda (k+m)
                                (cons (car k+m)
                                      (convert-methods (cdr k+m)
                                                       method-alist
                                                       wrappers)))
                              (cddr constant)))
               (mp (cadr constant)))
           (ecase (cadr mp)
             (:simple
              (car alist))
             (:assoc
              alist)
             (:hash-table
              (let ((table (make-hash-table :test (if (car mp) 'eq 'eql))))
                (dolist (k+m alist)
                  (setf (gethash (car k+m) table) (cdr k+m)))
                table)))))))

(defun compute-secondary-dispatch-function1 (generic-function net
                                             &optional function-p)
  (cond
   ((and (eq (car net) 'methods) (not function-p))
    (get-effective-method-function1 generic-function (cadr net)))
   (t
    (let* ((name (generic-function-name generic-function))
           (arg-info (gf-arg-info generic-function))
           (metatypes (arg-info-metatypes arg-info))
           (nargs (length metatypes))
           (applyp (arg-info-applyp arg-info))
           (fmc-arg-info (cons nargs applyp))
           (arglist (if function-p
                        (make-dfun-lambda-list nargs applyp)
                        (make-fast-method-call-lambda-list nargs applyp))))
      (multiple-value-bind (cfunction constants)
          (get-fun1 `(lambda
                      ,arglist
                      ,@(unless function-p
                          `((declare (ignore .pv. .next-method-call.))))
                      (locally (declare #.*optimize-speed*)
                               (let ((emf ,net))
                                 ,(make-emf-call nargs applyp 'emf))))
                    #'net-test-converter
                    #'net-code-converter
                    (lambda (form)
                      (net-constant-converter form generic-function)))
        (lambda (method-alist wrappers)
          (let* ((alist (list nil))
                 (alist-tail alist))
            (dolist (constant constants)
              (let* ((a (or (dolist (a alist nil)
                              (when (eq (car a) constant)
                                (return a)))
                            (cons constant
                                  (or (convert-table
                                       constant method-alist wrappers)
                                      (convert-methods
                                       constant method-alist wrappers)))))
                     (new (list a)))
                (setf (cdr alist-tail) new)
                (setf alist-tail new)))
            (let ((function (apply cfunction (mapcar #'cdr (cdr alist)))))
              (if function-p
                  function
                  (make-fast-method-call
                   :function (set-fun-name function `(sdfun-method ,name))
                   :arg-info fmc-arg-info))))))))))

(defvar *show-make-unordered-methods-emf-calls* nil)

(defun make-unordered-methods-emf (generic-function methods)
  (when *show-make-unordered-methods-emf-calls*
    (format t "~&make-unordered-methods-emf ~S~%"
            (generic-function-name generic-function)))
  (lambda (&rest args)
    (let* ((types (types-from-args generic-function args 'eql))
           (smethods (sort-applicable-methods generic-function
                                              methods
                                              types))
           (emf (get-effective-method-function generic-function smethods)))
      (invoke-emf emf args))))

;;; The value returned by compute-discriminating-function is a function
;;; object. It is called a discriminating function because it is called
;;; when the generic function is called and its role is to discriminate
;;; on the arguments to the generic function and then call appropriate
;;; method functions.
;;;
;;; A discriminating function can only be called when it is installed as
;;; the funcallable instance function of the generic function for which
;;; it was computed.
;;;
;;; More precisely, if compute-discriminating-function is called with
;;; an argument <gf1>, and returns a result <df1>, that result must
;;; not be passed to apply or funcall directly. Rather, <df1> must be
;;; stored as the funcallable instance function of the same generic
;;; function <gf1> (using SET-FUNCALLABLE-INSTANCE-FUNCTION). Then the
;;; generic function can be passed to funcall or apply.
;;;
;;; An important exception is that methods on this generic function are
;;; permitted to return a function which itself ends up calling the value
;;; returned by a more specific method. This kind of `encapsulation' of
;;; discriminating function is critical to many uses of the MOP.
;;;
;;; As an example, the following canonical case is legal:
;;;
;;;   (defmethod compute-discriminating-function ((gf my-generic-function))
;;;     (let ((std (call-next-method)))
;;;       (lambda (arg)
;;;         (print (list 'call-to-gf gf arg))
;;;         (funcall std arg))))
;;;
;;; Because many discriminating functions would like to use a dynamic
;;; strategy in which the precise discriminating function changes with
;;; time it is important to specify how a discriminating function is
;;; permitted itself to change the funcallable instance function of the
;;; generic function.
;;;
;;; Discriminating functions may set the funcallable instance function
;;; of the generic function, but the new value must be generated by making
;;; a call to COMPUTE-DISCRIMINATING-FUNCTION. This is to ensure that any
;;; more specific methods which may have encapsulated the discriminating
;;; function will get a chance to encapsulate the new, inner discriminating
;;; function.
;;;
;;; This implies that if a discriminating function wants to modify itself
;;; it should first store some information in the generic function proper,
;;; and then call compute-discriminating-function. The appropriate method
;;; on compute-discriminating-function will see the information stored in
;;; the generic function and generate a discriminating function accordingly.
;;;
;;; The following is an example of a discriminating function which modifies
;;; itself in accordance with this protocol:
;;;
;;;   (defmethod compute-discriminating-function ((gf my-generic-function))
;;;     (lambda (arg)
;;;      (cond (<some condition>
;;;             <store some info in the generic function>
;;;             (set-funcallable-instance-function
;;;               gf
;;;               (compute-discriminating-function gf))
;;;             (funcall gf arg))
;;;            (t
;;;             <call-a-method-of-gf>))))
;;;
;;; Whereas this code would not be legal:
;;;
;;;   (defmethod compute-discriminating-function ((gf my-generic-function))
;;;     (lambda (arg)
;;;      (cond (<some condition>
;;;             (set-funcallable-instance-function
;;;               gf
;;;               (lambda (a) ..))
;;;             (funcall gf arg))
;;;            (t
;;;             <call-a-method-of-gf>))))
;;;
;;; NOTE:  All the examples above assume that all instances of the class
;;;     my-generic-function accept only one argument.

(defun slot-value-using-class-dfun (class object slotd)
  (declare (ignore class))
  (funcall (slot-info-reader (slot-definition-info slotd)) object))

(defun setf-slot-value-using-class-dfun (new-value class object slotd)
  (declare (ignore class))
  (funcall (slot-info-writer (slot-definition-info slotd)) new-value object))

(defun slot-boundp-using-class-dfun (class object slotd)
  (declare (ignore class))
  (funcall (slot-info-boundp (slot-definition-info slotd)) object))

(defun special-case-for-compute-discriminating-function-p (gf)
  (or (eq gf #'slot-value-using-class)
      (eq gf #'(setf slot-value-using-class))
      (eq gf #'slot-boundp-using-class)))

(let (initial-print-object-cache)
  (defmethod compute-discriminating-function ((gf standard-generic-function))
    (let ((dfun-state (slot-value gf 'dfun-state)))
      (when (special-case-for-compute-discriminating-function-p gf)
        ;; if we have a special case for
        ;; COMPUTE-DISCRIMINATING-FUNCTION, then (at least for the
        ;; special cases implemented as of 2006-05-09) any information
        ;; in the cache is misplaced.
        (aver (null dfun-state)))
      (typecase dfun-state
        (null
         (when (eq gf #'compute-applicable-methods)
           (update-all-c-a-m-gf-info gf))
         (cond
           ((eq gf #'slot-value-using-class)
            (update-slot-value-gf-info gf 'reader)
            #'slot-value-using-class-dfun)
           ((eq gf #'(setf slot-value-using-class))
            (update-slot-value-gf-info gf 'writer)
            #'setf-slot-value-using-class-dfun)
           ((eq gf #'slot-boundp-using-class)
            (update-slot-value-gf-info gf 'boundp)
            #'slot-boundp-using-class-dfun)
           ;; KLUDGE: PRINT-OBJECT is not a special-case in the sense
           ;; of having a desperately special discriminating function.
           ;; However, it is important that the machinery for printing
           ;; conditions for stack and heap exhaustion, and the
           ;; restarts offered by the debugger, work without consuming
           ;; many extra resources.  This way (testing by name of GF
           ;; rather than by identity) was the only way I found to get
           ;; this to bootstrap, given that the PRINT-OBJECT generic
           ;; function is only set up later, in
           ;; SRC;PCL;PRINT-OBJECT.LISP.  -- CSR, 2008-06-09
           ((eq (slot-value gf 'name) 'print-object)
            (let ((nkeys (nth-value 3 (get-generic-fun-info gf))))
              (cond ((/= nkeys 1)
                     ;; KLUDGE: someone has defined a method
                     ;; specialized on the second argument: punt.
                     (setf initial-print-object-cache nil)
                     (make-initial-dfun gf))
                    (initial-print-object-cache
                     (multiple-value-bind (dfun cache info)
                         (make-caching-dfun gf (copy-cache initial-print-object-cache))
                       (set-dfun gf dfun cache info)))
                    ;; the relevant PRINT-OBJECT methods get defined
                    ;; late, by delayed DEF!METHOD.  We mustn't cache
                    ;; the effective method for our classes earlier
                    ;; than the relevant PRINT-OBJECT methods are
                    ;; defined...
                    ((boundp 'sb-impl::*delayed-def!method-args*)
                     (make-initial-dfun gf))
                    (t (multiple-value-bind (dfun cache info)
                           (make-final-dfun-internal
                            gf
                            (mapcar (lambda (x) (list (find-class x)))
                                    '(sb-kernel::control-stack-exhausted
                                      sb-kernel::binding-stack-exhausted
                                      sb-kernel::alien-stack-exhausted
                                      sb-kernel::heap-exhausted-error
                                      restart)))
                         (setq initial-print-object-cache cache)
                         (set-dfun gf dfun (copy-cache cache) info))))))
           ((gf-precompute-dfun-and-emf-p (slot-value gf 'arg-info))
            (make-final-dfun gf))
           (t
            (make-initial-dfun gf))))
        (function dfun-state)
        (cons (car dfun-state))))))

(defmethod (setf class-name) (new-value class)
  (let ((classoid (wrapper-classoid (class-wrapper class))))
    (if (and new-value (symbolp new-value))
        (setf (classoid-name classoid) new-value)
        (setf (classoid-name classoid) nil)))
  (reinitialize-instance class :name new-value)
  new-value)

(defmethod (setf generic-function-name) (new-value generic-function)
  (reinitialize-instance generic-function :name new-value)
  new-value)

(defmethod function-keywords ((method standard-method))
  (multiple-value-bind (nreq nopt keysp restp allow-other-keys-p
                        keywords)
      (analyze-lambda-list (if (consp method)
                               (early-method-lambda-list method)
                               (method-lambda-list method)))
    (declare (ignore nreq nopt keysp restp))
    (values keywords allow-other-keys-p)))

(defmethod function-keyword-parameters ((method standard-method))
  (multiple-value-bind (nreq nopt keysp restp allow-other-keys-p
                        keywords keyword-parameters)
      (analyze-lambda-list (if (consp method)
                               (early-method-lambda-list method)
                               (method-lambda-list method)))
    (declare (ignore nreq nopt keysp restp keywords))
    (values keyword-parameters allow-other-keys-p)))

(defun method-ll->generic-function-ll (ll)
  (multiple-value-bind
      (nreq nopt keysp restp allow-other-keys-p keywords keyword-parameters)
      (analyze-lambda-list ll)
    (declare (ignore nreq nopt keysp restp allow-other-keys-p keywords))
    (remove-if (lambda (s)
                 (or (memq s keyword-parameters)
                     (eq s '&allow-other-keys)))
               ll)))

;;; This is based on the rules of method lambda list congruency
;;; defined in the spec. The lambda list it constructs is the pretty
;;; union of the lambda lists of the generic function and of all its
;;; methods.  It doesn't take method applicability into account at all
;;; yet.

;;; (Notice that we ignore &AUX variables as they're not part of the
;;; "public interface" of a function.)

(defmethod generic-function-pretty-arglist
           ((generic-function standard-generic-function))
  (let ((gf-lambda-list (generic-function-lambda-list generic-function))
        (methods (generic-function-methods generic-function)))
    (if (null methods)
        gf-lambda-list
        (multiple-value-bind (gf.required gf.optional gf.rest gf.keys gf.allowp)
            (%split-arglist gf-lambda-list)
          ;; Possibly extend the keyword parameters of the gf by
          ;; additional key parameters of its methods:
          (let ((methods.keys nil) (methods.allowp nil))
            (dolist (m methods)
              (multiple-value-bind (m.keyparams m.allow-other-keys)
                  (function-keyword-parameters m)
                (setq methods.keys (union methods.keys m.keyparams :key #'maybe-car))
                (setq methods.allowp (or methods.allowp m.allow-other-keys))))
            (let ((arglist '()))
              (when (or gf.allowp methods.allowp)
                (push '&allow-other-keys arglist))
              (when (or gf.keys methods.keys)
                ;; We make sure that the keys of the gf appear before
                ;; those of its methods, since they're probably more
                ;; generally appliable.
                (setq arglist (nconc (list '&key) gf.keys
                                     (nset-difference methods.keys gf.keys)
                                     arglist)))
              (when gf.rest
                (setq arglist (nconc (list '&rest gf.rest) arglist)))
              (when gf.optional
                (setq arglist (nconc (list '&optional) gf.optional arglist)))
              (nconc gf.required arglist)))))))

(defun maybe-car (thing)
  (if (listp thing)
      (car thing)
      thing))


(defun %split-arglist (lambda-list)
  ;; This function serves to shrink the number of returned values of
  ;; PARSE-LAMBDA-LIST to something handier.
  (multiple-value-bind (required optional restp rest keyp keys allowp
                        auxp aux morep more-context more-count)
      (parse-lambda-list lambda-list :silent t)
    (declare (ignore restp keyp auxp aux morep))
    (declare (ignore more-context more-count))
    (values required optional rest keys allowp)))
