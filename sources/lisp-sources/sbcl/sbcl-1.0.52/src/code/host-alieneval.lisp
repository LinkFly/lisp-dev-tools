;;;; the part of the Alien implementation which is needed at
;;;; cross-compilation time

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; This software is derived from the CMU CL system, which was
;;;; written at Carnegie Mellon University and released into the
;;;; public domain. The software is in the public domain and is
;;;; provided with absolutely no warranty. See the COPYING and CREDITS
;;;; files for more information.

(in-package "SB!ALIEN")

(/show0 "host-alieneval.lisp 15")

;;;; utility functions

(defun align-offset (offset alignment)
  (let ((extra (rem offset alignment)))
    (if (zerop extra) offset (+ offset (- alignment extra)))))

(defun guess-alignment (bits)
  (cond ((null bits) nil)
        #!-(or (and x86 (not win32)) (and ppc darwin)) ((> bits 32) 64)
        ((> bits 16) 32)
        ((> bits 8) 16)
        ((> bits 1) 8)
        (t 1)))

;;;; ALIEN-TYPE-INFO stuff

(eval-when (#-sb-xc :compile-toplevel :execute :load-toplevel)

(defstruct (alien-type-class (:copier nil))
  (name nil :type symbol)
  (defstruct-name nil :type symbol)
  (include nil :type (or null alien-type-class))
  (unparse nil :type (or null function))
  (type= nil :type (or null function))
  (lisp-rep nil :type (or null function))
  (alien-rep nil :type (or null function))
  (extract-gen nil :type (or null function))
  (deposit-gen nil :type (or null function))
  (naturalize-gen nil :type (or null function))
  (deport-gen nil :type (or null function))
  (deport-alloc-gen nil :type (or null function))
  (deport-pin-p nil :type (or null function))
  ;; Cast?
  (arg-tn nil :type (or null function))
  (result-tn nil :type (or null function))
  (subtypep nil :type (or null function)))
(def!method print-object ((type-class alien-type-class) stream)
  (print-unreadable-object (type-class stream :type t)
    (prin1 (alien-type-class-name type-class) stream)))

(defun alien-type-class-or-lose (name)
  (or (gethash name *alien-type-classes*)
      (error "no alien type class ~S" name)))

(defun create-alien-type-class-if-necessary (name defstruct-name include)
  (let ((old (gethash name *alien-type-classes*))
        (include (and include (alien-type-class-or-lose include))))
    (if old
        (setf (alien-type-class-include old) include)
        (setf (gethash name *alien-type-classes*)
              (make-alien-type-class :name name
                                     :defstruct-name defstruct-name
                                     :include include)))))

(defparameter *method-slot-alist*
  '((:unparse . alien-type-class-unparse)
    (:type= . alien-type-class-type=)
    (:subtypep . alien-type-class-subtypep)
    (:lisp-rep . alien-type-class-lisp-rep)
    (:alien-rep . alien-type-class-alien-rep)
    (:extract-gen . alien-type-class-extract-gen)
    (:deposit-gen . alien-type-class-deposit-gen)
    (:naturalize-gen . alien-type-class-naturalize-gen)
    (:deport-gen . alien-type-class-deport-gen)
    (:deport-alloc-gen . alien-type-class-deport-alloc-gen)
    (:deport-pin-p . alien-type-class-deport-pin-p)
    ;; cast?
    (:arg-tn . alien-type-class-arg-tn)
    (:result-tn . alien-type-class-result-tn)))

(defun method-slot (method)
  (cdr (or (assoc method *method-slot-alist*)
           (error "no method ~S" method))))

) ; EVAL-WHEN

