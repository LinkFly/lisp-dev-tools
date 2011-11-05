;;;; miscellaneous side-effectful tests of the MOP

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; While most of SBCL is derived from the CMU CL system, the test
;;;; files (like this one) were written from scratch after the fork
;;;; from CMU CL.
;;;;
;;;; This software is in the public domain and is provided with
;;;; absolutely no warranty. See the COPYING and CREDITS files for
;;;; more information.

;;;; Note that the MOP is not in an entirely supported state.
;;;; However, this seems a good a way as any of ensuring that we have
;;;; no regressions.

;;; This is basically the DYNAMIC-SLOT-CLASS example from AMOP, with
;;; fixups for running in the full MOP rather than closette -- SLOTDs
;;; instead of slot-names, and so on -- and :allocation :dynamic for
;;; dynamic slots.

(untrace)

(defpackage "TEST" (:use "CL" "SB-MOP"))
(in-package "TEST")

(defclass dynamic-slot-class (standard-class) ())

(defmethod validate-superclass
    ((class dynamic-slot-class) (super standard-class))
  t)

(defun dynamic-slot-p (slot)
  (eq (slot-definition-allocation slot) :dynamic))

(let ((table (make-hash-table)))

   (defun allocate-table-entry (instance)
     (setf (gethash instance table) ()))

   (defun read-dynamic-slot-value (instance slot-name)
     (let* ((alist (gethash instance table))
            (entry (assoc slot-name alist)))
        (if (null entry)
            (error "slot ~S unbound in ~S" slot-name instance)
            (cdr entry))))

   (defun write-dynamic-slot-value (new-value instance slot-name)
      (let* ((alist (gethash instance table))
             (entry (assoc slot-name alist)))
         (if (null entry)
             (push `(,slot-name . ,new-value)
                   (gethash instance table))
             (setf (cdr entry) new-value))
         new-value))

  (defun dynamic-slot-names (instance)
    (mapcar #'car (gethash instance table)))

   (defun dynamic-slot-boundp (instance slot-name)
      (let* ((alist (gethash instance table))
             (entry (assoc slot-name alist)))
        (not (null entry))))

   (defun dynamic-slot-makunbound (instance slot-name)
      (let* ((alist (gethash instance table))
             (entry (assoc slot-name alist)))
        (unless (null entry)
          (setf (gethash instance table) (delete entry alist))))
      instance)
)

(defmethod allocate-instance ((class dynamic-slot-class) &key)
  (let ((instance (call-next-method)))
    (allocate-table-entry instance)
    instance))

(defmethod slot-value-using-class ((class dynamic-slot-class)
                                   instance slotd)
  (let ((slot (find slotd (class-slots class))))
    (if (and slot (dynamic-slot-p slot))
        (read-dynamic-slot-value instance (slot-definition-name slotd))
        (call-next-method))))

(defmethod (setf slot-value-using-class) (new-value (class dynamic-slot-class)
                                          instance slotd)
  (let ((slot (find slotd (class-slots class))))
    (if (and slot (dynamic-slot-p slot))
        (write-dynamic-slot-value new-value instance (slot-definition-name slotd))
        (call-next-method))))

(defmethod slot-boundp-using-class ((class dynamic-slot-class)
                                    instance slotd)
  (let ((slot (find slotd (class-slots class))))
    (if (and slot (dynamic-slot-p slot))
        (dynamic-slot-boundp instance (slot-definition-name slotd))
        (call-next-method))))

(defmethod slot-makunbound-using-class ((class dynamic-slot-class)
                                        instance slotd)
  (let ((slot (find slotd (class-slots class))))
    (if (and slot (dynamic-slot-p slot))
        (dynamic-slot-makunbound instance (slot-definition-name slotd))
        (call-next-method))))

(defclass test-class-1 ()
  ((slot1 :initarg :slot1 :allocation :dynamic)
   (slot2 :initarg :slot2 :initform nil))
  (:metaclass dynamic-slot-class))

(defclass test-class-2 (test-class-1)
  ((slot2 :initarg :slot2 :initform t :allocation :dynamic)
   (slot3 :initarg :slot3))
  (:metaclass dynamic-slot-class))

(defvar *one* (make-instance 'test-class-1))
(defvar *two* (make-instance 'test-class-2 :slot3 1))

(assert (not (slot-boundp *one* 'slot1)))
(assert (null (slot-value *one* 'slot2)))
(assert (eq t (slot-value *two* 'slot2)))
(assert (= 1 (slot-value *two* 'slot3)))

;;; breakage observed by R. Mattes sbcl-help 2004-09-16, caused by
;;; overconservatism in accessing a class's precedence list deep in
;;; the bowels of COMPUTE-APPLICABLE-METHODS, during the process of
;;; finalizing a class.
(defclass dynamic-slot-subclass (dynamic-slot-class) ())

(defmethod slot-value-using-class ((class dynamic-slot-subclass)
                                   instance slotd)
  (let ((slot (find slotd (class-slots class))))
    (if (and slot (dynamic-slot-p slot))
        (read-dynamic-slot-value instance (slot-definition-name slotd))
        (call-next-method))))

(defmethod (setf slot-value-using-class) (new-value
                                          (class dynamic-slot-subclass)
                                          instance slotd)
  (let ((slot (find slotd (class-slots class))))
    (if (and slot (dynamic-slot-p slot))
        (write-dynamic-slot-value new-value instance (slot-definition-name slotd))
        (call-next-method))))

(defmethod slot-boundp-using-class ((class dynamic-slot-subclass)
                                    instance slotd)
  (let ((slot (find slotd (class-slots class))))
    (if (and slot (dynamic-slot-p slot))
        (dynamic-slot-boundp instance (slot-definition-name slotd))
        (call-next-method))))

(defclass test-class-3 (test-class-1)
  ((slot2 :initarg :slot2 :initform t :allocation :dynamic)
   (slot3 :initarg :slot3))
  (:metaclass dynamic-slot-subclass))

(defvar *three* (make-instance 'test-class-3 :slot3 3))
(assert (not (slot-boundp *three* 'slot1)))
(assert (eq (slot-value *three* 'slot2) t))
(assert (= (slot-value *three* 'slot3) 3))

(defmethod slot-missing ((class dynamic-slot-class) instance slot-name operation &optional v)
  (declare (ignore v))
  (list :slot-missing slot-name))

;;; Test redefinition adding a dynamic slot
(defclass test-class-3 (test-class-1)
  ((slot2 :initarg :slot2 :initform t :allocation :dynamic)
   (slot3 :initarg :slot3)
   (slot4 :initarg :slot4 :initform 42 :allocation :dynamic))
  (:metaclass dynamic-slot-subclass))
(assert (= 42 (slot-value *three* 'slot4)))

;;; Test redefinition removing a dynamic slot
(defclass test-class-3 (test-class-1)
  ((slot2 :initarg :slot2 :initform t :allocation :dynamic)
   (slot3 :initarg :slot3))
  (:metaclass dynamic-slot-subclass))
(assert (equal (list :slot-missing 'slot4) (slot-value *three* 'slot4)))

;;; Test redefinition making a dynamic slot local
;;;
;;; NOTE: seriously underspecified. We muddle somehow.
(defclass test-class-3 (test-class-1)
  ((slot2 :initarg :slot2 :initform 'ok :allocation :instance)
   (slot3 :initarg :slot3))
  (:metaclass dynamic-slot-subclass))
(let* ((slots (class-slots (find-class 'test-class-3)))
       (slot (find 'slot2 slots :key #'slot-definition-name)))
  (assert (eq :instance (slot-definition-allocation slot)))
  (assert (eq 'ok (slot-value *three* 'slot2))))

;;; Test redefinition making a local slot dynamic again
;;;
;;; NOTE: seriously underspecified. We muddle somehow.
;;; This picks up the old value from the table, not the
;;; new initform.
(defclass test-class-3 (test-class-1)
  ((slot2 :initarg :slot2 :initform 'ok? :allocation :dynamic)
   (slot3 :initarg :slot3))
  (:metaclass dynamic-slot-subclass))
(let* ((slots (class-slots (find-class 'test-class-3)))
       (slot (find 'slot2 slots :key #'slot-definition-name)))
  (assert (eq :dynamic (slot-definition-allocation slot)))
  (assert (eq t (slot-value *three* 'slot2))))

;;; Test redefinition making a dynamic slot local, with
;;; UPDATE-INSTANCE-FOR-REDEFINED-CLASS unbinding the dynamic slot.
;;; Then we make it dynamic again.
;;;
;;; NOTE: seriously underspecified. We muddle somehow.
(defmethod update-instance-for-redefined-class :after ((obj test-class-3) add drop plist
                                                       &rest inits)
  (declare (ignore inits))
  (let* ((class (class-of obj))
         (slots (class-slots class)))
    (dolist (name (dynamic-slot-names obj))
      (let ((slotd (find name slots :key #'slot-definition-name)))
        (unless (and slotd (eq :dynamic (slot-definition-allocation slotd)))
          (dynamic-slot-makunbound obj name))))))
(defclass test-class-3 (test-class-1)
  ((slot2 :initarg :slot2 :initform 'ok :allocation :instance)
   (slot3 :initarg :slot3))
  (:metaclass dynamic-slot-subclass))
(let* ((slots (class-slots (find-class 'test-class-3)))
       (slot (find 'slot2 slots :key #'slot-definition-name)))
  (assert (eq :instance (slot-definition-allocation slot)))
  (assert (eq 'ok (slot-value *three* 'slot2))))
(defclass test-class-3 (test-class-1)
  ((slot2 :initarg :slot2 :initform 'ok! :allocation :dynamic)
   (slot3 :initarg :slot3))
  (:metaclass dynamic-slot-subclass))
(let* ((slots (class-slots (find-class 'test-class-3)))
       (slot (find 'slot2 slots :key #'slot-definition-name)))
  (assert (eq :dynamic (slot-definition-allocation slot)))
  (assert (eq 'ok! (slot-value *three* 'slot2))))
