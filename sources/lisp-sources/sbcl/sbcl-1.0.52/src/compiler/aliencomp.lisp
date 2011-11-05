;;;; transforms and other stuff used to compile ALIEN operations

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; This software is derived from the CMU CL system, which was
;;;; written at Carnegie Mellon University and released into the
;;;; public domain. The software is in the public domain and is
;;;; provided with absolutely no warranty. See the COPYING and CREDITS
;;;; files for more information.

(in-package "SB!C")

;;;; DEFKNOWNs

(defknown %sap-alien (system-area-pointer alien-type) alien-value
  (flushable movable))
(defknown alien-sap (alien-value) system-area-pointer
  (flushable movable))

(defknown slot (alien-value symbol) t
  (flushable recursive))
(defknown %set-slot (alien-value symbol t) t
  (recursive))
(defknown %slot-addr (alien-value symbol) (alien (* t))
  (flushable movable recursive))

(defknown deref (alien-value &rest index) t
  (flushable))
(defknown %set-deref (alien-value t &rest index) t
  ())
(defknown %deref-addr (alien-value &rest index) (alien (* t))
  (flushable movable))

(defknown %heap-alien (heap-alien-info) t
  (flushable))
(defknown %set-heap-alien (heap-alien-info t) t
  ())
(defknown %heap-alien-addr (heap-alien-info) (alien (* t))
  (flushable movable))

(defknown make-local-alien (local-alien-info) t
  ())
(defknown note-local-alien-type (local-alien-info t) null
  ())
(defknown local-alien (local-alien-info t) t
  (flushable))
(defknown %local-alien-forced-to-memory-p (local-alien-info) (member t nil)
  (movable))
(defknown %set-local-alien (local-alien-info t t) t
  ())
(defknown %local-alien-addr (local-alien-info t) (alien (* t))
  (flushable movable))
(defknown dispose-local-alien (local-alien-info t) t
  ())

(defknown %cast (alien-value alien-type) alien
  (flushable movable))

(defknown naturalize (t alien-type) alien
  (flushable movable))
(defknown deport (alien alien-type) t
  (flushable movable))
(defknown deport-alloc (alien alien-type) t
  (flushable movable))
(defknown extract-alien-value (system-area-pointer unsigned-byte alien-type) t
  (flushable))
(defknown deposit-alien-value (system-area-pointer unsigned-byte alien-type t) t
  ())

(defknown alien-funcall (alien-value &rest *) *
  (any recursive))

;;;; cosmetic transforms

