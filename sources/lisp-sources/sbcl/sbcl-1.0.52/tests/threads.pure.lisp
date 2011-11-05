;;;; miscellaneous tests of thread stuff

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; While most of SBCL is derived from the CMU CL system, the test
;;;; files (like this one) were written from scratch after the fork
;;;; from CMU CL.
;;;
;;;; This software is in the public domain and is provided with
;;;; absoluely no warranty. See the COPYING and CREDITS files for
;;;; more information.

(in-package :cl-user)

(defpackage :thread-test
  (:use :cl :sb-thread))

(in-package :thread-test)

(use-package :test-util)

(with-test (:name mutex-owner)
  ;; Make sure basics are sane on unithreaded ports as well
  (let ((mutex (make-mutex)))
    (get-mutex mutex)
    (assert (eq *current-thread* (mutex-value mutex)))
    (handler-bind ((warning #'error))
      (release-mutex mutex))
    (assert (not (mutex-value mutex)))))

(with-test (:name spinlock-owner)
  ;; Make sure basics are sane on unithreaded ports as well
  (let ((spinlock (sb-thread::make-spinlock)))
    (sb-thread::get-spinlock spinlock)
    (assert (eq *current-thread* (sb-thread::spinlock-value spinlock)))
    (handler-bind ((warning #'error))
      (sb-thread::release-spinlock spinlock))
    (assert (not (sb-thread::spinlock-value spinlock)))))

;;; Terminating a thread that's waiting for the terminal.

#+sb-thread
(let ((thread (make-thread (lambda ()
                             (sb-thread::get-foreground)))))
  (sleep 1)
  (assert (thread-alive-p thread))
  (terminate-thread thread)
  (sleep 1)
  (assert (not (thread-alive-p thread))))

;;; Condition-wait should not be interruptible under WITHOUT-INTERRUPTS

(with-test (:name without-interrupts+condition-wait
            :fails-on :sb-lutex
            :skipped-on '(not :sb-thread))
  (let* ((lock (make-mutex))
         (queue (make-waitqueue))
         (thread (make-thread (lambda ()
                                (sb-sys:without-interrupts
                                  (with-mutex (lock)
                                    (condition-wait queue lock)))))))
    (sleep 1)
    (assert (thread-alive-p thread))
    (terminate-thread thread)
    (sleep 1)
    (assert (thread-alive-p thread))
    (condition-notify queue)
    (sleep 1)
    (assert (not (thread-alive-p thread)))))

;;; GET-MUTEX should not be interruptible under WITHOUT-INTERRUPTS

(with-test (:name without-interrupts+get-mutex :skipped-on '(not :sb-thread))
  (let* ((lock (make-mutex))
         (bar (progn (get-mutex lock) nil))
         (thread (make-thread (lambda ()
                                (sb-sys:without-interrupts
                                    (with-mutex (lock)
                                      (setf bar t)))))))
    (sleep 1)
    (assert (thread-alive-p thread))
    (terminate-thread thread)
    (sleep 1)
    (assert (thread-alive-p thread))
    (release-mutex lock)
    (sleep 1)
    (assert (not (thread-alive-p thread)))
    (assert (eq :aborted (join-thread thread :default :aborted)))
    (assert bar)))

(with-test (:name parallel-find-class :skipped-on '(not :sb-thread))
  (let* ((oops nil)
         (threads (loop repeat 10
                        collect (make-thread (lambda ()
                                               (handler-case
                                                   (loop repeat 10000
                                                         do (find-class (gensym) nil))
                                                 (serious-condition ()
                                                   (setf oops t))))))))
    (mapcar #'sb-thread:join-thread threads)
    (assert (not oops))))

(with-test (:name :semaphore-multiple-waiters :skipped-on '(not :sb-thread))
  (let ((semaphore (make-semaphore :name "test sem")))
    (labels ((make-readers (n i)
               (values
                (loop for r from 0 below n
                      collect
                      (sb-thread:make-thread
                       (lambda ()
                         (let ((sem semaphore))
                           (dotimes (s i)
                             (sb-thread:wait-on-semaphore sem))))
                       :name "reader"))
                (* n i)))
             (make-writers (n readers i)
               (let ((j (* readers i)))
                 (multiple-value-bind (k rem) (truncate j n)
                   (values
                    (let ((writers
                           (loop for w from 0 below n
                                 collect
                                 (sb-thread:make-thread
                                  (lambda ()
                                    (let ((sem semaphore))
                                      (dotimes (s k)
                                        (sb-thread:signal-semaphore sem))))
                                  :name "writer"))))
                      (assert (zerop rem))
                      writers)
                    (+ rem (* n k))))))
             (test (r w n)
               (multiple-value-bind (readers x) (make-readers r n)
                 (assert (= (length readers) r))
                 (multiple-value-bind (writers y) (make-writers w r n)
                   (assert (= (length writers) w))
                   (assert (= x y))
                   (mapc #'sb-thread:join-thread writers)
                   (mapc #'sb-thread:join-thread readers)
                   (assert (zerop (sb-thread:semaphore-count semaphore)))
                   (values)))))
      (assert
       (eq :ok
           (handler-case
               (sb-ext:with-timeout 10
                 (test 1 1 100)
                 (test 2 2 10000)
                 (test 4 2 10000)
                 (test 4 2 10000)
                 (test 10 10 10000)
                 (test 10 1 10000)
                 :ok)
             (sb-ext:timeout ()
               :timeout)))))))

;;;; Printing waitqueues

(with-test (:name :waitqueue-circle-print :skipped-on '(not :sb-thread))
  (let* ((*print-circle* nil)
         (lock (sb-thread:make-mutex))
         (wq (sb-thread:make-waitqueue)))
    (sb-thread:with-recursive-lock (lock)
      (sb-thread:condition-notify wq))
    ;; Used to blow stack due to recursive structure.
    (assert (princ-to-string wq))))

;;;; SYMBOL-VALUE-IN-THREAD

(with-test (:name symbol-value-in-thread.1)
  (let ((* (cons t t)))
    (assert (eq * (symbol-value-in-thread '* *current-thread*)))
    (setf (symbol-value-in-thread '* *current-thread*) 123)
    (assert (= 123 (symbol-value-in-thread '* *current-thread*)))
    (assert (= 123 *))))

(with-test (:name symbol-value-in-thread.2 :skipped-on '(not :sb-thread))
  (let* ((parent *current-thread*)
         (semaphore (make-semaphore))
         (child (make-thread (lambda ()
                               (wait-on-semaphore semaphore)
                               (let ((old (symbol-value-in-thread 'this-is-new parent)))
                                 (setf (symbol-value-in-thread 'this-is-new parent) :from-child)
                                 old)))))
    (progv '(this-is-new) '(42)
      (signal-semaphore semaphore)
      (assert (= 42 (join-thread child)))
      (assert (eq :from-child (symbol-value 'this-is-new))))))

;;; Disabled on Darwin due to deadlocks caused by apparent OS specific deadlocks,
;;; wich _appear_ to be caused by malloc() and free() not being thread safe: an
;;; interrupted malloc in one thread can apparently block a free in another. There
;;; are also some indications that pthread_mutex_lock is not re-entrant.
(with-test (:name symbol-value-in-thread.3 :skipped-on '(not :sb-thread) :broken-on :darwin)
  (let* ((parent *current-thread*)
         (semaphore (make-semaphore))
         (running t)
         (noise (make-thread (lambda ()
                               (loop while running
                                     do (setf * (make-array 1024))
                                     ;; Busy-wait a bit so we don't TOTALLY flood the
                                     ;; system with GCs: a GC occurring in the middle of
                                     ;; S-V-I-T causes it to start over -- we want that
                                     ;; to occur occasionally, but not _all_ the time.
                                        (loop repeat (random 128)
                                              do (setf ** *)))))))
    (write-string "; ")
    (dotimes (i 15000)
      (when (zerop (mod i 200))
        (write-char #\.)
        (force-output))
      (let* ((mom-mark (cons t t))
             (kid-mark (cons t t))
             (child (make-thread (lambda ()
                                   (wait-on-semaphore semaphore)
                                   (let ((old (symbol-value-in-thread 'this-is-new parent)))
                                     (setf (symbol-value-in-thread 'this-is-new parent)
                                           (make-array 24 :initial-element kid-mark))
                                     old)))))
        (progv '(this-is-new) (list (make-array 24 :initial-element mom-mark))
          (signal-semaphore semaphore)
          (assert (eq mom-mark (aref (join-thread child) 0)))
          (assert (eq kid-mark (aref (symbol-value 'this-is-new) 0))))))
    (setf running nil)
    (join-thread noise)))

(with-test (:name symbol-value-in-thread.4 :skipped-on '(not :sb-thread))
  (let* ((parent *current-thread*)
         (semaphore (make-semaphore))
         (child (make-thread (lambda ()
                               (wait-on-semaphore semaphore)
                               (symbol-value-in-thread 'this-is-new parent nil)))))
    (signal-semaphore semaphore)
    (assert (equal '(nil nil) (multiple-value-list (join-thread child))))))

(with-test (:name symbol-value-in-thread.5 :skipped-on '(not :sb-thread))
  (let* ((parent *current-thread*)
         (semaphore (make-semaphore))
         (child (make-thread (lambda ()
                               (wait-on-semaphore semaphore)
                               (handler-case
                                   (symbol-value-in-thread 'this-is-new parent)
                                 (symbol-value-in-thread-error (e)
                                   (list (thread-error-thread e)
                                         (cell-error-name e)
                                         (sb-thread::symbol-value-in-thread-error-info e))))))))
    (signal-semaphore semaphore)
    (assert (equal (list *current-thread* 'this-is-new (list :read :unbound-in-thread))
                   (join-thread child)))))

(with-test (:name symbol-value-in-thread.6 :skipped-on '(not :sb-thread))
  (let* ((parent *current-thread*)
         (semaphore (make-semaphore))
         (name (gensym))
         (child (make-thread (lambda ()
                               (wait-on-semaphore semaphore)
                               (handler-case
                                   (setf (symbol-value-in-thread name parent) t)
                                 (symbol-value-in-thread-error (e)
                                   (list (thread-error-thread e)
                                         (cell-error-name e)
                                         (sb-thread::symbol-value-in-thread-error-info e))))))))
    (signal-semaphore semaphore)
    (let ((res (join-thread child))
          (want (list *current-thread* name (list :write :no-tls-value))))
      (unless (equal res want)
        (error "wanted ~S, got ~S" want res)))))

(with-test (:name symbol-value-in-thread.7 :skipped-on '(not :sb-thread))
  (let ((child (make-thread (lambda ())))
        (error-occurred nil))
    (join-thread child)
    (handler-case
        (symbol-value-in-thread 'this-is-new child)
      (symbol-value-in-thread-error (e)
        (setf error-occurred t)
        (assert (eq child (thread-error-thread e)))
        (assert (eq 'this-is-new (cell-error-name e)))
        (assert (equal (list :read :thread-dead)
                       (sb-thread::symbol-value-in-thread-error-info e)))))
    (assert error-occurred)))

(with-test (:name symbol-value-in-thread.8  :skipped-on '(not :sb-thread))
  (let ((child (make-thread (lambda ())))
        (error-occurred nil))
    (join-thread child)
    (handler-case
        (setf (symbol-value-in-thread 'this-is-new child) t)
      (symbol-value-in-thread-error (e)
        (setf error-occurred t)
        (assert (eq child (thread-error-thread e)))
        (assert (eq 'this-is-new (cell-error-name e)))
        (assert (equal (list :write :thread-dead)
                       (sb-thread::symbol-value-in-thread-error-info e)))))
    (assert error-occurred)))

(with-test (:name deadlock-detection.1  :skipped-on '(not :sb-thread))
  (loop
    repeat 1000
    do (flet ((test (ma mb sa sb)
                (lambda ()
                  (handler-case
                      (sb-thread:with-mutex (ma)
                        (sb-thread:signal-semaphore sa)
                        (sb-thread:wait-on-semaphore sb)
                        (sb-thread:with-mutex (mb)
                          :ok))
                    (sb-thread:thread-deadlock (e)
                      (princ e)
                      :deadlock)))))
         (let* ((m1 (sb-thread:make-mutex :name "M1"))
                (m2 (sb-thread:make-mutex :name "M2"))
                (s1 (sb-thread:make-semaphore :name "S1"))
                (s2 (sb-thread:make-semaphore :name "S2"))
                (t1 (sb-thread:make-thread (test m1 m2 s1 s2) :name "T1"))
                (t2 (sb-thread:make-thread (test m2 m1 s2 s1) :name "T2")))
           ;; One will deadlock, and the other will then complete normally.
           ;; ...except sometimes, when we get unlucky, and both will do
           ;; the deadlock detection in parallel and both signal.
           (let ((res (list (sb-thread:join-thread t1)
                            (sb-thread:join-thread t2))))
             (assert (or (equal '(:deadlock :ok) res)
                         (equal '(:ok :deadlock) res)
                         (equal '(:deadlock :deadlock) res))))))))

(with-test (:name deadlock-detection.2 :skipped-on '(not :sb-thread))
  (let* ((m1 (sb-thread:make-mutex :name "M1"))
         (m2 (sb-thread:make-mutex :name "M2"))
         (s1 (sb-thread:make-semaphore :name "S1"))
         (s2 (sb-thread:make-semaphore :name "S2"))
         (t1 (sb-thread:make-thread
              (lambda ()
                (sb-thread:with-mutex (m1)
                  (sb-thread:signal-semaphore s1)
                  (sb-thread:wait-on-semaphore s2)
                  (sb-thread:with-mutex (m2)
                    :ok)))
              :name "T1")))
    (prog (err)
     :retry
       (handler-bind ((sb-thread:thread-deadlock
                       (lambda (e)
                         (unless err
                           ;; Make sure we can print the condition
                           ;; while it's active
                           (let ((*print-circle* nil))
                             (setf err (princ-to-string e)))
                           (go :retry)))))
         (when err
           (sleep 1))
         (assert (eq :ok (sb-thread:with-mutex (m2)
                           (unless err
                             (sb-thread:signal-semaphore s2)
                             (sb-thread:wait-on-semaphore s1)
                             (sleep 1))
                           (sb-thread:with-mutex (m1)
                             :ok)))))
       (assert (stringp err)))
    (assert (eq :ok (sb-thread:join-thread t1)))))

(with-test (:name deadlock-detection.3  :skipped-on '(not :sb-thread))
  (let* ((m1 (sb-thread:make-mutex :name "M1"))
         (m2 (sb-thread:make-mutex :name "M2"))
         (s1 (sb-thread:make-semaphore :name "S1"))
         (s2 (sb-thread:make-semaphore :name "S2"))
         (t1 (sb-thread:make-thread
              (lambda ()
                (sb-thread:with-mutex (m1)
                  (sb-thread:signal-semaphore s1)
                  (sb-thread:wait-on-semaphore s2)
                  (sb-thread:with-mutex (m2)
                    :ok)))
              :name "T1")))
    ;; Currently we don't consider it a deadlock
    ;; if there is a timeout in the chain. No
    ;; Timeouts on lutex builds, though.
    (assert (eq #-sb-lutex :deadline
                #+sb-lutex :deadlock
                (handler-case
                    (sb-thread:with-mutex (m2)
                      (sb-thread:signal-semaphore s2)
                      (sb-thread:wait-on-semaphore s1)
                      (sleep 1)
                      (sb-sys:with-deadline (:seconds 0.1)
                        (sb-thread:with-mutex (m1)
                          :ok)))
                  (sb-sys:deadline-timeout ()
                    :deadline)
                  (sb-thread:thread-deadlock ()
                    :deadlock))))
    (assert (eq :ok (join-thread t1)))))

(with-test (:name deadlock-detection.4  :skipped-on '(not :sb-thread))
  (loop
    repeat 1000
    do (flet ((test (ma mb sa sb)
                (lambda ()
                  (handler-case
                      (sb-thread::with-spinlock (ma)
                        (sb-thread:signal-semaphore sa)
                        (sb-thread:wait-on-semaphore sb)
                        (sb-thread::with-spinlock (mb)
                          :ok))
                    (sb-thread:thread-deadlock (e)
                      (princ e)
                      :deadlock)))))
         (let* ((m1 (sb-thread::make-spinlock :name "M1"))
                (m2 (sb-thread::make-spinlock :name "M2"))
                (s1 (sb-thread:make-semaphore :name "S1"))
                (s2 (sb-thread:make-semaphore :name "S2"))
                (t1 (sb-thread:make-thread (test m1 m2 s1 s2) :name "T1"))
                (t2 (sb-thread:make-thread (test m2 m1 s2 s1) :name "T2")))
           ;; One will deadlock, and the other will then complete normally
           ;; ...except sometimes, when we get unlucky, and both will do
           ;; the deadlock detection in parallel and both signal.
           (let ((res (list (sb-thread:join-thread t1)
                            (sb-thread:join-thread t2))))
             (assert (or (equal '(:deadlock :ok) res)
                         (equal '(:ok :deadlock) res)
                         (equal '(:deadlock :deadlock) res))))))))

(with-test (:name deadlock-detection.5 :skipped-on '(not :sb-thread))
  (let* ((m1 (sb-thread::make-spinlock :name "M1"))
         (m2 (sb-thread::make-spinlock :name "M2"))
         (s1 (sb-thread:make-semaphore :name "S1"))
         (s2 (sb-thread:make-semaphore :name "S2"))
         (t1 (sb-thread:make-thread
              (lambda ()
                (sb-thread::with-spinlock (m1)
                  (sb-thread:signal-semaphore s1)
                  (sb-thread:wait-on-semaphore s2)
                  (sb-thread::with-spinlock (m2)
                    :ok)))
              :name "T1")))
    (prog (err)
     :retry
       (handler-bind ((sb-thread:thread-deadlock
                       (lambda (e)
                         (unless err
                           ;; Make sure we can print the condition
                           ;; while it's active
                           (let ((*print-circle* nil))
                             (setf err (princ-to-string e)))
                           (go :retry)))))
         (when err
           (sleep 1))
         (assert (eq :ok (sb-thread::with-spinlock (m2)
                           (unless err
                             (sb-thread:signal-semaphore s2)
                             (sb-thread:wait-on-semaphore s1)
                             (sleep 1))
                           (sb-thread::with-spinlock (m1)
                             :ok)))))
       (assert (stringp err)))
    (assert (eq :ok (sb-thread:join-thread t1)))))

(with-test (:name deadlock-detection.7 :skipped-on '(not :sb-thread))
  (let* ((m1 (sb-thread::make-spinlock :name "M1"))
         (m2 (sb-thread::make-spinlock :name "M2"))
         (s1 (sb-thread:make-semaphore :name "S1"))
         (s2 (sb-thread:make-semaphore :name "S2"))
         (t1 (sb-thread:make-thread
              (lambda ()
                (sb-thread::with-spinlock (m1)
                  (sb-thread:signal-semaphore s1)
                  (sb-thread:wait-on-semaphore s2)
                  (sb-thread::with-spinlock (m2)
                    :ok)))
              :name "T1")))
    (assert (eq :deadlock
                (handler-case
                    (sb-thread::with-spinlock (m2)
                      (sb-thread:signal-semaphore s2)
                      (sb-thread:wait-on-semaphore s1)
                      (sleep 1)
                      (sb-sys:with-deadline (:seconds 0.1)
                        (sb-thread::with-spinlock (m1)
                          :ok)))
                  (sb-sys:deadline-timeout ()
                    :deadline)
                  (sb-thread:thread-deadlock ()
                    :deadlock))))
    (assert (eq :ok (join-thread t1)))))

#+sb-thread
(with-test (:name :pass-arguments-to-thread)
  (assert (= 3 (join-thread (make-thread #'+ :arguments '(1 2))))))

#+sb-thread
(with-test (:name :pass-atom-to-thread)
  (assert (= 1/2 (join-thread (make-thread #'/ :arguments 2)))))

#+sb-thread
(with-test (:name :pass-nil-to-thread)
  (assert (= 1 (join-thread (make-thread #'* :arguments '())))))

#+sb-thread
(with-test (:name :pass-nothing-to-thread)
  (assert (= 1 (join-thread (make-thread #'*)))))

#+sb-thread
(with-test (:name :pass-improper-list-to-thread)
  (multiple-value-bind (value error)
      (ignore-errors (make-thread #'+ :arguments '(1 . 1)))
    (when value
      (join-thread value))
    (assert (and (null value)
                 error))))