;;; We define a keyword "BOA" constructor so that we can reference the
;;; slot names in init forms.
(def!macro define-alien-type-class ((name &key include include-args)
                                    &rest slots)
  (let ((defstruct-name (symbolicate "ALIEN-" name "-TYPE")))
    (multiple-value-bind (include include-defstruct overrides)
        (etypecase include
          (null
           (values nil 'alien-type nil))
          (symbol
           (values
            include
            (alien-type-class-defstruct-name
             (alien-type-class-or-lose include))
            nil))
          (list
           (values
            (car include)
            (alien-type-class-defstruct-name
             (alien-type-class-or-lose (car include)))
            (cdr include))))
      `(progn
         (eval-when (:compile-toplevel :load-toplevel :execute)
           (create-alien-type-class-if-necessary ',name ',defstruct-name
                                                 ',(or include 'root)))
         (def!struct (,defstruct-name
                        (:include ,include-defstruct
                                  (class ',name)
                                  ,@overrides)
                        (:constructor
                         ,(symbolicate "MAKE-" defstruct-name)
                         (&key class bits alignment
                               ,@(mapcar (lambda (x)
                                           (if (atom x) x (car x)))
                                         slots)
                               ,@include-args
                               ;; KLUDGE
                               &aux (alignment (or alignment (guess-alignment bits))))))
           ,@slots)))))

(def!macro define-alien-type-method ((class method) lambda-list &rest body)
  (let ((defun-name (symbolicate class "-" method "-METHOD")))
    `(progn
       (defun ,defun-name ,lambda-list
         ,@body)
       (setf (,(method-slot method) (alien-type-class-or-lose ',class))
             #',defun-name))))

(def!macro invoke-alien-type-method (method type &rest args)
  (let ((slot (method-slot method)))
    (once-only ((type type))
      `(funcall (do ((class (alien-type-class-or-lose (alien-type-class ,type))
                            (alien-type-class-include class)))
                    ((null class)
                     (error "method ~S not defined for ~S"
                            ',method (alien-type-class ,type)))
                  (let ((fn (,slot class)))
                    (when fn
                      (return fn))))
                ,type ,@args))))

;;;; type parsing and unparsing

;;; CMU CL used COMPILER-LET to bind *AUXILIARY-TYPE-DEFINITIONS*, and
;;; COMPILER-LET is no longer supported by ANSI or SBCL. Instead, we
;;; follow the suggestion in CLTL2 of using SYMBOL-MACROLET to achieve
;;; a similar effect.
(eval-when (#-sb-xc :compile-toplevel :load-toplevel :execute)
  (defun auxiliary-type-definitions (env)
    (multiple-value-bind (result expanded-p)
        (%macroexpand '&auxiliary-type-definitions& env)
      (if expanded-p
          result
          ;; This is like having the global symbol-macro definition be
          ;; NIL, but global symbol-macros make me vaguely queasy, so
          ;; I do it this way instead.
          nil))))

;;; Process stuff in a new scope.
(def!macro with-auxiliary-alien-types (env &body body)
  ``(symbol-macrolet ((&auxiliary-type-definitions&
                       ,(append *new-auxiliary-types*
                                (auxiliary-type-definitions ,env))))
      ,(let ((*new-auxiliary-types* nil))
         ,@body)))

;;; Parse TYPE as an alien type specifier and return the resultant
;;; ALIEN-TYPE structure.
(defun parse-alien-type (type env)
  (declare (type (or sb!kernel:lexenv null) env))
  (if (consp type)
      (let ((translator (info :alien-type :translator (car type))))
        (unless translator
          (error "unknown alien type: ~S" type))
        (funcall translator type env))
      (ecase (info :alien-type :kind type)
        (:primitive
         (let ((translator (info :alien-type :translator type)))
           (unless translator
             (error "no translator for primitive alien type ~S" type))
           (funcall translator (list type) env)))
        (:defined
         (or (info :alien-type :definition type)
             (error "no definition for alien type ~S" type)))
        (:unknown
         (error "unknown alien type: ~S" type)))))

(defun auxiliary-alien-type (kind name env)
  (declare (type (or sb!kernel:lexenv null) env))
  (flet ((aux-defn-matches (x)
           (and (eq (first x) kind) (eq (second x) name))))
    (let ((in-auxiliaries
           (or (find-if #'aux-defn-matches *new-auxiliary-types*)
               (find-if #'aux-defn-matches (auxiliary-type-definitions env)))))
      (if in-auxiliaries
          (values (third in-auxiliaries) t)
          (ecase kind
            (:struct
             (info :alien-type :struct name))
            (:union
             (info :alien-type :union name))
            (:enum
             (info :alien-type :enum name)))))))

(defun (setf auxiliary-alien-type) (new-value kind name env)
  (declare (type (or sb!kernel:lexenv null) env))
  (flet ((aux-defn-matches (x)
           (and (eq (first x) kind) (eq (second x) name))))
    (when (find-if #'aux-defn-matches *new-auxiliary-types*)
      (error "attempt to multiply define ~A ~S" kind name))
    (when (find-if #'aux-defn-matches (auxiliary-type-definitions env))
      (error "attempt to shadow definition of ~A ~S" kind name)))
  (push (list kind name new-value) *new-auxiliary-types*)
  new-value)

(defun verify-local-auxiliaries-okay ()
  (dolist (info *new-auxiliary-types*)
    (destructuring-bind (kind name defn) info
      (declare (ignore defn))
      (when (ecase kind
              (:struct
               (info :alien-type :struct name))
              (:union
               (info :alien-type :union name))
              (:enum
               (info :alien-type :enum name)))
        (error "attempt to shadow definition of ~A ~S" kind name)))))

(defun unparse-alien-type (type)
  #!+sb-doc
  "Convert the alien-type structure TYPE back into a list specification of
   the type."
  (declare (type alien-type type))
  (let ((*record-types-already-unparsed* nil))
    (%unparse-alien-type type)))

;;; Does all the work of UNPARSE-ALIEN-TYPE. It's separate because we
;;; need to recurse inside the binding of
;;; *RECORD-TYPES-ALREADY-UNPARSED*.
(defun %unparse-alien-type (type)
  (invoke-alien-type-method :unparse type))

;;;; alien type defining stuff

(def!macro define-alien-type-translator (name lambda-list &body body)
  (with-unique-names (whole env)
    (let ((defun-name (symbolicate "ALIEN-" name "-TYPE-TRANSLATOR")))
      (multiple-value-bind (body decls docs)
          (sb!kernel:parse-defmacro lambda-list whole body name
                                    'define-alien-type-translator
                                    :environment env)
        `(eval-when (:compile-toplevel :load-toplevel :execute)
           (defun ,defun-name (,whole ,env)
             (declare (ignorable ,env))
             ,@decls
             (block ,name
               ,body))
           (%define-alien-type-translator ',name #',defun-name ,docs))))))

(eval-when (#-sb-xc :compile-toplevel :load-toplevel :execute)
  (defun %define-alien-type-translator (name translator docs)
    (declare (ignore docs))
    (setf (info :alien-type :kind name) :primitive)
    (setf (info :alien-type :translator name) translator)
    (clear-info :alien-type :definition name)
    #+nil
    (setf (fdocumentation name 'alien-type) docs)
    name))

(def!macro define-alien-type (name type &environment env)
  #!+sb-doc
  "Define the alien type NAME to be equivalent to TYPE. Name may be NIL for
   STRUCT and UNION types, in which case the name is taken from the type
   specifier."
  (with-auxiliary-alien-types env
    (let ((alien-type (parse-alien-type type env)))
      `(eval-when (:compile-toplevel :load-toplevel :execute)
         ,@(when *new-auxiliary-types*
             `((%def-auxiliary-alien-types ',*new-auxiliary-types*)))
         ,@(when name
             `((%define-alien-type ',name ',alien-type)))))))

(eval-when (#-sb-xc :compile-toplevel :load-toplevel :execute)
  (defun %def-auxiliary-alien-types (types)
    (dolist (info types)
      ;; Clear up the type we're about to define from the toplevel
      ;; *new-auxiliary-types* (local scopes take care of themselves).
      ;; Unless this is done we never actually get back the full type
      ;; from INFO, since the *new-auxiliary-types* have precendence.
      (setf *new-auxiliary-types*
            (remove info *new-auxiliary-types*
                    :test (lambda (a b)
                            (and (eq (first a) (first b))
                                 (eq (second a) (second b))))))
      (destructuring-bind (kind name defn) info
        (macrolet ((frob (kind)
                         `(let ((old (info :alien-type ,kind name)))
                            (unless (or (null old) (alien-type-= old defn))
                              (warn
                               "redefining ~A ~S to be:~%  ~S,~%was:~%  ~S"
                               kind name defn old))
                            (setf (info :alien-type ,kind name) defn))))
          (ecase kind
            (:struct (frob :struct))
            (:union (frob :union))
            (:enum (frob :enum)))))))
  (defun %define-alien-type (name new)
    (ecase (info :alien-type :kind name)
      (:primitive
       (error "~S is a built-in alien type." name))
      (:defined
       (let ((old (info :alien-type :definition name)))
         (unless (or (null old) (alien-type-= new old))
           (warn "redefining ~S to be:~%  ~S,~%was~%  ~S"
                 name
                 (unparse-alien-type new)
                 (unparse-alien-type old)))))
      (:unknown))
    (setf (info :alien-type :definition name) new)
    (setf (info :alien-type :kind name) :defined)
    name))

;;;; the root alien type

(eval-when (:compile-toplevel :load-toplevel :execute)
  (create-alien-type-class-if-necessary 'root 'alien-type nil))

(def!struct (alien-type
             (:make-load-form-fun sb!kernel:just-dump-it-normally)
             (:constructor make-alien-type (&key class bits alignment
                                            &aux (alignment (or alignment (guess-alignment bits))))))
  (class 'root :type symbol)
  (bits nil :type (or null unsigned-byte))
  (alignment nil :type (or null unsigned-byte)))
(def!method print-object ((type alien-type) stream)
  (print-unreadable-object (type stream :type t)
    (prin1 (unparse-alien-type type) stream)))

;;;; the SAP type

(define-alien-type-class (system-area-pointer))

(define-alien-type-translator system-area-pointer ()
  (make-alien-system-area-pointer-type
   :bits #!-alpha sb!vm:n-word-bits #!+alpha 64))

(define-alien-type-method (system-area-pointer :unparse) (type)
  (declare (ignore type))
  'system-area-pointer)

(define-alien-type-method (system-area-pointer :lisp-rep) (type)
  (declare (ignore type))
  'system-area-pointer)

(define-alien-type-method (system-area-pointer :alien-rep) (type context)
  (declare (ignore type context))
  'system-area-pointer)

(define-alien-type-method (system-area-pointer :naturalize-gen) (type alien)
  (declare (ignore type))
  alien)

(define-alien-type-method (system-area-pointer :deport-gen) (type object)
  (declare (ignore type))
  (/noshow "doing alien type method SYSTEM-AREA-POINTER :DEPORT-GEN" object)
  object)

(define-alien-type-method (system-area-pointer :extract-gen) (type sap offset)
  (declare (ignore type))
  `(sap-ref-sap ,sap (/ ,offset sb!vm:n-byte-bits)))

;;;; the ALIEN-VALUE type

(define-alien-type-class (alien-value :include system-area-pointer))

(define-alien-type-method (alien-value :lisp-rep) (type)
  (declare (ignore type))
  nil)

(define-alien-type-method (alien-value :naturalize-gen) (type alien)
  `(%sap-alien ,alien ',type))

(define-alien-type-method (alien-value :deport-gen) (type value)
  (declare (ignore type))
  (/noshow "doing alien type method ALIEN-VALUE :DEPORT-GEN" value)
  `(alien-sap ,value))

;;; HEAP-ALIEN-INFO -- defstruct.
;;;
;;; Information describing a heap-allocated alien.
(def!struct (heap-alien-info
             (:make-load-form-fun sb!kernel:just-dump-it-normally))
  ;; The type of this alien.
  (type (missing-arg) :type alien-type)
  ;; The form to evaluate to produce the SAP pointing to where in the heap
  ;; it is.
  (sap-form (missing-arg)))
(def!method print-object ((info heap-alien-info) stream)
  (print-unreadable-object (info stream :type t)
    (funcall (formatter "~S ~S")
             stream
             (heap-alien-info-sap-form info)
             (unparse-alien-type (heap-alien-info-type info)))))

;;;; Interfaces to the different methods

(defun alien-type-= (type1 type2)
  #!+sb-doc
  "Return T iff TYPE1 and TYPE2 describe equivalent alien types."
  (or (eq type1 type2)
      (and (eq (alien-type-class type1)
               (alien-type-class type2))
           (invoke-alien-type-method :type= type1 type2))))

(defun alien-subtype-p (type1 type2)
  #!+sb-doc
  "Return T iff the alien type TYPE1 is a subtype of TYPE2. Currently, the
   only supported subtype relationships are is that any pointer type is a
   subtype of (* t), and any array type first dimension will match
   (array <eltype> nil ...). Otherwise, the two types have to be
   ALIEN-TYPE-=."
  (or (eq type1 type2)
      (invoke-alien-type-method :subtypep type1 type2)))

(defun compute-naturalize-lambda (type)
  `(lambda (alien ignore)
     (declare (ignore ignore))
     ,(invoke-alien-type-method :naturalize-gen type 'alien)))

(defun compute-deport-lambda (type)
  (declare (type alien-type type))
  (/noshow "entering COMPUTE-DEPORT-LAMBDA" type)
  (multiple-value-bind (form value-type)
      (invoke-alien-type-method :deport-gen type 'value)
    `(lambda (value ignore)
       (declare (type ,(or value-type
                           (compute-lisp-rep-type type)
                           `(alien ,type))
                      value)
                (ignore ignore))
       ,form)))

(defun compute-deport-alloc-lambda (type)
  `(lambda (value ignore)
     (declare (ignore ignore))
     ,(invoke-alien-type-method :deport-alloc-gen type 'value)))

(defun compute-extract-lambda (type)
  `(lambda (sap offset ignore)
     (declare (type system-area-pointer sap)
              (type unsigned-byte offset)
              (ignore ignore))
     (naturalize ,(invoke-alien-type-method :extract-gen type 'sap 'offset)
                 ',type)))

(def!macro maybe-with-pinned-objects (variables types &body body)
  (declare (ignorable variables types))
  (let ((pin-variables
         ;; Only pin things on x86/x86-64, since on non-conservative
         ;; gcs it'd imply disabling the GC. Which is something we
         ;; don't want to do every time we're calling to C.
         #!+(or x86 x86-64)
         (loop for variable in variables
            for type in types
            when (invoke-alien-type-method :deport-pin-p type)
            collect variable)))
    (if pin-variables
        `(with-pinned-objects ,pin-variables
           ,@body)
        `(progn
           ,@body))))

(defun compute-deposit-lambda (type)
  (declare (type alien-type type))
  `(lambda (sap offset ignore value)
     (declare (type system-area-pointer sap)
              (type unsigned-byte offset)
              (ignore ignore))
     (let ((alloc-tmp (deport-alloc value ',type)))
       (maybe-with-pinned-objects (alloc-tmp) (,type)
         (let ((value (deport alloc-tmp  ',type)))
           ,(invoke-alien-type-method :deposit-gen type 'sap 'offset 'value)
           ;; Note: the reason we don't just return the pre-deported value
           ;; is because that would inhibit any (deport (naturalize ...))
           ;; optimizations that might have otherwise happen. Re-naturalizing
           ;; the value might cause extra consing, but is flushable, so probably
           ;; results in better code.
           (naturalize value ',type))))))

(defun compute-lisp-rep-type (type)
  (invoke-alien-type-method :lisp-rep type))

;;; CONTEXT is either :NORMAL (the default) or :RESULT (alien function
;;; return values).  See the :ALIEN-REP method for INTEGER for
;;; details.
(defun compute-alien-rep-type (type &optional (context :normal))
  (invoke-alien-type-method :alien-rep type context))

;;;; default methods

(define-alien-type-method (root :unparse) (type)
  `(<unknown-alien-type> ,(type-of type)))

(define-alien-type-method (root :type=) (type1 type2)
  (declare (ignore type1 type2))
  t)

(define-alien-type-method (root :subtypep) (type1 type2)
  (alien-type-= type1 type2))

(define-alien-type-method (root :lisp-rep) (type)
  (declare (ignore type))
  nil)

(define-alien-type-method (root :alien-rep) (type context)
  (declare (ignore type context))
  '*)

(define-alien-type-method (root :naturalize-gen) (type alien)
  (declare (ignore alien))
  (error "cannot represent ~S typed aliens" type))

(define-alien-type-method (root :deport-gen) (type object)
  (declare (ignore object))
  (error "cannot represent ~S typed aliens" type))

(define-alien-type-method (root :deport-alloc-gen) (type object)
  (declare (ignore type))
  object)

(define-alien-type-method (root :deport-pin-p) (type)
  (declare (ignore type))
  ;; Override this method to return T for classes which take a SAP to a
  ;; GCable lisp object when deporting.
  nil)

(define-alien-type-method (root :extract-gen) (type sap offset)
  (declare (ignore sap offset))
  (error "cannot represent ~S typed aliens" type))

(define-alien-type-method (root :deposit-gen) (type sap offset value)
  `(setf ,(invoke-alien-type-method :extract-gen type sap offset) ,value))

(define-alien-type-method (root :arg-tn) (type state)
  (declare (ignore state))
  (error "Aliens of type ~S cannot be passed as arguments to CALL-OUT."
         (unparse-alien-type type)))

(define-alien-type-method (root :result-tn) (type state)
  (declare (ignore state))
  (error "Aliens of type ~S cannot be returned from CALL-OUT."
         (unparse-alien-type type)))

;;;; the INTEGER type

(define-alien-type-class (integer)
  (signed t :type (member t nil)))

(define-alien-type-translator signed (&optional (bits sb!vm:n-word-bits))
  (make-alien-integer-type :bits bits))

(define-alien-type-translator integer (&optional (bits sb!vm:n-word-bits))
  (make-alien-integer-type :bits bits))

(define-alien-type-translator unsigned (&optional (bits sb!vm:n-word-bits))
  (make-alien-integer-type :bits bits :signed nil))

(define-alien-type-method (integer :unparse) (type)
  (list (if (alien-integer-type-signed type) 'signed 'unsigned)
        (alien-integer-type-bits type)))

(define-alien-type-method (integer :type=) (type1 type2)
  (and (eq (alien-integer-type-signed type1)
           (alien-integer-type-signed type2))
       (= (alien-integer-type-bits type1)
          (alien-integer-type-bits type2))))

(define-alien-type-method (integer :lisp-rep) (type)
  (list (if (alien-integer-type-signed type) 'signed-byte 'unsigned-byte)
        (alien-integer-type-bits type)))

(define-alien-type-method (integer :alien-rep) (type context)
  ;; When returning integer values that are narrower than a machine
  ;; register from a function, some platforms leave the higher bits of
  ;; the register uninitialized.  On those platforms, we use an
  ;; alien-rep of the full register width when checking for purposes
  ;; of return values and override the naturalize method to perform
  ;; the sign extension (in compiler/target/c-call.lisp).
  (ecase context
    ((:normal #!-(or x86 x86-64) :result)
     (list (if (alien-integer-type-signed type) 'signed-byte 'unsigned-byte)
           (alien-integer-type-bits type)))
    #!+(or x86 x86-64)
    (:result
     (list (if (alien-integer-type-signed type) 'signed-byte 'unsigned-byte)
           sb!vm:n-word-bits))))

;;; As per the comment in the :ALIEN-REP method above, this is defined
;;; elsewhere for x86oids.
#!-(or x86 x86-64)
(define-alien-type-method (integer :naturalize-gen) (type alien)
  (declare (ignore type))
  alien)

(define-alien-type-method (integer :deport-gen) (type value)
  (declare (ignore type))
  value)

(define-alien-type-method (integer :extract-gen) (type sap offset)
  (declare (type alien-integer-type type))
  (let ((ref-fun
         (if (alien-integer-type-signed type)
          (case (alien-integer-type-bits type)
            (8 'signed-sap-ref-8)
            (16 'signed-sap-ref-16)
            (32 'signed-sap-ref-32)
            (64 'signed-sap-ref-64))
          (case (alien-integer-type-bits type)
            (8 'sap-ref-8)
            (16 'sap-ref-16)
            (32 'sap-ref-32)
            (64 'sap-ref-64)))))
    (if ref-fun
        `(,ref-fun ,sap (/ ,offset sb!vm:n-byte-bits))
        (error "cannot extract ~W-bit integers"
               (alien-integer-type-bits type)))))

;;;; the BOOLEAN type

(define-alien-type-class (boolean :include integer :include-args (signed)))

;;; FIXME: Check to make sure that we aren't attaching user-readable
;;; stuff to CL:BOOLEAN in any way which impairs ANSI compliance.
(define-alien-type-translator boolean (&optional (bits sb!vm:n-word-bits))
  (make-alien-boolean-type :bits bits :signed nil))

(define-alien-type-method (boolean :unparse) (type)
  `(boolean ,(alien-boolean-type-bits type)))

(define-alien-type-method (boolean :lisp-rep) (type)
  (declare (ignore type))
  `(member t nil))

(define-alien-type-method (boolean :naturalize-gen) (type alien)
  (declare (ignore type))
  `(not (zerop ,alien)))

(define-alien-type-method (boolean :deport-gen) (type value)
  (declare (ignore type))
  `(if ,value 1 0))

;;;; the ENUM type

(define-alien-type-class (enum :include (integer (bits 32))
                               :include-args (signed))
  name          ; name of this enum (if any)
  from          ; alist from symbols to integers
  to            ; alist or vector from integers to symbols
  kind          ; kind of from mapping, :VECTOR or :ALIST
  offset)       ; offset to add to value for :VECTOR from mapping

(define-alien-type-translator enum (&whole
                                 type name
                                 &rest mappings
                                 &environment env)
  (cond (mappings
         (let ((result (parse-enum name mappings)))
           (when name
             (multiple-value-bind (old old-p)
                 (auxiliary-alien-type :enum name env)
               (when old-p
                 (unless (alien-type-= result old)
                   (cerror "Continue, clobbering the old definition"
                           "Incompatible alien enum type definition: ~S" name)
                   (setf (alien-type-from old) (alien-type-from result)
                         (alien-type-to old) (alien-type-to result)
                         (alien-type-kind old) (alien-type-kind result)
                         (alien-type-offset old) (alien-type-offset result)
                         (alien-type-signed old) (alien-type-signed result)))
                 (setf result old))
               (unless old-p
                 (setf (auxiliary-alien-type :enum name env) result))))
           result))
        (name
         (multiple-value-bind (result found)
             (auxiliary-alien-type :enum name env)
           (unless found
             (error "unknown enum type: ~S" name))
           result))
        (t
         (error "empty enum type: ~S" type))))

(defun parse-enum (name elements)
  (when (null elements)
    (error "An enumeration must contain at least one element."))
  (let ((min nil)
        (max nil)
        (from-alist ())
        (prev -1))
    (declare (list from-alist))
    (dolist (el elements)
      (multiple-value-bind (sym val)
          (if (listp el)
              (values (first el) (second el))
              (values el (1+ prev)))
        (setf prev val)
        (unless (symbolp sym)
          (error "The enumeration element ~S is not a symbol." sym))
        (unless (integerp val)
          (error "The element value ~S is not an integer." val))
        (unless (and max (> max val)) (setq max val))
        (unless (and min (< min val)) (setq min val))
        (when (rassoc val from-alist)
          (style-warn "The element value ~S is used more than once." val))
        (when (assoc sym from-alist :test #'eq)
          (error "The enumeration element ~S is used more than once." sym))
        (push (cons sym val) from-alist)))
    (let* ((signed (minusp min))
           (min-bits (if signed
                         (1+ (max (integer-length min)
                                  (integer-length max)))
                         (integer-length max))))
      (when (> min-bits 32)
        (error "can't represent enums needing more than 32 bits"))
      (setf from-alist (sort from-alist #'< :key #'cdr))
      (cond
       ;; If range is at least 20% dense, use vector mapping. Crossover
       ;; point solely on basis of space would be 25%. Vector mapping
       ;; is always faster, so give the benefit of the doubt.
       ((< 0.2 (/ (float (length from-alist)) (float (1+ (- max min)))))
        ;; If offset is small and ignorable, ignore it to save time.
        (when (< 0 min 10) (setq min 0))
        (let ((to (make-array (1+ (- max min)))))
          (dolist (el from-alist)
            (setf (svref to (- (cdr el) min)) (car el)))
          (make-alien-enum-type :name name :signed signed
                                :from from-alist :to to :kind
                                :vector :offset (- min))))
       (t
        (make-alien-enum-type :name name :signed signed
                              :from from-alist
                              :to (mapcar (lambda (x) (cons (cdr x) (car x)))
                                          from-alist)
                              :kind :alist))))))

(define-alien-type-method (enum :unparse) (type)
  `(enum ,(alien-enum-type-name type)
         ,@(let ((prev -1))
             (mapcar (lambda (mapping)
                       (let ((sym (car mapping))
                             (value (cdr mapping)))
                         (prog1
                             (if (= (1+ prev) value)
                                 sym
                                 `(,sym ,value))
                           (setf prev value))))
                     (alien-enum-type-from type)))))

(define-alien-type-method (enum :type=) (type1 type2)
  (and (eq (alien-enum-type-name type1)
           (alien-enum-type-name type2))
       (equal (alien-enum-type-from type1)
              (alien-enum-type-from type2))))

(define-alien-type-method (enum :lisp-rep) (type)
  `(member ,@(mapcar #'car (alien-enum-type-from type))))

(define-alien-type-method (enum :naturalize-gen) (type alien)
  (ecase (alien-enum-type-kind type)
    (:vector
     `(svref ',(alien-enum-type-to type)
             (+ ,alien ,(alien-enum-type-offset type))))
    (:alist
     `(ecase ,alien
        ,@(mapcar (lambda (mapping)
                    `(,(car mapping) ',(cdr mapping)))
                  (alien-enum-type-to type))))))

(define-alien-type-method (enum :deport-gen) (type value)
  `(ecase ,value
     ,@(mapcar (lambda (mapping)
                 `(,(car mapping) ,(cdr mapping)))
               (alien-enum-type-from type))))

;;;; the FLOAT types

(define-alien-type-class (float)
  (type (missing-arg) :type symbol))

(define-alien-type-method (float :unparse) (type)
  (alien-float-type-type type))

(define-alien-type-method (float :lisp-rep) (type)
  (alien-float-type-type type))

(define-alien-type-method (float :alien-rep) (type context)
  (declare (ignore context))
  (alien-float-type-type type))

(define-alien-type-method (float :naturalize-gen) (type alien)
  (declare (ignore type))
  alien)

(define-alien-type-method (float :deport-gen) (type value)
  (declare (ignore type))
  value)

(define-alien-type-class (single-float :include (float (bits 32))
                                       :include-args (type)))

(define-alien-type-translator single-float ()
  (make-alien-single-float-type :type 'single-float))

(define-alien-type-method (single-float :extract-gen) (type sap offset)
  (declare (ignore type))
  `(sap-ref-single ,sap (/ ,offset sb!vm:n-byte-bits)))

(define-alien-type-class (double-float :include (float (bits 64))
                                       :include-args (type)))

(define-alien-type-translator double-float ()
  (make-alien-double-float-type :type 'double-float))

(define-alien-type-method (double-float :extract-gen) (type sap offset)
  (declare (ignore type))
  `(sap-ref-double ,sap (/ ,offset sb!vm:n-byte-bits)))


;;;; the POINTER type

(define-alien-type-class (pointer :include (alien-value (bits
                                                         #!-alpha
                                                         sb!vm:n-word-bits
                                                         #!+alpha 64)))
  (to nil :type (or alien-type null)))

(define-alien-type-translator * (to &environment env)
  (make-alien-pointer-type :to (if (eq to t) nil (parse-alien-type to env))))

(define-alien-type-method (pointer :unparse) (type)
  (let ((to (alien-pointer-type-to type)))
    `(* ,(if to
             (%unparse-alien-type to)
             t))))

(define-alien-type-method (pointer :type=) (type1 type2)
  (let ((to1 (alien-pointer-type-to type1))
        (to2 (alien-pointer-type-to type2)))
    (if to1
        (if to2
            (alien-type-= to1 to2)
            nil)
        (null to2))))

(define-alien-type-method (pointer :subtypep) (type1 type2)
  (and (alien-pointer-type-p type2)
       (let ((to1 (alien-pointer-type-to type1))
             (to2 (alien-pointer-type-to type2)))
         (if to1
             (if to2
                 (alien-subtype-p to1 to2)
                 t)
             (null to2)))))

(define-alien-type-method (pointer :deport-gen) (type value)
  (/noshow "doing alien type method POINTER :DEPORT-GEN" type value)
  (values
   ;; FIXME: old version, highlighted a bug in xc optimization
   `(etypecase ,value
      (null
       (int-sap 0))
      (system-area-pointer
       ,value)
      ((alien ,type)
       (alien-sap ,value)))
   ;; new version, works around bug in xc optimization
   #+nil
   `(etypecase ,value
      (system-area-pointer
       ,value)
      ((alien ,type)
       (alien-sap ,value))
      (null
       (int-sap 0)))
   `(or null system-area-pointer (alien ,type))))

;;;; the MEM-BLOCK type

(define-alien-type-class (mem-block :include alien-value))

(define-alien-type-method (mem-block :extract-gen) (type sap offset)
  (declare (ignore type))
  `(sap+ ,sap (truncate ,offset sb!vm:n-byte-bits)))

(define-alien-type-method (mem-block :deposit-gen) (type sap offset value)
  (let ((bits (alien-mem-block-type-bits type)))
    (unless bits
      (error "can't deposit aliens of type ~S (unknown size)" type))
    `(sb!kernel:system-area-ub8-copy ,value 0 ,sap
      (truncate ,offset sb!vm:n-byte-bits)
      ',(truncate bits sb!vm:n-byte-bits))))

;;;; the ARRAY type

(define-alien-type-class (array :include mem-block)
  (element-type (missing-arg) :type alien-type)
  (dimensions (missing-arg) :type list))

(define-alien-type-translator array (ele-type &rest dims &environment env)

  (when dims
    (unless (typep (first dims) '(or index null))
      (error "The first dimension is not a non-negative fixnum or NIL: ~S"
             (first dims)))
    (let ((loser (find-if-not (lambda (x) (typep x 'index))
                              (rest dims))))
      (when loser
        (error "A dimension is not a non-negative fixnum: ~S" loser))))

  (let ((parsed-ele-type (parse-alien-type ele-type env)))
    (make-alien-array-type
     :element-type parsed-ele-type
     :dimensions dims
     :alignment (alien-type-alignment parsed-ele-type)
     :bits (if (and (alien-type-bits parsed-ele-type)
                    (every #'integerp dims))
               (* (align-offset (alien-type-bits parsed-ele-type)
                                (alien-type-alignment parsed-ele-type))
                  (reduce #'* dims))))))

(define-alien-type-method (array :unparse) (type)
  `(array ,(%unparse-alien-type (alien-array-type-element-type type))
          ,@(alien-array-type-dimensions type)))

(define-alien-type-method (array :type=) (type1 type2)
  (and (equal (alien-array-type-dimensions type1)
              (alien-array-type-dimensions type2))
       (alien-type-= (alien-array-type-element-type type1)
                     (alien-array-type-element-type type2))))

(define-alien-type-method (array :subtypep) (type1 type2)
  (and (alien-array-type-p type2)
       (let ((dim1 (alien-array-type-dimensions type1))
             (dim2 (alien-array-type-dimensions type2)))
         (and (= (length dim1) (length dim2))
              (or (and dim2
                       (null (car dim2))
                       (equal (cdr dim1) (cdr dim2)))
                  (equal dim1 dim2))
              (alien-subtype-p (alien-array-type-element-type type1)
                               (alien-array-type-element-type type2))))))

;;;; the RECORD type

(def!struct (alien-record-field
             (:make-load-form-fun sb!kernel:just-dump-it-normally))
  (name (missing-arg) :type symbol)
  (type (missing-arg) :type alien-type)
  (bits nil :type (or unsigned-byte null))
  (offset 0 :type unsigned-byte))
(def!method print-object ((field alien-record-field) stream)
  (print-unreadable-object (field stream :type t)
    (format stream
            "~S ~S~@[:~D~]"
            (alien-record-field-type field)
            (alien-record-field-name field)
            (alien-record-field-bits field))))

(define-alien-type-class (record :include mem-block)
  (kind :struct :type (member :struct :union))
  (name nil :type (or symbol null))
  (fields nil :type list))

(define-alien-type-translator struct (name &rest fields &environment env)
  (parse-alien-record-type :struct name fields env))

(define-alien-type-translator union (name &rest fields &environment env)
  (parse-alien-record-type :union name fields env))

;;; FIXME: This is really pretty horrible: we avoid creating new
;;; ALIEN-RECORD-TYPE objects when a live one is flitting around the
;;; system already. This way forwrd-references sans fields get get
;;; "updated" for free to contain the field info. Maybe rename
;;; MAKE-ALIEN-RECORD-TYPE to %MAKE-ALIEN-RECORD-TYPE and use
;;; ENSURE-ALIEN-RECORD-TYPE instead. --NS 20040729
(defun parse-alien-record-type (kind name fields env)
  (declare (type (or sb!kernel:lexenv null) env))
  (flet ((frob-type (type new-fields alignment bits)
           (setf (alien-record-type-fields type) new-fields
                 (alien-record-type-alignment type) alignment
                 (alien-record-type-bits type) bits)))
      (cond (fields
             (multiple-value-bind (new-fields alignment bits)
                 (parse-alien-record-fields kind fields env)
               (let* ((old (and name (auxiliary-alien-type kind name env)))
                      (old-fields (and old (alien-record-type-fields old))))
                 (when (and old-fields
                            (notevery #'record-fields-match-p old-fields new-fields))
                   (cerror "Continue, clobbering the old definition."
                           "Incompatible alien record type definition~%Old: ~S~%New: ~S"
                           (unparse-alien-type old)
                           `(,(unparse-alien-record-kind kind)
                              ,name
                              ,@(mapcar #'unparse-alien-record-field new-fields)))
                   (frob-type old new-fields alignment bits))
                 (if old-fields
                     old
                     (let ((type (or old (make-alien-record-type :name name :kind kind))))
                       (when (and name (not old))
                         (setf (auxiliary-alien-type kind name env) type))
                       (frob-type type new-fields alignment bits)
                       type)))))
            (name
             (or (auxiliary-alien-type kind name env)
                 (setf (auxiliary-alien-type kind name env)
                       (make-alien-record-type :name name :kind kind))))
            (t
             (make-alien-record-type :kind kind)))))

;;; This is used by PARSE-ALIEN-TYPE to parse the fields of struct and union
;;; types. KIND is the kind we are paring the fields of, and FIELDS is the
;;; list of field specifications.
;;;
;;; Result is a list of field objects, overall alignment, and number of bits
(defun parse-alien-record-fields (kind fields env)
  (declare (type list fields))
  (let ((total-bits 0)
        (overall-alignment 1)
        (parsed-fields nil))
    (dolist (field fields)
      (destructuring-bind (var type &key alignment) field
        (let* ((field-type (parse-alien-type type env))
               (bits (alien-type-bits field-type))
               (parsed-field
                (make-alien-record-field :type field-type
                                         :name var)))
          (unless alignment
            (setf alignment (alien-type-alignment field-type)))
          (push parsed-field parsed-fields)
          (when (null bits)
            (error "unknown size: ~S" (unparse-alien-type field-type)))
          (when (null alignment)
            (error "unknown alignment: ~S" (unparse-alien-type field-type)))
          (setf overall-alignment (max overall-alignment alignment))
          (ecase kind
            (:struct
             (let ((offset (align-offset total-bits alignment)))
               (setf (alien-record-field-offset parsed-field) offset)
               (setf total-bits (+ offset bits))))
            (:union
             (setf total-bits (max total-bits bits)))))))
    (values (nreverse parsed-fields)
            overall-alignment
            (align-offset total-bits overall-alignment))))

(define-alien-type-method (record :unparse) (type)
  `(,(unparse-alien-record-kind (alien-record-type-kind type))
    ,(alien-record-type-name type)
    ,@(unless (member type *record-types-already-unparsed* :test #'eq)
        (push type *record-types-already-unparsed*)
        (mapcar #'unparse-alien-record-field
                (alien-record-type-fields type)))))

(defun unparse-alien-record-kind (kind)
  (case kind
    (:struct 'struct)
    (:union 'union)
    (t '???)))

(defun unparse-alien-record-field (field)
  `(,(alien-record-field-name field)
     ,(%unparse-alien-type (alien-record-field-type field))
     ,@(when (alien-record-field-bits field)
             (list (alien-record-field-bits field)))))

;;; Test the record fields. Keep a hashtable table of already compared
;;; types to detect cycles.
(defun record-fields-match-p (field1 field2)
  (and (eq (alien-record-field-name field1)
           (alien-record-field-name field2))
       (eql (alien-record-field-bits field1)
            (alien-record-field-bits field2))
       (eql (alien-record-field-offset field1)
            (alien-record-field-offset field2))
       (alien-type-= (alien-record-field-type field1)
                     (alien-record-field-type field2))))

(defvar *alien-type-matches* nil
  "A hashtable used to detect cycles while comparing record types.")

(define-alien-type-method (record :type=) (type1 type2)
  (and (eq (alien-record-type-name type1)
           (alien-record-type-name type2))
       (eq (alien-record-type-kind type1)
           (alien-record-type-kind type2))
       (eql (alien-type-bits type1)
            (alien-type-bits type2))
       (eql (alien-type-alignment type1)
            (alien-type-alignment type2))
       (flet ((match-fields (&optional old)
                (setf (gethash type1 *alien-type-matches*) (cons type2 old))
                (every #'record-fields-match-p
                       (alien-record-type-fields type1)
                       (alien-record-type-fields type2))))
         (if *alien-type-matches*
             (let ((types (gethash type1 *alien-type-matches*)))
               (or (memq type2 types) (match-fields types)))
             (let ((*alien-type-matches* (make-hash-table :test #'eq)))
               (match-fields))))))

;;;; the FUNCTION and VALUES alien types

(define-alien-type-class (fun :include mem-block)
  (result-type (missing-arg) :type alien-type)
  (arg-types (missing-arg) :type list)
  (stub nil :type (or null function)))

(define-alien-type-translator function (result-type &rest arg-types
                                                    &environment env)
  (make-alien-fun-type
   :result-type (let ((*values-type-okay* t))
                  (parse-alien-type result-type env))
   :arg-types (mapcar (lambda (arg-type) (parse-alien-type arg-type env))
                      arg-types)))

(define-alien-type-method (fun :unparse) (type)
  `(function ,(%unparse-alien-type (alien-fun-type-result-type type))
             ,@(mapcar #'%unparse-alien-type
                       (alien-fun-type-arg-types type))))

(define-alien-type-method (fun :type=) (type1 type2)
  (and (alien-type-= (alien-fun-type-result-type type1)
                     (alien-fun-type-result-type type2))
       (= (length (alien-fun-type-arg-types type1))
          (length (alien-fun-type-arg-types type2)))
       (every #'alien-type-=
              (alien-fun-type-arg-types type1)
              (alien-fun-type-arg-types type2))))

(define-alien-type-class (values)
  (values (missing-arg) :type list))

(define-alien-type-translator values (&rest values &environment env)
  (unless *values-type-okay*
    (error "cannot use values types here"))
  (let ((*values-type-okay* nil))
    (make-alien-values-type
     :values (mapcar (lambda (alien-type) (parse-alien-type alien-type env))
                     values))))

(define-alien-type-method (values :unparse) (type)
  `(values ,@(mapcar #'%unparse-alien-type
                     (alien-values-type-values type))))

(define-alien-type-method (values :type=) (type1 type2)
  (and (= (length (alien-values-type-values type1))
          (length (alien-values-type-values type2)))
       (every #'alien-type-=
              (alien-values-type-values type1)
              (alien-values-type-values type2))))

;;;; a structure definition needed both in the target and in the
;;;; cross-compilation host

;;; information about local aliens. The WITH-ALIEN macro builds one of
;;; these structures and LOCAL-ALIEN and friends communicate
;;; information about how that local alien is represented.
(def!struct (local-alien-info
             (:make-load-form-fun sb!kernel:just-dump-it-normally)
             (:constructor make-local-alien-info
                           (&key type force-to-memory-p
                            &aux (force-to-memory-p (or force-to-memory-p
                                                        (alien-array-type-p type)
                                                        (alien-record-type-p type))))))
  ;; the type of the local alien
  (type (missing-arg) :type alien-type)
  ;; Must this local alien be forced into memory? Using the ADDR macro
  ;; on a local alien will set this.
  (force-to-memory-p nil :type (member t nil)))
(def!method print-object ((info local-alien-info) stream)
  (print-unreadable-object (info stream :type t)
    (format stream
            "~:[~;(forced to stack) ~]~S"
            (local-alien-info-force-to-memory-p info)
            (unparse-alien-type (local-alien-info-type info)))))

;;;; the ADDR macro

(defmacro-mundanely addr (expr &environment env)
  #!+sb-doc
  "Return an Alien pointer to the data addressed by Expr, which must be a call
   to SLOT or DEREF, or a reference to an Alien variable."
  (let ((form (%macroexpand expr env)))
    (or (typecase form
          (cons
           (case (car form)
             (slot
              (cons '%slot-addr (cdr form)))
             (deref
              (cons '%deref-addr (cdr form)))
             (%heap-alien
              (cons '%heap-alien-addr (cdr form)))
             (local-alien
              (let ((info (let ((info-arg (second form)))
                            (and (consp info-arg)
                                 (eq (car info-arg) 'quote)
                                 (second info-arg)))))
                (unless (local-alien-info-p info)
                  (error "Something is wrong, LOCAL-ALIEN-INFO not found: ~S"
                         form))
                (setf (local-alien-info-force-to-memory-p info) t))
              (cons '%local-alien-addr (cdr form)))))
          (symbol
           (let ((kind (info :variable :kind form)))
             (when (eq kind :alien)
               `(%heap-alien-addr ',(info :variable :alien-info form))))))
        (error "~S is not a valid L-value." form))))

(/show0 "host-alieneval.lisp end of file")