(deftransform slot ((object slot)
                    ((alien (* t)) symbol))
  '(slot (deref object) slot))

(deftransform %set-slot ((object slot value)
                         ((alien (* t)) symbol t))
  '(%set-slot (deref object) slot value))

(deftransform %slot-addr ((object slot)
                          ((alien (* t)) symbol))
  '(%slot-addr (deref object) slot))

;;;; SLOT support

(defun find-slot-offset-and-type (alien slot)
  (unless (constant-lvar-p slot)
    (give-up-ir1-transform
     "The slot is not constant, so access cannot be open coded."))
  (let ((type (lvar-type alien)))
    (unless (alien-type-type-p type)
      (give-up-ir1-transform))
    (let ((alien-type (alien-type-type-alien-type type)))
      (unless (alien-record-type-p alien-type)
        (give-up-ir1-transform))
      (let* ((slot-name (lvar-value slot))
             (field (find slot-name (alien-record-type-fields alien-type)
                          :key #'alien-record-field-name)))
        (unless field
          (abort-ir1-transform "~S doesn't have a slot named ~S"
                               alien
                               slot-name))
        (values (alien-record-field-offset field)
                (alien-record-field-type field))))))

#+nil ;; Shouldn't be necessary.
(defoptimizer (slot derive-type) ((alien slot))
  (block nil
    (catch 'give-up-ir1-transform
      (multiple-value-bind (slot-offset slot-type)
          (find-slot-offset-and-type alien slot)
        (declare (ignore slot-offset))
        (return (make-alien-type-type slot-type))))
    *wild-type*))

(deftransform slot ((alien slot) * * :important t)
  (multiple-value-bind (slot-offset slot-type)
      (find-slot-offset-and-type alien slot)
    `(extract-alien-value (alien-sap alien)
                          ,slot-offset
                          ',slot-type)))

#+nil ;; ### But what about coercions?
(defoptimizer (%set-slot derive-type) ((alien slot value))
  (block nil
    (catch 'give-up-ir1-transform
      (multiple-value-bind (slot-offset slot-type)
          (find-slot-offset-and-type alien slot)
        (declare (ignore slot-offset))
        (let ((type (make-alien-type-type slot-type)))
          (assert-lvar-type value type)
          (return type))))
    *wild-type*))

(deftransform %set-slot ((alien slot value) * * :important t)
  (multiple-value-bind (slot-offset slot-type)
      (find-slot-offset-and-type alien slot)
    `(deposit-alien-value (alien-sap alien)
                          ,slot-offset
                          ',slot-type
                          value)))

(defoptimizer (%slot-addr derive-type) ((alien slot))
  (block nil
    (catch 'give-up-ir1-transform
      (multiple-value-bind (slot-offset slot-type)
          (find-slot-offset-and-type alien slot)
        (declare (ignore slot-offset))
        (return (make-alien-type-type
                 (make-alien-pointer-type :to slot-type)))))
    *wild-type*))

(deftransform %slot-addr ((alien slot) * * :important t)
  (multiple-value-bind (slot-offset slot-type)
      (find-slot-offset-and-type alien slot)
    (/noshow "in DEFTRANSFORM %SLOT-ADDR, creating %SAP-ALIEN")
    `(%sap-alien (sap+ (alien-sap alien) (/ ,slot-offset sb!vm:n-byte-bits))
                 ',(make-alien-pointer-type :to slot-type))))

;;;; DEREF support

(defun find-deref-alien-type (alien)
  (let ((alien-type (lvar-type alien)))
    (unless (alien-type-type-p alien-type)
      (give-up-ir1-transform))
    (let ((alien-type (alien-type-type-alien-type alien-type)))
      (if (alien-type-p alien-type)
          alien-type
          (give-up-ir1-transform)))))

(defun find-deref-element-type (alien)
  (let ((alien-type (find-deref-alien-type alien)))
    (typecase alien-type
      (alien-pointer-type
       (alien-pointer-type-to alien-type))
      (alien-array-type
       (alien-array-type-element-type alien-type))
      (t
       (give-up-ir1-transform)))))

(defun compute-deref-guts (alien indices)
  (let ((alien-type (find-deref-alien-type alien)))
    (typecase alien-type
      (alien-pointer-type
       (when (cdr indices)
         (abort-ir1-transform "too many indices for pointer deref: ~W"
                              (length indices)))
       (let ((element-type (alien-pointer-type-to alien-type)))
         (unless element-type
           (give-up-ir1-transform "unable to open code deref of wild pointer type"))
         (if indices
             (let ((bits (alien-type-bits element-type))
                   (alignment (alien-type-alignment element-type)))
               (unless bits
                 (abort-ir1-transform "unknown element size"))
               (unless alignment
                 (abort-ir1-transform "unknown element alignment"))
               (values '(offset)
                       `(* offset
                           ,(align-offset bits alignment))
                       element-type))
             (values nil 0 element-type))))
      (alien-array-type
       (let* ((element-type (alien-array-type-element-type alien-type))
              (bits (alien-type-bits element-type))
              (alignment (alien-type-alignment element-type))
              (dims (alien-array-type-dimensions alien-type)))
         (unless (= (length indices) (length dims))
           (give-up-ir1-transform "incorrect number of indices"))
         (unless bits
           (give-up-ir1-transform "Element size is unknown."))
         (unless alignment
           (give-up-ir1-transform "Element alignment is unknown."))
         (if (null dims)
             (values nil 0 element-type)
             (let* ((arg (gensym))
                    (args (list arg))
                    (offsetexpr arg))
               (dolist (dim (cdr dims))
                 (let ((arg (gensym)))
                   (push arg args)
                   (setf offsetexpr `(+ (* ,offsetexpr ,dim) ,arg))))
               (values (reverse args)
                       `(* ,offsetexpr
                           ,(align-offset bits alignment))
                       element-type)))))
      (t
       (abort-ir1-transform "~S not either a pointer or array type."
                            alien-type)))))

#+nil ;; Shouldn't be necessary.
(defoptimizer (deref derive-type) ((alien &rest noise))
  (declare (ignore noise))
  (block nil
    (catch 'give-up-ir1-transform
      (return (make-alien-type-type (find-deref-element-type alien))))
    *wild-type*))

(deftransform deref ((alien &rest indices) * * :important t)
  (multiple-value-bind (indices-args offset-expr element-type)
      (compute-deref-guts alien indices)
    `(lambda (alien ,@indices-args)
       (extract-alien-value (alien-sap alien)
                            ,offset-expr
                            ',element-type))))

#+nil ;; ### Again, the value might be coerced.
(defoptimizer (%set-deref derive-type) ((alien value &rest noise))
  (declare (ignore noise))
  (block nil
    (catch 'give-up-ir1-transform
      (let ((type (make-alien-type-type
                   (make-alien-pointer-type
                    :to (find-deref-element-type alien)))))
        (assert-lvar-type value type)
        (return type)))
    *wild-type*))

(deftransform %set-deref ((alien value &rest indices) * * :important t)
  (multiple-value-bind (indices-args offset-expr element-type)
      (compute-deref-guts alien indices)
    `(lambda (alien value ,@indices-args)
       (deposit-alien-value (alien-sap alien)
                            ,offset-expr
                            ',element-type
                            value))))

(defoptimizer (%deref-addr derive-type) ((alien &rest noise))
  (declare (ignore noise))
  (block nil
    (catch 'give-up-ir1-transform
      (return (make-alien-type-type
               (make-alien-pointer-type
                :to (find-deref-element-type alien)))))
    *wild-type*))

(deftransform %deref-addr ((alien &rest indices) * * :important t)
  (multiple-value-bind (indices-args offset-expr element-type)
      (compute-deref-guts alien indices)
    (/noshow "in DEFTRANSFORM %DEREF-ADDR, creating (LAMBDA .. %SAP-ALIEN)")
    `(lambda (alien ,@indices-args)
       (%sap-alien (sap+ (alien-sap alien) (/ ,offset-expr sb!vm:n-byte-bits))
                   ',(make-alien-pointer-type :to element-type)))))

;;;; support for aliens on the heap

(defun heap-alien-sap-and-type (info)
  (unless (constant-lvar-p info)
    (give-up-ir1-transform "info not constant; can't open code"))
  (let ((info (lvar-value info)))
    (values (heap-alien-info-sap-form info)
            (heap-alien-info-type info))))

#+nil ; shouldn't be necessary
(defoptimizer (%heap-alien derive-type) ((info))
  (block nil
    (catch 'give-up
      (multiple-value-bind (sap type) (heap-alien-sap-and-type info)
        (declare (ignore sap))
        (return (make-alien-type-type type))))
    *wild-type*))

(deftransform %heap-alien ((info) * * :important t)
  (multiple-value-bind (sap type) (heap-alien-sap-and-type info)
    `(extract-alien-value ,sap 0 ',type)))

#+nil ;; ### Again, deposit value might change the type.
(defoptimizer (%set-heap-alien derive-type) ((info value))
  (block nil
    (catch 'give-up-ir1-transform
      (multiple-value-bind (sap type) (heap-alien-sap-and-type info)
        (declare (ignore sap))
        (let ((type (make-alien-type-type type)))
          (assert-lvar-type value type)
          (return type))))
    *wild-type*))

(deftransform %set-heap-alien ((info value) (heap-alien-info *) * :important t)
  (multiple-value-bind (sap type) (heap-alien-sap-and-type info)
    `(deposit-alien-value ,sap 0 ',type value)))

(defoptimizer (%heap-alien-addr derive-type) ((info))
  (block nil
    (catch 'give-up-ir1-transform
      (multiple-value-bind (sap type) (heap-alien-sap-and-type info)
        (declare (ignore sap))
        (return (make-alien-type-type (make-alien-pointer-type :to type)))))
    *wild-type*))

(deftransform %heap-alien-addr ((info) * * :important t)
  (multiple-value-bind (sap type) (heap-alien-sap-and-type info)
    (/noshow "in DEFTRANSFORM %HEAP-ALIEN-ADDR, creating %SAP-ALIEN")
    `(%sap-alien ,sap ',(make-alien-pointer-type :to type))))


;;;; support for local (stack or register) aliens

(defun alien-info-constant-or-abort (info)
  (unless (constant-lvar-p info)
    (abort-ir1-transform "Local alien info isn't constant?")))

(deftransform make-local-alien ((info) * * :important t)
  (alien-info-constant-or-abort info)
  (let* ((info (lvar-value info))
         (alien-type (local-alien-info-type info))
         (bits (alien-type-bits alien-type)))
    (unless bits
      (abort-ir1-transform "unknown size: ~S" (unparse-alien-type alien-type)))
    (/noshow "in DEFTRANSFORM MAKE-LOCAL-ALIEN" info)
    (/noshow (local-alien-info-force-to-memory-p info))
    (/noshow alien-type (unparse-alien-type alien-type) (alien-type-bits alien-type))
    (if (local-alien-info-force-to-memory-p info)
        #!+(or x86 x86-64)
        `(%primitive alloc-alien-stack-space
                     ,(ceiling (alien-type-bits alien-type)
                               sb!vm:n-byte-bits))
        #!-(or x86 x86-64)
        `(%primitive alloc-number-stack-space
                     ,(ceiling (alien-type-bits alien-type)
                               sb!vm:n-byte-bits))
        (let* ((alien-rep-type-spec (compute-alien-rep-type alien-type))
               (alien-rep-type (specifier-type alien-rep-type-spec)))
          (cond ((csubtypep (specifier-type 'system-area-pointer)
                            alien-rep-type)
                 '(int-sap 0))
                ((ctypep 0 alien-rep-type) 0)
                ((ctypep 0.0f0 alien-rep-type) 0.0f0)
                ((ctypep 0.0d0 alien-rep-type) 0.0d0)
                (t
                 (compiler-error
                  "Aliens of type ~S cannot be represented immediately."
                  (unparse-alien-type alien-type))))))))

(deftransform note-local-alien-type ((info var) * * :important t)
  (alien-info-constant-or-abort info)
  (let ((info (lvar-value info)))
    (/noshow "in DEFTRANSFORM NOTE-LOCAL-ALIEN-TYPE" info)
    (/noshow (local-alien-info-force-to-memory-p info))
    (unless (local-alien-info-force-to-memory-p info)
      (let ((var-node (lvar-uses var)))
        (/noshow var-node (ref-p var-node))
        (when (ref-p var-node)
          (propagate-to-refs (ref-leaf var-node)
                             (specifier-type
                              (compute-alien-rep-type
                               (local-alien-info-type info))))))))
  nil)

(deftransform local-alien ((info var) * * :important t)
  (alien-info-constant-or-abort info)
  (let* ((info (lvar-value info))
         (alien-type (local-alien-info-type info)))
    (/noshow "in DEFTRANSFORM LOCAL-ALIEN" info alien-type)
    (/noshow (local-alien-info-force-to-memory-p info))
    (if (local-alien-info-force-to-memory-p info)
        `(extract-alien-value var 0 ',alien-type)
        `(naturalize var ',alien-type))))

(deftransform %local-alien-forced-to-memory-p ((info) * * :important t)
  (alien-info-constant-or-abort info)
  (let ((info (lvar-value info)))
    (local-alien-info-force-to-memory-p info)))

(deftransform %set-local-alien ((info var value) * * :important t)
  (alien-info-constant-or-abort info)
  (let* ((info (lvar-value info))
         (alien-type (local-alien-info-type info)))
    (if (local-alien-info-force-to-memory-p info)
        `(deposit-alien-value var 0 ',alien-type value)
        '(error "This should be eliminated as dead code."))))

(defoptimizer (%local-alien-addr derive-type) ((info var))
  (if (constant-lvar-p info)
      (let* ((info (lvar-value info))
             (alien-type (local-alien-info-type info)))
        (make-alien-type-type (make-alien-pointer-type :to alien-type)))
      *wild-type*))

(deftransform %local-alien-addr ((info var) * * :important t)
  (alien-info-constant-or-abort info)
  (let* ((info (lvar-value info))
         (alien-type (local-alien-info-type info)))
    (/noshow "in DEFTRANSFORM %LOCAL-ALIEN-ADDR, creating %SAP-ALIEN")
    (if (local-alien-info-force-to-memory-p info)
        `(%sap-alien var ',(make-alien-pointer-type :to alien-type))
        (error "This shouldn't happen."))))

(deftransform dispose-local-alien ((info var) * * :important t)
  (alien-info-constant-or-abort info)
  (let* ((info (lvar-value info))
         (alien-type (local-alien-info-type info)))
    (if (local-alien-info-force-to-memory-p info)
      #!+(or x86 x86-64) `(%primitive dealloc-alien-stack-space
                          ,(ceiling (alien-type-bits alien-type)
                                    sb!vm:n-byte-bits))
      #!-(or x86 x86-64) `(%primitive dealloc-number-stack-space
                          ,(ceiling (alien-type-bits alien-type)
                                    sb!vm:n-byte-bits))
      nil)))

;;;; %CAST

(defoptimizer (%cast derive-type) ((alien type))
  (or (when (constant-lvar-p type)
        (let ((alien-type (lvar-value type)))
          (when (alien-type-p alien-type)
            (make-alien-type-type alien-type))))
      *wild-type*))

(deftransform %cast ((alien target-type) * * :important t)
  (unless (constant-lvar-p target-type)
    (give-up-ir1-transform
     "The alien type is not constant, so access cannot be open coded."))
  (let ((target-type (lvar-value target-type)))
    (cond ((or (alien-pointer-type-p target-type)
               (alien-array-type-p target-type)
               (alien-fun-type-p target-type))
           `(naturalize (alien-sap alien) ',target-type))
          (t
           (abort-ir1-transform "cannot cast to alien type ~S" target-type)))))

;;;; ALIEN-SAP, %SAP-ALIEN, %ADDR, etc.

(deftransform alien-sap ((alien) * * :important t)
  (let ((alien-node (lvar-uses alien)))
    (typecase alien-node
      (combination
       (splice-fun-args alien '%sap-alien 2)
       '(lambda (sap type)
          (declare (ignore type))
          sap))
      (t
       (give-up-ir1-transform)))))

(defoptimizer (%sap-alien derive-type) ((sap type))
  (declare (ignore sap))
  (if (constant-lvar-p type)
      (make-alien-type-type (lvar-value type))
      *wild-type*))

(deftransform %sap-alien ((sap type) * * :important t)
  (give-up-ir1-transform
   ;; FIXME: The hardcoded newline here causes more-than-usually
   ;; screwed-up formatting of the optimization note output.
   "could not optimize away %SAP-ALIEN: forced to do runtime ~@
    allocation of alien-value structure"))

;;;; NATURALIZE/DEPORT/EXTRACT/DEPOSIT magic

(flet ((%computed-lambda (compute-lambda type)
         (declare (type function compute-lambda))
         (unless (constant-lvar-p type)
           (give-up-ir1-transform
            "The type is not constant at compile time; can't open code."))
         (handler-case
             (let ((result (funcall compute-lambda (lvar-value type))))
               (/noshow "in %COMPUTED-LAMBDA" (lvar-value type) result)
               result)
           (error (condition)
                  (compiler-error "~A" condition)))))
  (deftransform naturalize ((object type) * * :important t)
    (%computed-lambda #'compute-naturalize-lambda type))
  (deftransform deport ((alien type) * * :important t)
    (%computed-lambda #'compute-deport-lambda type))
  (deftransform deport-alloc ((alien type) * * :important t)
    (%computed-lambda #'compute-deport-alloc-lambda type))
  (deftransform extract-alien-value ((sap offset type) * * :important t)
    (%computed-lambda #'compute-extract-lambda type))
  (deftransform deposit-alien-value ((sap offset type value) * * :important t)
    (%computed-lambda #'compute-deposit-lambda type)))

;;;; a hack to clean up divisions

(defun count-low-order-zeros (thing)
  (typecase thing
    (lvar
     (if (constant-lvar-p thing)
         (count-low-order-zeros (lvar-value thing))
         (count-low-order-zeros (lvar-uses thing))))
    (combination
     (case (let ((name (lvar-fun-name (combination-fun thing))))
             (or (modular-version-info name :untagged nil) name))
       ((+ -)
        (let ((min most-positive-fixnum)
              (itype (specifier-type 'integer)))
          (dolist (arg (combination-args thing) min)
            (if (csubtypep (lvar-type arg) itype)
                (setf min (min min (count-low-order-zeros arg)))
                (return 0)))))
       (*
        (let ((result 0)
              (itype (specifier-type 'integer)))
          (dolist (arg (combination-args thing) result)
            (if (csubtypep (lvar-type arg) itype)
                (setf result (+ result (count-low-order-zeros arg)))
                (return 0)))))
       (ash
        (let ((args (combination-args thing)))
          (if (= (length args) 2)
              (let ((amount (second args)))
                (if (constant-lvar-p amount)
                    (max (+ (count-low-order-zeros (first args))
                            (lvar-value amount))
                         0)
                    0))
              0)))
       (t
        0)))
    (integer
     (if (zerop thing)
         most-positive-fixnum
         (do ((result 0 (1+ result))
              (num thing (ash num -1)))
             ((logbitp 0 num) result))))
    (cast
     (count-low-order-zeros (cast-value thing)))
    (t
     0)))

(deftransform / ((numerator denominator) (integer integer))
  "convert x/2^k to shift"
  (unless (constant-lvar-p denominator)
    (give-up-ir1-transform))
  (let* ((denominator (lvar-value denominator))
         (bits (1- (integer-length denominator))))
    (unless (and (> denominator 0) (= (ash 1 bits) denominator))
      (give-up-ir1-transform))
    (let ((alignment (count-low-order-zeros numerator)))
      (unless (>= alignment bits)
        (give-up-ir1-transform))
      `(ash numerator ,(- bits)))))

(deftransform ash ((value amount))
  (let ((value-node (lvar-uses value)))
    (unless (combination-p value-node)
      (give-up-ir1-transform))
    (let ((inside-fun-name (lvar-fun-name (combination-fun value-node))))
      (multiple-value-bind (prototype width)
          (modular-version-info inside-fun-name :untagged nil)
        (unless (eq (or prototype inside-fun-name) 'ash)
          (give-up-ir1-transform))
        (when (and width (not (constant-lvar-p amount)))
          (give-up-ir1-transform))
        (let ((inside-args (combination-args value-node)))
          (unless (= (length inside-args) 2)
            (give-up-ir1-transform))
          (let ((inside-amount (second inside-args)))
            (unless (and (constant-lvar-p inside-amount)
                         (not (minusp (lvar-value inside-amount))))
              (give-up-ir1-transform)))
          (splice-fun-args value inside-fun-name 2)
          (if width
              `(lambda (value amount1 amount2)
                 (logand (ash value (+ amount1 amount2))
                         ,(1- (ash 1 (+ width (lvar-value amount))))))
              `(lambda (value amount1 amount2)
                 (ash value (+ amount1 amount2)))))))))

;;;; ALIEN-FUNCALL support

(deftransform alien-funcall ((function &rest args)
                             ((alien (* t)) &rest *) *
                             :important t)
  (let ((names (make-gensym-list (length args))))
    (/noshow "entering first DEFTRANSFORM ALIEN-FUNCALL" function args)
    `(lambda (function ,@names)
       (alien-funcall (deref function) ,@names))))

;;; Frame pointer, program counter conses. In each thread it's bound
;;; locally or not bound at all.
(defvar *saved-fp-and-pcs*)

#!+:c-stack-is-control-stack
(declaim (inline invoke-with-saved-fp-and-pc))
#!+:c-stack-is-control-stack
(defun invoke-with-saved-fp-and-pc (fn)
  (declare #-sb-xc-host (muffle-conditions compiler-note)
           (optimize (speed 3)))
  (let* ((fp-and-pc (cons (%caller-frame)
                          (sap-int (%caller-pc)))))
    (declare (truly-dynamic-extent fp-and-pc))
    (let ((*saved-fp-and-pcs* (if (boundp '*saved-fp-and-pcs*)
                                  (cons fp-and-pc *saved-fp-and-pcs*)
                                  (list fp-and-pc))))
      (declare (truly-dynamic-extent *saved-fp-and-pcs*))
      (funcall fn))))

(defun find-saved-fp-and-pc (fp)
  (when (boundp '*saved-fp-and-pcs*)
    (dolist (x *saved-fp-and-pcs*)
      (when (#!+:stack-grows-downward-not-upward
             sap>
             #!-:stack-grows-downward-not-upward
             sap<
             (int-sap (get-lisp-obj-address (car x))) fp)
        (return (values (car x) (cdr x)))))))

(deftransform alien-funcall ((function &rest args) * * :node node :important t)
  (let ((type (lvar-type function)))
    (unless (alien-type-type-p type)
      (give-up-ir1-transform "can't tell function type at compile time"))
    (/noshow "entering second DEFTRANSFORM ALIEN-FUNCALL" function)
    (let ((alien-type (alien-type-type-alien-type type)))
      (unless (alien-fun-type-p alien-type)
        (give-up-ir1-transform))
      (let ((arg-types (alien-fun-type-arg-types alien-type)))
        (unless (= (length args) (length arg-types))
          (abort-ir1-transform
           "wrong number of arguments; expected ~W, got ~W"
           (length arg-types)
           (length args)))
        (collect ((params) (deports))
          (dolist (arg-type arg-types)
            (let ((param (gensym)))
              (params param)
              (deports `(deport ,param ',arg-type))))
          ;; Build BODY from the inside out.
          (let ((return-type (alien-fun-type-result-type alien-type))
                ;; Innermost, we DEPORT the parameters (e.g. by taking SAPs
                ;; to them) and do the call.
                (body `(%alien-funcall (deport function ',alien-type)
                                       ',alien-type
                                       ,@(deports))))
            ;; Wrap that in a WITH-PINNED-OBJECTS to ensure the values
            ;; the SAPs are taken for won't be moved by the GC. (If
            ;; needed: some alien types won't need it).
            (setf body `(maybe-with-pinned-objects ,(params) ,arg-types
                          ,body))
            ;; Around that handle any memory allocation that's needed.
            ;; Mostly the DEPORT-ALLOC alien-type-methods are just an
            ;; identity operation, but for example for deporting a
            ;; Unicode string we need to convert the string into an
            ;; octet array. This step needs to be done before the pinning
            ;; to ensure we pin the right objects, so it can't be combined
            ;; with the deporting.
            ;; -- JES 2006-03-16
            (loop for param in (params)
                  for arg-type in arg-types
                  do (setf body
                           `(let ((,param (deport-alloc ,param ',arg-type)))
                              ,body)))
            (if (alien-values-type-p return-type)
                (collect ((temps) (results))
                  (dolist (type (alien-values-type-values return-type))
                    (let ((temp (gensym)))
                      (temps temp)
                      (results `(naturalize ,temp ',type))))
                  (setf body
                        `(multiple-value-bind ,(temps) ,body
                           (values ,@(results)))))
                (setf body `(naturalize ,body ',return-type)))
            ;; Remember this frame to make sure that we can get back
            ;; to it later regardless of how the foreign stack looks
            ;; like.
            #!+:c-stack-is-control-stack
            (when (policy node (= 3 alien-funcall-saves-fp-and-pc))
              (setf body `(invoke-with-saved-fp-and-pc (lambda () ,body))))
            (/noshow "returning from DEFTRANSFORM ALIEN-FUNCALL" (params) body)
            `(lambda (function ,@(params))
               (declare (optimize (let-conversion 3)))
               ,body)))))))

(defoptimizer (%alien-funcall derive-type) ((function type &rest args))
  (declare (ignore function args))
  (unless (constant-lvar-p type)
    (error "Something is broken."))
  (let ((type (lvar-value type)))
    (unless (alien-fun-type-p type)
      (error "Something is broken."))
    (values-specifier-type
     (compute-alien-rep-type
      (alien-fun-type-result-type type)
      :result))))

(defoptimizer (%alien-funcall ltn-annotate)
              ((function type &rest args) node ltn-policy)
  (setf (basic-combination-info node) :funny)
  (setf (node-tail-p node) nil)
  (annotate-ordinary-lvar function)
  (dolist (arg args)
    (annotate-ordinary-lvar arg)))

;;; We support both the stdcall and cdecl calling conventions on win32 by
;;; resetting ESP after the foreign function returns. This way it works
;;; correctly whether the party that is supposed to pop arguments from
;;; the stack is the caller (cdecl) or the callee (stdcall).
(defoptimizer (%alien-funcall ir2-convert)
              ((function type &rest args) call block)
  (let ((type (if (constant-lvar-p type)
                  (lvar-value type)
                  (error "Something is broken.")))
        (lvar (node-lvar call))
        (args args)
        #!+x86
        (stack-pointer (make-stack-pointer-tn)))
    (multiple-value-bind (nsp stack-frame-size arg-tns result-tns)
        (make-call-out-tns type)
      #!+x86
      (progn
        (vop set-fpu-word-for-c call block)
        (vop current-stack-pointer call block stack-pointer))
      (vop alloc-number-stack-space call block stack-frame-size nsp)
      (dolist (tn arg-tns)
        ;; On PPC, TN might be a list. This is used to indicate
        ;; something special needs to happen. See below.
        ;;
        ;; FIXME: We should implement something better than this.
        (let* ((first-tn (if (listp tn) (car tn) tn))
               (arg (pop args))
               (sc (tn-sc first-tn))
               (scn (sc-number sc))
               #!-(or x86 x86-64) (temp-tn (make-representation-tn
                                            (tn-primitive-type first-tn) scn))
               (move-arg-vops (svref (sc-move-arg-vops sc) scn)))
          (aver arg)
          (unless (= (length move-arg-vops) 1)
            (error "no unique move-arg-vop for moves in SC ~S" (sc-name sc)))
          #!+(or x86 x86-64) (emit-move-arg-template call
                                                     block
                                                     (first move-arg-vops)
                                                     (lvar-tn call block arg)
                                                     nsp
                                                     first-tn)
          #!-(or x86 x86-64) (progn
                               (emit-move call
                                          block
                                          (lvar-tn call block arg)
                                          temp-tn)
                               (emit-move-arg-template call
                                                       block
                                                       (first move-arg-vops)
                                                       temp-tn
                                                       nsp
                                                       first-tn))
          #!+(and ppc darwin)
          (when (listp tn)
            ;; This means that we have a float arg that we need to
            ;; also copy to some int regs. The list contains the TN
            ;; for the float as well as the TNs to use for the int
            ;; arg.
            (destructuring-bind (float-tn i1-tn &optional i2-tn)
                tn
              (if i2-tn
                  (vop sb!vm::move-double-to-int-arg call block
                       float-tn i1-tn i2-tn)
                  (vop sb!vm::move-single-to-int-arg call block
                       float-tn i1-tn))))))
      (aver (null args))
      (unless (listp result-tns)
        (setf result-tns (list result-tns)))
      (let ((arg-tns (flatten-list arg-tns)))
        (vop* call-out call block
              ((lvar-tn call block function)
               (reference-tn-list arg-tns nil))
              ((reference-tn-list result-tns t))))
      #!-x86
      (vop dealloc-number-stack-space call block stack-frame-size)
      #!+x86
      (progn
        (vop reset-stack-pointer call block stack-pointer)
        (vop set-fpu-word-for-lisp call block))
      (move-lvar-result call block result-tns lvar))))
