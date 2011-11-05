;;;; implementation of CONSTANTP, needs both INFO and IR1-ATTRIBUTES

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; This software is derived from the CMU CL system, which was
;;;; written at Carnegie Mellon University and released into the
;;;; public domain. The software is in the public domain and is
;;;; provided with absolutely no warranty. See the COPYING and CREDITS
;;;; files for more information.

(in-package "SB!C")

(!begin-collecting-cold-init-forms)

(defvar *special-form-constantp-funs*)
(declaim (type hash-table *special-form-constantp-funs*))
(!cold-init-forms
  (setf *special-form-constantp-funs* (make-hash-table)))

(defvar *special-form-constant-form-value-funs*)
(declaim (type hash-table *special-form-constant-form-value-funs*))
(!cold-init-forms
  (setf *special-form-constant-form-value-funs* (make-hash-table)))

(defvar *special-constant-variables*)
(!cold-init-forms
  (setf *special-constant-variables* nil))

(defun %constantp (form environment envp)
  (let ((form (if envp
                  (%macroexpand form environment)
                  form)))
    (typecase form
      ;; This INFO test catches KEYWORDs as well as explicitly
      ;; DEFCONSTANT symbols.
      (symbol
       (or (eq (info :variable :kind form) :constant)
           (constant-special-variable-p form)))
      (list
       (or (constant-special-form-p form environment envp)
           #-sb-xc-host
           (values (constant-function-call-p form environment envp))))
      (t t))))

(defun %constant-form-value (form environment envp)
  (let ((form (if envp
                  (%macroexpand form environment)
                  form)))
    (typecase form
      (symbol
       ;; KLUDGE: superficially, this might look good enough: we grab
       ;; the value from the info database, and if it isn't there (or
       ;; is NIL, but hey) we use the host's value.  This works for
       ;; MOST-POSITIVE-FIXNUM and friends, but still fails for
       ;; float-related constants, where there is in fact no guarantee
       ;; that we can represent our target value at all in the host,
       ;; so we don't try.  We should rework all uses of floating
       ;; point so that we never try to use a host's value, and then
       ;; make some kind of assertion that we never attempt to take
       ;; a host value of a constant in the CL package.
       #+sb-xc-host (or (info :variable :xc-constant-value form)
                        (symbol-value form))
       #-sb-xc-host (symbol-value form))
      (list
       (if (special-operator-p (car form))
           (constant-special-form-value form environment envp)
           #-sb-xc-host
           (constant-function-call-value form environment envp)))
      (t
       form))))

(defun constant-special-form-p (form environment envp)
  (let ((fun (gethash (car form) *special-form-constantp-funs*)))
    (when fun
      (funcall fun form environment envp))))

(defun constant-special-form-value (form environment envp)
  (let ((fun (gethash (car form) *special-form-constant-form-value-funs*)))
    (if fun
        (funcall fun form environment envp)
        (error "Not a constant-foldable special form: ~S" form))))

(defun constant-special-variable-p (name)
  (and (member name *special-constant-variables*) t))

;;; FIXME: It would be nice to deal with inline functions
;;; too.
(defun constant-function-call-p (form environment envp)
  (let ((name (car form)))
    (if (and (legal-fun-name-p name)
             (eq :function (info :function :kind name))
             (let ((info (info :function :info name)))
               (and info (ir1-attributep (fun-info-attributes info)
                                         foldable)))
             (and (every (lambda (arg)
                           (%constantp arg environment envp))
                         (cdr form))))
        ;; Even though the function may be marked as foldable
        ;; the call may still signal an error -- eg: (CAR 1).
        (handler-case
            (values t (constant-function-call-value form environment envp))
          (error ()
            (values nil nil)))
        (values nil nil))))

(defun constant-function-call-value (form environment envp)
  (apply (fdefinition (car form))
         (mapcar (lambda (arg)
                   (%constant-form-value arg environment envp))
                 (cdr form))))

#!-sb-fluid (declaim (inline sb!xc:constantp))
(defun sb!xc:constantp (form &optional (environment nil envp))
  #!+sb-doc
  "True of any FORM that has a constant value: self-evaluating objects,
keywords, defined constants, quote forms. Additionally the
constant-foldability of some function calls special forms is recognized. If
ENVIRONMENT is provided the FORM is first macroexpanded in it."
  (%constantp form environment envp))

#!-sb-fluid (declaim (inline constant-form-value))
(defun constant-form-value (form &optional (environment nil envp))
  #!+sb-doc
  "Returns the value of the constant FORM in ENVIRONMENT. Behaviour
is undefined unless CONSTANTP has been first used to determine the
constantness of the FORM in ENVIRONMENT."
  (%constant-form-value form environment envp))

(declaim (inline constant-typep))
(defun constant-typep (form type &optional (environment nil envp))
  (and (%constantp form environment envp)
       ;; FIXME: We probably should be passing the environment to
       ;; TYPEP too, but (1) our XC version of typep AVERs that the
       ;; environment is null (2) our real version ignores it anyhow.
       (sb!xc:typep (%constant-form-value form environment envp) type)))

;;;; NOTE!!!
;;;;
;;;; If you add new special forms, check that they do not
;;;; alter the logic of existing ones: eg, currently
;;;; CONSTANT-FORM-VALUE directly evaluates the last expression
;;;; of a PROGN, as no assignment is allowed. If you extend
;;;; analysis to assignments then other forms must take this
;;;; into account.

(defmacro defconstantp (operator lambda-list &key test eval)
  (with-unique-names (form environment envp)
    (flet ((frob (body)
             `(flet ((constantp* (x)
                       (%constantp x ,environment ,envp))
                     (constant-form-value* (x)
                       (%constant-form-value x ,environment ,envp)))
                (declare (ignorable #'constantp* #'constant-form-value*))
                (destructuring-bind ,lambda-list (cdr ,form)
                  ;; KLUDGE: is all we need, so we keep it simple
                  ;; instead of general (not handling cases like &key (x y))
                  (declare (ignorable
                            ,@(remove-if (lambda (arg)
                                           (member arg sb!xc:lambda-list-keywords))
                                         lambda-list)))
                   ,body))))
      `(progn
         (setf (gethash ',operator *special-form-constantp-funs*)
               (lambda (,form ,environment ,envp)
                 ,(frob test)))
         (setf (gethash ',operator *special-form-constant-form-value-funs*)
               (lambda (,form ,environment ,envp)
                 ,(frob eval)))))))

(!cold-init-forms
 (defconstantp quote (value)
   :test t
   :eval value)

 (defconstantp if (test then &optional else)
   :test
   (and (constantp* test)
        (constantp* (if (constant-form-value* test)
                        then
                        else)))
   :eval (if (constant-form-value* test)
             (constant-form-value* then)
             (constant-form-value* else)))

 (defconstantp progn (&body forms)
   :test (every #'constantp* forms)
   :eval (constant-form-value* (car (last forms))))

 (defconstantp unwind-protect (protected-form &body cleanup-forms)
   :test (every #'constantp* (cons protected-form cleanup-forms))
   :eval (constant-form-value* protected-form))

 (defconstantp the (type form)
   :test (and (constantp* form)
              (handler-case
                  ;; in case the type-spec is malformed!
                  (typep (constant-form-value* form) type)
                (error () nil)))
   :eval (constant-form-value* form))

 (defconstantp block (name &body forms)
   ;; We currently fail to detect cases like
   ;;
   ;; (BLOCK FOO
   ;;   ...CONSTANT-FORMS...
   ;;   (RETURN-FROM FOO CONSTANT-VALUE)
   ;;   ...ANYTHING...)
   ;;
   ;; Right now RETURN-FROM kills the constantness unequivocally.
   :test (every #'constantp* forms)
   :eval (constant-form-value* (car (last forms))))

 (defconstantp multiple-value-prog1 (first-form &body forms)
   :test (every #'constantp* (cons first-form forms))
   :eval (constant-form-value* first-form))

 (defconstantp progv (symbols values &body forms)
   :test (and (constantp* symbols)
              (constantp* values)
              (let* ((symbol-values (constant-form-value* symbols))
                     (*special-constant-variables*
                      (append symbol-values *special-constant-variables*)))
                (progv
                    symbol-values
                    (constant-form-value* values)
                  (every #'constantp* forms))))
   :eval (progv
             (constant-form-value* symbols)
             (constant-form-value* values)
           (constant-form-value* (car (last forms))))))

(!defun-from-collected-cold-init-forms !constantp-cold-init)

