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

; WHITE-BOX TESTS

(in-package "SB-THREAD")
(use-package :test-util)
(use-package "ASSERTOID")

(setf sb-unix::*on-dangerous-wait* :error)

(defun wait-for-threads (threads)
  (mapc (lambda (thread) (sb-thread:join-thread thread :default nil)) threads)
  (assert (not (some #'sb-thread:thread-alive-p threads))))

(with-test (:name (:threads :trivia))
  (assert (eql 1 (length (list-all-threads))))

  (assert (eq *current-thread*
              (find (thread-name *current-thread*) (list-all-threads)
                    :key #'thread-name :test #'equal)))

  (assert (thread-alive-p *current-thread*)))

(with-test (:name (:with-mutex :basics))
  (let ((mutex (make-mutex)))
    (with-mutex (mutex)
      mutex)))

(with-test (:name (:with-spinlock :basics))
  (let ((spinlock (make-spinlock)))
    (with-spinlock (spinlock))))

(sb-alien:define-alien-routine "check_deferrables_blocked_or_lose"
    void
  (where sb-alien:unsigned-long))
(sb-alien:define-alien-routine "check_deferrables_unblocked_or_lose"
    void
  (where sb-alien:unsigned-long))

(with-test (:name (:interrupt-thread :basics :no-unwinding))
  (let ((a 0))
    (interrupt-thread *current-thread* (lambda () (setq a 1)))
    (assert (eql a 1))))

(with-test (:name (:interrupt-thread :deferrables-blocked))
  (sb-thread:interrupt-thread sb-thread:*current-thread*
                              (lambda ()
                                (check-deferrables-blocked-or-lose 0))))

(with-test (:name (:interrupt-thread :deferrables-unblocked))
  (sb-thread:interrupt-thread sb-thread:*current-thread*
                              (lambda ()
                                (with-interrupts
                                  (check-deferrables-unblocked-or-lose 0)))))

(with-test (:name (:interrupt-thread :nlx))
  (catch 'xxx
    (sb-thread:interrupt-thread sb-thread:*current-thread*
                                (lambda ()
                                  (check-deferrables-blocked-or-lose 0)
                                  (throw 'xxx nil))))
  (check-deferrables-unblocked-or-lose 0))

#-sb-thread (sb-ext:quit :unix-status 104)

;;;; Now the real tests...

(with-test (:name (:interrupt-thread :deferrables-unblocked-by-spinlock))
  (let ((spinlock (sb-thread::make-spinlock))
        (thread (sb-thread:make-thread (lambda ()
                                         (loop (sleep 1))))))
    (sb-thread::get-spinlock spinlock)
    (sb-thread:interrupt-thread thread
                                (lambda ()
                                  (check-deferrables-blocked-or-lose 0)
                                  (sb-thread::get-spinlock spinlock)
                                  (check-deferrables-unblocked-or-lose 0)
                                  (sb-ext:quit)))
    (sleep 1)
    (sb-thread::release-spinlock spinlock)))

;;; compare-and-swap

(defmacro defincf (name accessor &rest args)
  `(defun ,name (x)
     (let* ((old (,accessor x ,@args))
         (new (1+ old)))
    (loop until (eq old (sb-ext:compare-and-swap (,accessor x ,@args) old new))
       do (setf old (,accessor x ,@args)
                new (1+ old)))
    new)))

(defstruct cas-struct (slot 0))

(defincf incf-car car)
(defincf incf-cdr cdr)
(defincf incf-slot cas-struct-slot)
(defincf incf-symbol-value symbol-value)
(defincf incf-svref/1 svref 1)
(defincf incf-svref/0 svref 0)

(defmacro def-test-cas (name init incf op)
  `(with-test (:name ,name)
     (flet ((,name (n)
              (declare (fixnum n))
              (let* ((x ,init)
                     (run nil)
                     (threads
                      (loop repeat 10
                            collect (sb-thread:make-thread
                                     (lambda ()
                                       (loop until run
                                             do (sb-thread:thread-yield))
                                       (loop repeat n do (,incf x)))))))
                (setf run t)
                (dolist (th threads)
                  (sb-thread:join-thread th))
                (assert (= (,op x) (* 10 n))))))
       (,name 200000))))

(def-test-cas test-cas-car (cons 0 nil) incf-car car)
(def-test-cas test-cas-cdr (cons nil 0) incf-cdr cdr)
(def-test-cas test-cas-slot (make-cas-struct) incf-slot cas-struct-slot)
(def-test-cas test-cas-value (let ((x '.x.))
                               (set x 0)
                               x)
  incf-symbol-value symbol-value)
(def-test-cas test-cas-svref/0 (vector 0 nil) incf-svref/0 (lambda (x)
                                                             (svref x 0)))
(def-test-cas test-cas-svref/1 (vector nil 0) incf-svref/1 (lambda (x)
                                                             (svref x 1)))
(format t "~&compare-and-swap tests done~%")

(with-test (:name (:threads :more-trivia)))
(let ((old-threads (list-all-threads))
      (thread (make-thread (lambda ()
                             (assert (find *current-thread* *all-threads*))
                             (sleep 2))))
      (new-threads (list-all-threads)))
  (assert (thread-alive-p thread))
  (assert (eq thread (first new-threads)))
  (assert (= (1+ (length old-threads)) (length new-threads)))
  (sleep 3)
  (assert (not (thread-alive-p thread))))

(with-test (:name (:join-thread :nlx :default))
  (let ((sym (gensym)))
    (assert (eq sym (join-thread (make-thread (lambda () (sb-ext:quit)))
                                 :default sym)))))

(with-test (:name (:join-thread :nlx :error))
  (raises-error? (join-thread (make-thread (lambda () (sb-ext:quit))))
                 join-thread-error))

(with-test (:name (:join-thread :multiple-values))
  (assert (equal '(1 2 3)
                 (multiple-value-list
                  (join-thread (make-thread (lambda () (values 1 2 3))))))))

;;; We had appalling scaling properties for a while.  Make sure they
;;; don't reappear.
(defun scaling-test (function &optional (nthreads 5))
  "Execute FUNCTION with NTHREADS lurking to slow it down."
  (let ((queue (sb-thread:make-waitqueue))
        (mutex (sb-thread:make-mutex)))
    ;; Start NTHREADS idle threads.
    (dotimes (i nthreads)
      (sb-thread:make-thread (lambda ()
                               (with-mutex (mutex)
                                 (sb-thread:condition-wait queue mutex))
                               (sb-ext:quit))))
    (let ((start-time (get-internal-run-time)))
      (funcall function)
      (prog1 (- (get-internal-run-time) start-time)
        (sb-thread:condition-broadcast queue)))))
(defun fact (n)
  "A function that does work with the CPU."
  (if (zerop n) 1 (* n (fact (1- n)))))
(let ((work (lambda () (fact 15000))))
  (let ((zero (scaling-test work 0))
        (four (scaling-test work 4)))
    ;; a slightly weak assertion, but good enough for starters.
    (assert (< four (* 1.5 zero)))))

;;; For one of the interupt-thread tests, we want a foreign function
;;; that does not make syscalls

(with-open-file (o "threads-foreign.c" :direction :output :if-exists :supersede)
  (format o "void loop_forever() { while(1) ; }~%"))
(sb-ext:run-program "/bin/sh"
                    '("run-compiler.sh" "-sbcl-pic" "-sbcl-shared"
                      "-o" "threads-foreign.so" "threads-foreign.c")
                    :environment (test-util::test-env))
(sb-alien:load-shared-object (truename "threads-foreign.so"))
(sb-alien:define-alien-routine loop-forever sb-alien:void)
(delete-file "threads-foreign.c")


;;; elementary "can we get a lock and release it again"
(with-test (:name (:mutex :basics))
  (let ((l (make-mutex :name "foo"))
        (p *current-thread*))
    (assert (eql (mutex-value l) nil) nil "1")
    (sb-thread:get-mutex l)
    (assert (eql (mutex-value l) p) nil "3")
    (sb-thread:release-mutex l)
    (assert (eql (mutex-value l) nil) nil "5")))

(with-test (:name (:with-recursive-lock :basics))
  (labels ((ours-p (value)
             (eq *current-thread* value)))
    (let ((l (make-mutex :name "rec")))
      (assert (eql (mutex-value l) nil) nil "1")
      (sb-thread:with-recursive-lock (l)
        (assert (ours-p (mutex-value l)) nil "3")
        (sb-thread:with-recursive-lock (l)
          (assert (ours-p (mutex-value l)) nil "4"))
        (assert (ours-p (mutex-value l)) nil "5"))
      (assert (eql (mutex-value l) nil) nil "6"))))

(with-test (:name (:with-recursive-spinlock :basics))
  (labels ((ours-p (value)
             (eq *current-thread* value)))
    (let ((l (make-spinlock :name "rec")))
      (assert (eql (spinlock-value l) nil) nil "1")
      (with-recursive-spinlock (l)
        (assert (ours-p (spinlock-value l)) nil "3")
        (with-recursive-spinlock (l)
          (assert (ours-p (spinlock-value l)) nil "4"))
        (assert (ours-p (spinlock-value l)) nil "5"))
      (assert (eql (spinlock-value l) nil) nil "6"))))

(with-test (:name (:mutex :nesting-mutex-and-recursive-lock))
  (let ((l (make-mutex :name "a mutex")))
    (with-mutex (l)
      (with-recursive-lock (l)))))

(with-test (:name (:spinlock :nesting-spinlock-and-recursive-spinlock))
  (let ((l (make-spinlock :name "a spinlock")))
    (with-spinlock (l)
      (with-recursive-spinlock (l)))))

(with-test (:name (:spinlock :more-basics))
  (let ((l (make-spinlock :name "spinlock")))
    (assert (eql (spinlock-value l) nil) ((spinlock-value l))
            "spinlock not free (1)")
    (with-spinlock (l)
      (assert (eql (spinlock-value l) *current-thread*) ((spinlock-value l))
              "spinlock not taken"))
    (assert (eql (spinlock-value l) nil) ((spinlock-value l))
            "spinlock not free (2)")))

;; test that SLEEP actually sleeps for at least the given time, even
;; if interrupted by another thread exiting/a gc/anything
(with-test (:name (:sleep :continue-sleeping-after-interrupt))
  (let ((start-time (get-universal-time)))
    (make-thread (lambda () (sleep 1) (sb-ext:gc :full t)))
    (sleep 5)
    (assert (>= (get-universal-time) (+ 5 start-time)))))


(with-test (:name (:condition-wait :basics-1))
  (let ((queue (make-waitqueue :name "queue"))
        (lock (make-mutex :name "lock"))
        (n 0))
    (labels ((in-new-thread ()
               (with-mutex (lock)
                 (assert (eql (mutex-value lock) *current-thread*))
                 (format t "~A got mutex~%" *current-thread*)
                 ;; now drop it and sleep
                 (condition-wait queue lock)
                 ;; after waking we should have the lock again
                 (assert (eql (mutex-value lock) *current-thread*))
                 (assert (eql n 1))
                 (decf n))))
      (make-thread #'in-new-thread)
      (sleep 2)            ; give it  a chance to start
      ;; check the lock is free while it's asleep
      (format t "parent thread ~A~%" *current-thread*)
      (assert (eql (mutex-value lock) nil))
      (with-mutex (lock)
        (incf n)
        (condition-notify queue))
      (sleep 1))))

(with-test (:name (:condition-wait :basics-2))
  (let ((queue (make-waitqueue :name "queue"))
        (lock (make-mutex :name "lock")))
    (labels ((ours-p (value)
               (eq *current-thread* value))
             (in-new-thread ()
               (with-recursive-lock (lock)
                 (assert (ours-p (mutex-value lock)))
                 (format t "~A got mutex~%" (mutex-value lock))
                 ;; now drop it and sleep
                 (condition-wait queue lock)
                 ;; after waking we should have the lock again
                 (format t "woken, ~A got mutex~%" (mutex-value lock))
                 (assert (ours-p (mutex-value lock))))))
      (make-thread #'in-new-thread)
      (sleep 2)            ; give it  a chance to start
      ;; check the lock is free while it's asleep
      (format t "parent thread ~A~%" *current-thread*)
      (assert (eql (mutex-value lock) nil))
      (with-recursive-lock (lock)
        (condition-notify queue))
      (sleep 1))))

(with-test (:name (:mutex :contention))
  (let ((mutex (make-mutex :name "contended")))
    (labels ((run ()
               (let ((me *current-thread*))
                 (dotimes (i 100)
                   (with-mutex (mutex)
                     (sleep .03)
                     (assert (eql (mutex-value mutex) me)))
                   (assert (not (eql (mutex-value mutex) me))))
                 (format t "done ~A~%" *current-thread*))))
      (let ((kid1 (make-thread #'run))
            (kid2 (make-thread #'run)))
        (format t "contention ~A ~A~%" kid1 kid2)
        (wait-for-threads (list kid1 kid2))))))

;;; GRAB-MUTEX

(with-test (:name (:grab-mutex :waitp nil))
  (let ((m (make-mutex)))
    (with-mutex (m)
      (assert (null (join-thread (make-thread
                                  #'(lambda ()
                                      (grab-mutex m :waitp nil)))))))))

(with-test (:name (:grab-mutex :timeout :acquisition-fail))
  #+sb-lutex
  (error "Mutex timeout not supported here.")
  (let ((m (make-mutex))
        (w (make-semaphore)))
    (with-mutex (m)
      (let ((th (make-thread
                 #'(lambda ()
                     (prog1
                         (grab-mutex m :timeout 0.1)
                       (signal-semaphore w))))))
        ;; Wait for it to -- otherwise the detect the deadlock chain
        ;; from JOIN-THREAD.
        (wait-on-semaphore w)
        (assert (null (join-thread th)))))))

(with-test (:name (:grab-mutex :timeout :acquisition-success))
  #+sb-lutex
  (error "Mutex timeout not supported here.")
  (let ((m (make-mutex))
        (child))
    (with-mutex (m)
      (setq child (make-thread #'(lambda () (grab-mutex m :timeout 1.0))))
      (sleep 0.2))
    (assert (eq (join-thread child) 't))))

(with-test (:name (:grab-mutex :timeout+deadline))
  #+sb-lutex
  (error "Mutex timeout not supported here.")
  (let ((m (make-mutex))
        (w (make-semaphore)))
    (with-mutex (m)
      (let ((th (make-thread #'(lambda ()
                                 (sb-sys:with-deadline (:seconds 0.0)
                                   (handler-case
                                       (grab-mutex m :timeout 0.0)
                                     (sb-sys:deadline-timeout ()
                                       (signal-semaphore w)
                                       :deadline)))))))
        (wait-on-semaphore w)
        (assert (eq (join-thread th) :deadline))))))

(with-test (:name (:grab-mutex :waitp+deadline))
  #+sb-lutex
  (error "Mutex timeout not supported here.")
  (let ((m (make-mutex)))
    (with-mutex (m)
      (assert (eq (join-thread
                   (make-thread #'(lambda ()
                                    (sb-sys:with-deadline (:seconds 0.0)
                                      (handler-case
                                          (grab-mutex m :waitp nil)
                                        (sb-sys:deadline-timeout ()
                                          :deadline))))))
                  'nil)))))

;;; semaphores

(defmacro raises-timeout-p (&body body)
  `(handler-case (progn (progn ,@body) nil)
    (sb-ext:timeout () t)))

(with-test (:name (:semaphore :wait-forever))
  (let ((sem (make-semaphore :count 0)))
    (assert (raises-timeout-p
              (sb-ext:with-timeout 0.1
                (wait-on-semaphore sem))))))

(with-test (:name (:semaphore :initial-count))
  (let ((sem (make-semaphore :count 1)))
    (sb-ext:with-timeout 0.1
      (wait-on-semaphore sem))))

(with-test (:name (:semaphore :wait-then-signal))
  (let ((sem (make-semaphore))
        (signalled-p nil))
    (make-thread (lambda ()
                   (sleep 0.1)
                   (setq signalled-p t)
                   (signal-semaphore sem)))
    (wait-on-semaphore sem)
    (assert signalled-p)))

(with-test (:name (:semaphore :signal-then-wait))
  (let ((sem (make-semaphore))
        (signalled-p nil))
    (make-thread (lambda ()
                   (signal-semaphore sem)
                   (setq signalled-p t)))
    (loop until signalled-p)
    (wait-on-semaphore sem)
    (assert signalled-p)))

(defun test-semaphore-multiple-signals (wait-on-semaphore)
  (let* ((sem (make-semaphore :count 5))
         (threads (loop repeat 20 collecting
                        (make-thread (lambda ()
                                       (funcall wait-on-semaphore sem))))))
    (flet ((count-live-threads ()
             (count-if #'thread-alive-p threads)))
      (sleep 0.5)
      (assert (= 15 (count-live-threads)))
      (signal-semaphore sem 10)
      (sleep 0.5)
      (assert (= 5 (count-live-threads)))
      (signal-semaphore sem 3)
      (sleep 0.5)
      (assert (= 2 (count-live-threads)))
      (signal-semaphore sem 4)
      (sleep 0.5)
      (assert (= 0 (count-live-threads))))))

(with-test (:name (:semaphore :multiple-signals))
  (test-semaphore-multiple-signals #'wait-on-semaphore))

(with-test (:name (:try-semaphore :trivial-fail))
  (assert (eq (try-semaphore (make-semaphore :count 0)) 'nil)))

(with-test (:name (:try-semaphore :trivial-success))
  (let ((sem (make-semaphore :count 1)))
    (assert (try-semaphore sem))
    (assert (zerop (semaphore-count sem)))))

(with-test (:name (:try-semaphore :trivial-fail :n>1))
  (assert (eq (try-semaphore (make-semaphore :count 1) 2) 'nil)))

(with-test (:name (:try-semaphore :trivial-success :n>1))
  (let ((sem (make-semaphore :count 10)))
    (assert (try-semaphore sem 5))
    (assert (try-semaphore sem 5))
    (assert (zerop (semaphore-count sem)))))

(with-test (:name (:try-semaphore :emulate-wait-on-semaphore))
  (flet ((busy-wait-on-semaphore (sem)
           (loop until (try-semaphore sem) do (sleep 0.001))))
    (test-semaphore-multiple-signals #'busy-wait-on-semaphore)))

;;; Here we test that interrupting TRY-SEMAPHORE does not leave a
;;; semaphore in a bad state.
(with-test (:name (:try-semaphore :interrupt-safe))
  (flet ((make-threads (count fn)
           (loop repeat count collect (make-thread fn)))
         (kill-thread (thread)
           (when (thread-alive-p thread)
             (ignore-errors (terminate-thread thread))))
         (count-live-threads (threads)
           (count-if #'thread-alive-p threads)))
    ;; WAITERS will already be waiting on the semaphore while
    ;; threads-being-interrupted will perform TRY-SEMAPHORE on that
    ;; semaphore, and MORE-WAITERS are new threads trying to wait on
    ;; the semaphore during the interruption-fire.
    (let* ((sem (make-semaphore :count 100))
           (waiters (make-threads 20 #'(lambda ()
                                         (wait-on-semaphore sem))))
           (triers  (make-threads 40 #'(lambda ()
                                         (sleep (random 0.01))
                                         (try-semaphore sem (1+ (random 5))))))
           (more-waiters
            (loop repeat 10
                  do (kill-thread (nth (random 40) triers))
                  collect (make-thread #'(lambda () (wait-on-semaphore sem)))
                  do (kill-thread (nth (random 40) triers)))))
      (sleep 0.5)
      ;; Now ensure that the waiting threads will all be waked up,
      ;; i.e. that the semaphore is still working.
      (loop repeat (+ (count-live-threads waiters)
                      (count-live-threads more-waiters))
            do (signal-semaphore sem))
      (sleep 0.5)
      (assert (zerop (count-live-threads triers)))
      (assert (zerop (count-live-threads waiters)))
      (assert (zerop (count-live-threads more-waiters))))))



(format t "~&semaphore tests done~%")

(defun test-interrupt (function-to-interrupt &optional quit-p)
  (let ((child  (make-thread function-to-interrupt)))
    ;;(format t "gdb ./src/runtime/sbcl ~A~%attach ~A~%" child child)
    (sleep 2)
    (format t "interrupting child ~A~%" child)
    (interrupt-thread child
                      (lambda ()
                        (format t "child pid ~A~%" *current-thread*)
                        (when quit-p (sb-ext:quit))))
    (sleep 1)
    child))

;; separate tests for (a) interrupting Lisp code, (b) C code, (c) a syscall,
;; (d) waiting on a lock, (e) some code which we hope is likely to be
;; in pseudo-atomic

(with-test (:name (:interrupt-thread :more-basics))
  (let ((child (test-interrupt (lambda () (loop)))))
    (terminate-thread child)))

(with-test (:name (:interrupt-thread :interrupt-foreign-loop))
  (test-interrupt #'loop-forever :quit))

(with-test (:name (:interrupt-thread :interrupt-sleep))
  (let ((child (test-interrupt (lambda () (loop (sleep 2000))))))
    (terminate-thread child)
    (wait-for-threads (list child))))

(with-test (:name (:interrupt-thread :interrupt-mutex-acquisition))
  (let ((lock (make-mutex :name "loctite"))
        child)
    (with-mutex (lock)
      (setf child (test-interrupt
                   (lambda ()
                     (with-mutex (lock)
                       (assert (eql (mutex-value lock) *current-thread*)))
                     (assert (not (eql (mutex-value lock) *current-thread*)))
                     (sleep 10))))
      ;;hold onto lock for long enough that child can't get it immediately
      (sleep 5)
      (interrupt-thread child (lambda () (format t "l ~A~%" (mutex-value lock))))
      (format t "parent releasing lock~%"))
    (terminate-thread child)
    (wait-for-threads (list child))))

(format t "~&locking test done~%")

(defun alloc-stuff () (copy-list '(1 2 3 4 5)))

(with-test (:name (:interrupt-thread :interrupt-consing-child))
  (let ((thread (sb-thread:make-thread (lambda () (loop (alloc-stuff))))))
    (let ((killers
           (loop repeat 4 collect
                 (sb-thread:make-thread
                  (lambda ()
                    (loop repeat 25 do
                          (sleep (random 0.1d0))
                          (princ ".")
                          (force-output)
                          (sb-thread:interrupt-thread thread (lambda ()))))))))
      (wait-for-threads killers)
      (sb-thread:terminate-thread thread)
      (wait-for-threads (list thread))))
  (sb-ext:gc :full t))

(format t "~&multi interrupt test done~%")

#+(or x86 x86-64) ;; x86oid-only, see internal commentary.
(with-test (:name (:interrupt-thread :interrupt-consing-child :again))
  (let ((c (make-thread (lambda () (loop (alloc-stuff))))))
    ;; NB this only works on x86: other ports don't have a symbol for
    ;; pseudo-atomic atomicity
    (dotimes (i 100)
      (sleep (random 0.1d0))
      (interrupt-thread c
                        (lambda ()
                          (princ ".") (force-output)
                          (assert (thread-alive-p *current-thread*))
                          (assert
                           (not (logbitp 0 SB-KERNEL:*PSEUDO-ATOMIC-BITS*))))))
    (terminate-thread c)
    (wait-for-threads (list c))))

(format t "~&interrupt test done~%")

(defstruct counter (n 0 :type sb-vm:word))
(defvar *interrupt-counter* (make-counter))

(declaim (notinline check-interrupt-count))
(defun check-interrupt-count (i)
  (declare (optimize (debug 1) (speed 1)))
  ;; This used to lose if eflags were not restored after an interrupt.
  (unless (typep i 'fixnum)
    (error "!!!!!!!!!!!")))

(with-test (:name (:interrupt-thread :interrupt-ATOMIC-INCF))
  (let ((c (make-thread
            (lambda ()
              (handler-bind ((error #'(lambda (cond)
                                        (princ cond)
                                        (sb-debug:backtrace
                                         most-positive-fixnum))))
                (loop (check-interrupt-count
                       (counter-n *interrupt-counter*))))))))
    (let ((func (lambda ()
                  (princ ".")
                  (force-output)
                  (sb-ext:atomic-incf (counter-n *interrupt-counter*)))))
      (setf (counter-n *interrupt-counter*) 0)
      (dotimes (i 100)
        (sleep (random 0.1d0))
        (interrupt-thread c func))
      (loop until (= (counter-n *interrupt-counter*) 100) do (sleep 0.1))
      (terminate-thread c)
      (wait-for-threads (list c)))))

(format t "~&interrupt count test done~%")

(defvar *runningp* nil)

(with-test (:name (:interrupt-thread :no-nesting))
  (let ((thread (sb-thread:make-thread
                 (lambda ()
                   (catch 'xxx
                     (loop))))))
    (declare (special runningp))
    (sleep 0.2)
    (sb-thread:interrupt-thread thread
                                (lambda ()
                                    (let ((*runningp* t))
                                      (sleep 1))))
    (sleep 0.2)
    (sb-thread:interrupt-thread thread
                                (lambda ()
                                  (throw 'xxx *runningp*)))
    (assert (not (sb-thread:join-thread thread)))))

(with-test (:name (:interrupt-thread :nesting))
  (let ((thread (sb-thread:make-thread
                 (lambda ()
                   (catch 'xxx
                     (loop))))))
    (declare (special runningp))
    (sleep 0.2)
    (sb-thread:interrupt-thread thread
                                (lambda ()
                                  (let ((*runningp* t))
                                    (sb-sys:with-interrupts
                                      (sleep 1)))))
    (sleep 0.2)
    (sb-thread:interrupt-thread thread
                                (lambda ()
                                  (throw 'xxx *runningp*)))
    (assert (sb-thread:join-thread thread))))

(with-test (:name (:two-threads-running-gc))
  (let (a-done b-done)
    (make-thread (lambda ()
                   (dotimes (i 100)
                     (sb-ext:gc) (princ "\\") (force-output))
                   (setf a-done t)))
    (make-thread (lambda ()
                   (dotimes (i 25)
                     (sb-ext:gc :full t)
                     (princ "/") (force-output))
                   (setf b-done t)))
    (loop
      (when (and a-done b-done) (return))
      (sleep 1))))

(terpri)

(defun waste (&optional (n 100000))
  (loop repeat n do (make-string 16384)))

(with-test (:name (:one-thread-runs-gc-while-other-conses))
  (loop for i below 100 do
        (princ "!")
        (force-output)
        (sb-thread:make-thread
         #'(lambda ()
             (waste)))
        (waste)
        (sb-ext:gc)))

(terpri)

(defparameter *aaa* nil)
(with-test (:name (:one-thread-runs-gc-while-other-conses :again))
  (loop for i below 100 do
        (princ "!")
        (force-output)
        (sb-thread:make-thread
         #'(lambda ()
             (let ((*aaa* (waste)))
               (waste))))
        (let ((*aaa* (waste)))
          (waste))
        (sb-ext:gc)))

(format t "~&gc test done~%")

;; this used to deadlock on session-lock
(with-test (:name (:no-session-deadlock))
  (sb-thread:make-thread (lambda () (sb-ext:gc))))

(defun exercise-syscall (fn reference-errno)
  (sb-thread:make-thread
   (lambda ()
     (loop do
          (funcall fn)
          (let ((errno (sb-unix::get-errno)))
            (sleep (random 0.1d0))
            (unless (eql errno reference-errno)
              (format t "Got errno: ~A (~A) instead of ~A~%"
                      errno
                      (sb-unix::strerror)
                      reference-errno)
              (force-output)
              (sb-ext:quit :unix-status 1)))))))

;; (nanosleep -1 0) does not fail on FreeBSD
(with-test (:name (:exercising-concurrent-syscalls))
  (let* (#-freebsd
         (nanosleep-errno (progn
                            (sb-unix:nanosleep -1 0)
                            (sb-unix::get-errno)))
         (open-errno (progn
                       (open "no-such-file"
                             :if-does-not-exist nil)
                       (sb-unix::get-errno)))
         (threads
          (list
           #-freebsd
           (exercise-syscall (lambda () (sb-unix:nanosleep -1 0)) nanosleep-errno)
           (exercise-syscall (lambda () (open "no-such-file"
                                              :if-does-not-exist nil))
                             open-errno)
           (sb-thread:make-thread (lambda () (loop (sb-ext:gc) (sleep 1)))))))
    (sleep 10)
    (princ "terminating threads")
    (dolist (thread threads)
      (sb-thread:terminate-thread thread))))

(format t "~&errno test done~%")

(with-test (:name (:terminate-thread-restart))
  (loop repeat 100 do
        (let ((thread (sb-thread:make-thread (lambda () (sleep 0.1)))))
          (sb-thread:interrupt-thread
           thread
           (lambda ()
             (assert (find-restart 'sb-thread:terminate-thread)))))))

(sb-ext:gc :full t)

(format t "~&thread startup sigmask test done~%")

(with-test (:name (:debugger-no-hang-on-session-lock-if-interrupted))
  (sb-debug::enable-debugger)
  (let* ((main-thread *current-thread*)
         (interruptor-thread
          (make-thread (lambda ()
                         (sleep 2)
                         (interrupt-thread main-thread
                                           (lambda ()
                                             (with-interrupts
                                               (break))))
                         (sleep 2)
                         (interrupt-thread main-thread #'continue))
                       :name "interruptor")))
    (with-session-lock (*session*)
      (sleep 3))
    (loop while (thread-alive-p interruptor-thread))))

(format t "~&session lock test done~%")

;; expose thread creation races by exiting quickly
(with-test (:name (:no-thread-creation-race :light))
  (sb-thread:make-thread (lambda ())))

(with-test (:name (:no-thread-creation-race :heavy))
  (loop repeat 20 do
        (wait-for-threads
         (loop for i below 100 collect
               (sb-thread:make-thread (lambda ()))))))

(format t "~&creation test done~%")

;; interrupt handlers are per-thread with pthreads, make sure the
;; handler installed in one thread is global
(with-test (:name (:global-interrupt-handler))
  (sb-thread:make-thread
   (lambda ()
     (sb-ext:run-program "sleep" '("1") :search t :wait nil))))

;;;; Binding stack safety

(defparameter *x* nil)
(defparameter *n-gcs-requested* 0)
(defparameter *n-gcs-done* 0)

(let ((counter 0))
  (defun make-something-big ()
    (let ((x (make-string 32000)))
      (incf counter)
      (let ((counter counter))
        (sb-ext:finalize x (lambda () (format t " ~S" counter)
                                   (force-output)))))))

(defmacro wait-for-gc ()
  `(progn
     (incf *n-gcs-requested*)
     (loop while (< *n-gcs-done* *n-gcs-requested*))))

(defun send-gc ()
  (loop until (< *n-gcs-done* *n-gcs-requested*))
  (format t "G")
  (force-output)
  (sb-ext:gc)
  (incf *n-gcs-done*))

(defun exercise-binding ()
  (loop
   (let ((*x* (make-something-big)))
     (let ((*x* 42))
       ;; at this point the binding stack looks like this:
       ;; NO-TLS-VALUE-MARKER, *x*, SOMETHING, *x*
       t))
   (wait-for-gc)
   ;; sig_stop_for_gc_handler binds FREE_INTERRUPT_CONTEXT_INDEX. By
   ;; now SOMETHING is gc'ed and the binding stack looks like this: 0,
   ;; 0, SOMETHING, 0 (because the symbol slots are zeroed on
   ;; unbinding but values are not).
   (let ((*x* nil))
     ;; bump bsp as if a BIND had just started
     (incf sb-vm::*binding-stack-pointer* 2)
     (wait-for-gc)
     (decf sb-vm::*binding-stack-pointer* 2))))

(with-test (:name (:binding-stack-gc-safety))
  (let (threads)
    (unwind-protect
         (progn
           (push (sb-thread:make-thread #'exercise-binding) threads)
           (push (sb-thread:make-thread (lambda ()
                                          (loop
                                           (sleep 0.1)
                                           (send-gc))))
                 threads)
           (sleep 4))
      (mapc #'sb-thread:terminate-thread threads))))

(format t "~&binding test done~%")

;;; HASH TABLES

(defvar *errors* nil)

(defun oops (e)
  (setf *errors* e)
  (format t "~&oops: ~A in ~S~%" e *current-thread*)
  (sb-debug:backtrace)
  (catch 'done))

(with-test (:name (:unsynchronized-hash-table)
                  ;; FIXME: This test occasionally eats out craploads
                  ;; of heap instead of expected error early. Not 100%
                  ;; sure if it would finish as expected, but since it
                  ;; hits swap on my system I'm not likely to find out
                  ;; soon. Disabling for now. -- nikodemus
            :skipped-on :sbcl)
  ;; We expect a (probable) error here: parellel readers and writers
  ;; on a hash-table are not expected to work -- but we also don't
  ;; expect this to corrupt the image.
  (let* ((hash (make-hash-table))
         (*errors* nil)
         (threads (list (sb-thread:make-thread
                         (lambda ()
                           (catch 'done
                             (handler-bind ((serious-condition 'oops))
                               (loop
                                 ;;(princ "1") (force-output)
                                 (setf (gethash (random 100) hash) 'h)))))
                         :name "writer")
                        (sb-thread:make-thread
                         (lambda ()
                           (catch 'done
                             (handler-bind ((serious-condition 'oops))
                               (loop
                                 ;;(princ "2") (force-output)
                                 (remhash (random 100) hash)))))
                         :name "reader")
                        (sb-thread:make-thread
                         (lambda ()
                           (catch 'done
                             (handler-bind ((serious-condition 'oops))
                               (loop
                                 (sleep (random 1.0))
                                 (sb-ext:gc :full t)))))
                         :name "collector"))))
    (unwind-protect
         (sleep 10)
      (mapc #'sb-thread:terminate-thread threads))))

(format t "~&unsynchronized hash table test done~%")

(with-test (:name (:synchronized-hash-table))
  (let* ((hash (make-hash-table :synchronized t))
         (*errors* nil)
         (threads (list (sb-thread:make-thread
                         (lambda ()
                           (catch 'done
                             (handler-bind ((serious-condition 'oops))
                               (loop
                                 ;;(princ "1") (force-output)
                                 (setf (gethash (random 100) hash) 'h)))))
                         :name "writer")
                        (sb-thread:make-thread
                         (lambda ()
                           (catch 'done
                             (handler-bind ((serious-condition 'oops))
                               (loop
                                 ;;(princ "2") (force-output)
                                 (remhash (random 100) hash)))))
                         :name "reader")
                        (sb-thread:make-thread
                         (lambda ()
                           (catch 'done
                             (handler-bind ((serious-condition 'oops))
                               (loop
                                 (sleep (random 1.0))
                                 (sb-ext:gc :full t)))))
                         :name "collector"))))
    (unwind-protect
         (sleep 10)
      (mapc #'sb-thread:terminate-thread threads))
    (assert (not *errors*))))

(format t "~&synchronized hash table test done~%")

(with-test (:name (:hash-table-parallel-readers))
  (let ((hash (make-hash-table))
        (*errors* nil))
    (loop repeat 50
          do (setf (gethash (random 100) hash) 'xxx))
    (let ((threads (list (sb-thread:make-thread
                          (lambda ()
                            (catch 'done
                              (handler-bind ((serious-condition 'oops))
                                (loop
                                      until (eq t (gethash (random 100) hash))))))
                          :name "reader 1")
                         (sb-thread:make-thread
                          (lambda ()
                            (catch 'done
                              (handler-bind ((serious-condition 'oops))
                                (loop
                                      until (eq t (gethash (random 100) hash))))))
                          :name "reader 2")
                         (sb-thread:make-thread
                          (lambda ()
                            (catch 'done
                              (handler-bind ((serious-condition 'oops))
                                (loop
                                      until (eq t (gethash (random 100) hash))))))
                          :name "reader 3")
                         (sb-thread:make-thread
                          (lambda ()
                            (catch 'done
                              (handler-bind ((serious-condition 'oops))
                               (loop
                                 (sleep (random 1.0))
                                 (sb-ext:gc :full t)))))
                          :name "collector"))))
      (unwind-protect
           (sleep 10)
        (mapc #'sb-thread:terminate-thread threads))
      (assert (not *errors*)))))

(format t "~&multiple reader hash table test done~%")

(with-test (:name (:hash-table-single-accessor-parallel-gc))
  (let ((hash (make-hash-table))
        (*errors* nil))
    (let ((threads (list (sb-thread:make-thread
                          (lambda ()
                            (handler-bind ((serious-condition 'oops))
                              (loop
                                (let ((n (random 100)))
                                  (if (gethash n hash)
                                      (remhash n hash)
                                      (setf (gethash n hash) 'h))))))
                          :name "accessor")
                         (sb-thread:make-thread
                          (lambda ()
                            (handler-bind ((serious-condition 'oops))
                              (loop
                                (sleep (random 1.0))
                                (sb-ext:gc :full t))))
                          :name "collector"))))
      (unwind-protect
           (sleep 10)
        (mapc #'sb-thread:terminate-thread threads))
      (assert (not *errors*)))))

(format t "~&single accessor hash table test~%")

#|  ;; a cll post from eric marsden
| (defun crash ()
|   (setq *debugger-hook*
|         (lambda (condition old-debugger-hook)
|           (debug:backtrace 10)
|           (unix:unix-exit 2)))
|   #+live-dangerously
|   (mp::start-sigalrm-yield)
|   (flet ((roomy () (loop (with-output-to-string (*standard-output*) (room)))))
|     (mp:make-process #'roomy)
|     (mp:make-process #'roomy)))
|#

(with-test (:name (:condition-variable :notify-multiple))
  (flet ((tester (notify-fun)
           (let ((queue (make-waitqueue :name "queue"))
                 (lock (make-mutex :name "lock"))
                 (data nil))
             (labels ((test (x)
                        (loop
                           (with-mutex (lock)
                             (format t "condition-wait ~a~%" x)
                             (force-output)
                             (condition-wait queue lock)
                             (format t "woke up ~a~%" x)
                             (force-output)
                             (push x data)))))
               (let ((threads (loop for x from 1 to 10
                                    collect
                                    (let ((x x))
                                      (sb-thread:make-thread (lambda ()
                                                               (test x)))))))
                 (sleep 5)
                 (with-mutex (lock)
                   (funcall notify-fun queue))
                 (sleep 5)
                 (mapcar #'terminate-thread threads)
                 ;; Check that all threads woke up at least once
                 (assert (= (length (remove-duplicates data)) 10)))))))
    (tester (lambda (queue)
              (format t "~&(condition-notify queue 10)~%")
              (force-output)
              (condition-notify queue 10)))
    (tester (lambda (queue)
              (format t "~&(condition-broadcast queue)~%")
              (force-output)
              (condition-broadcast queue)))))

(format t "waitqueue wakeup tests done~%")

;;; Make sure that a deadline handler is not invoked twice in a row in
;;; CONDITION-WAIT. See LP #512914 for a detailed explanation.
;;;
#-sb-lutex    ; See KLUDGE above: no deadlines for condition-wait+lutexes.
(with-test (:name (:condition-wait :deadlines :LP-512914))
  (let ((n 2) ; was empirically enough to trigger the bug
        (mutex (sb-thread:make-mutex))
        (waitq (sb-thread:make-waitqueue))
        (threads nil)
        (deadline-handler-run-twice? nil))
    (dotimes (i n)
      (let ((child
             (sb-thread:make-thread
              #'(lambda ()
                  (handler-bind
                      ((sb-sys:deadline-timeout
                        (let ((already? nil))
                          #'(lambda (c)
                              (when already?
                                (setq deadline-handler-run-twice? t))
                              (setq already? t)
                              (sleep 0.2)
                              (sb-thread:condition-broadcast waitq)
                              (sb-sys:defer-deadline 10.0 c)))))
                    (sb-sys:with-deadline (:seconds 0.1)
                      (sb-thread:with-mutex (mutex)
                        (sb-thread:condition-wait waitq mutex))))))))
        (push child threads)))
    (mapc #'sb-thread:join-thread threads)
    (assert (not deadline-handler-run-twice?))))

(with-test (:name (:condition-wait :signal-deadline-with-interrupts-enabled))
  #+darwin
  (error "Bad Darwin")
  (let ((mutex (sb-thread:make-mutex))
        (waitq (sb-thread:make-waitqueue))
        (A-holds? :unknown)
        (B-holds? :unknown)
        (A-interrupts-enabled? :unknown)
        (B-interrupts-enabled? :unknown)
        (A)
        (B))
    ;; W.L.O.G., we assume that A is executed first...
    (setq A (sb-thread:make-thread
             #'(lambda ()
                 (handler-bind
                     ((sb-sys:deadline-timeout
                       #'(lambda (c)
                           ;; We came here through the call to DECODE-TIMEOUT
                           ;; in CONDITION-WAIT; hence both here are supposed
                           ;; to evaluate to T.
                           (setq A-holds? (sb-thread:holding-mutex-p mutex))
                           (setq A-interrupts-enabled?
                                 sb-sys:*interrupts-enabled*)
                           (sleep 0.2)
                           (sb-thread:condition-broadcast waitq)
                           (sb-sys:defer-deadline 10.0 c))))
                   (sb-sys:with-deadline (:seconds 0.1)
                     (sb-thread:with-mutex (mutex)
                       (sb-thread:condition-wait waitq mutex)))))))
    (setq B (sb-thread:make-thread
             #'(lambda ()
                 (thread-yield)
                 (handler-bind
                     ((sb-sys:deadline-timeout
                       #'(lambda (c)
                           ;; We came here through the call to GET-MUTEX
                           ;; in CONDITION-WAIT (contended case of
                           ;; reaquiring the mutex) - so the former will
                           ;; be NIL, but interrupts should still be enabled.
                           (setq B-holds? (sb-thread:holding-mutex-p mutex))
                           (setq B-interrupts-enabled?
                                 sb-sys:*interrupts-enabled*)
                           (sleep 0.2)
                           (sb-thread:condition-broadcast waitq)
                           (sb-sys:defer-deadline 10.0 c))))
                   (sb-sys:with-deadline (:seconds 0.1)
                     (sb-thread:with-mutex (mutex)
                       (sb-thread:condition-wait waitq mutex)))))))
    (sb-thread:join-thread A)
    (sb-thread:join-thread B)
    (let ((A-result (list A-holds? A-interrupts-enabled?))
          (B-result (list B-holds? B-interrupts-enabled?)))
      ;; We also check some subtle behaviour w.r.t. whether a deadline
      ;; handler in CONDITION-WAIT got the mutex, or not. This is most
      ;; probably very internal behaviour (so user should not depend
      ;; on it) -- I added the testing here just to manifest current
      ;; behaviour.
      (cond ((equal A-result '(t t)) (assert (equal B-result '(nil t))))
            ((equal B-result '(t t)) (assert (equal A-result '(nil t))))
            (t (error "Failure: fall through."))))))

(with-test (:name (:mutex :finalization))
  (let ((a nil))
    (dotimes (i 500000)
      (setf a (make-mutex)))))

(format t "mutex finalization test done~%")

;;; Check that INFO is thread-safe, at least when we're just doing reads.

(let* ((symbols (loop repeat 10000 collect (gensym)))
       (functions (loop for (symbol . rest) on symbols
                        for next = (car rest)
                        for fun = (let ((next next))
                                    (lambda (n)
                                      (if next
                                          (funcall next (1- n))
                                          n)))
                        do (setf (symbol-function symbol) fun)
                        collect fun)))
  (defun infodb-test ()
    (funcall (car functions) 9999)))

(with-test (:name (:infodb :read))
  (let* ((ok t)
         (threads (loop for i from 0 to 10
                        collect (sb-thread:make-thread
                                 (lambda ()
                                   (dotimes (j 100)
                                     (write-char #\-)
                                     (finish-output)
                                     (let ((n (infodb-test)))
                                       (unless (zerop n)
                                         (setf ok nil)
                                         (format t "N != 0 (~A)~%" n)
                                         (sb-ext:quit)))))))))
    (wait-for-threads threads)
    (assert ok)))

(format t "infodb test done~%")

(with-test (:name (:backtrace))
  #+darwin
  (error "Prone to crash on Darwin, cause unknown.")
  ;; Printing backtraces from several threads at once used to hang the
  ;; whole SBCL process (discovered by accident due to a timer.impure
  ;; test misbehaving). The cause was that packages weren't even
  ;; thread-safe for only doing FIND-SYMBOL, and while printing
  ;; backtraces a loot of symbol lookups need to be done due to
  ;; *PRINT-ESCAPE*.
  (let* ((threads (loop repeat 10
                        collect (sb-thread:make-thread
                                 (lambda ()
                                   (dotimes (i 1000)
                                     (with-output-to-string (*debug-io*)
                                       (sb-debug::backtrace 10))))))))
    (wait-for-threads threads)))

(format t "backtrace test done~%")

(format t "~&starting gc deadlock test: WARNING: THIS TEST WILL HANG ON FAILURE!~%")

(with-test (:name (:gc-deadlock))
  #+darwin
  (error "Prone to hang on Darwin due to interrupt issues.")
  ;; Prior to 0.9.16.46 thread exit potentially deadlocked the
  ;; GC due to *all-threads-lock* and session lock. On earlier
  ;; versions and at least on one specific box this test is good enough
  ;; to catch that typically well before the 1500th iteration.
  (loop
     with i = 0
     with n = 3000
     while (< i n)
     do
       (incf i)
       (when (zerop (mod i 100))
         (write-char #\.)
         (force-output))
       (handler-case
           (if (oddp i)
               (sb-thread:make-thread
                (lambda ()
                  (sleep (random 0.001)))
                :name (format nil "SLEEP-~D" i))
               (sb-thread:make-thread
                (lambda ()
                  ;; KLUDGE: what we are doing here is explicit,
                  ;; but the same can happen because of a regular
                  ;; MAKE-THREAD or LIST-ALL-THREADS, and various
                  ;; session functions.
                  (sb-thread::with-all-threads-lock
                    (sb-thread::with-session-lock (sb-thread::*session*)
                      (sb-ext:gc))))
                :name (format nil "GC-~D" i)))
         (error (e)
           (format t "~%error creating thread ~D: ~A -- backing off for retry~%" i e)
           (sleep 0.1)
           (incf i)))))

(format t "~&gc deadlock test done~%")

(let ((count (make-array 8 :initial-element 0)))
  (defun closure-one ()
    (declare (optimize safety))
    (values (incf (aref count 0)) (incf (aref count 1))
            (incf (aref count 2)) (incf (aref count 3))
            (incf (aref count 4)) (incf (aref count 5))
            (incf (aref count 6)) (incf (aref count 7))))
  (defun no-optimizing-away-closure-one ()
    (setf count (make-array 8 :initial-element 0))))

(defstruct box
  (count 0))

(let ((one (make-box))
      (two (make-box))
      (three (make-box)))
  (defun closure-two ()
    (declare (optimize safety))
    (values (incf (box-count one)) (incf (box-count two)) (incf (box-count three))))
  (defun no-optimizing-away-closure-two ()
    (setf one (make-box)
          two (make-box)
          three (make-box))))

(with-test (:name (:funcallable-instances))
  ;; the funcallable-instance implementation used not to be threadsafe
  ;; against setting the funcallable-instance function to a closure
  ;; (because the code and lexenv were set separately).
  (let ((fun (sb-kernel:%make-funcallable-instance 0))
        (condition nil))
    (setf (sb-kernel:funcallable-instance-fun fun) #'closure-one)
    (flet ((changer ()
             (loop (setf (sb-kernel:funcallable-instance-fun fun) #'closure-one)
                   (setf (sb-kernel:funcallable-instance-fun fun) #'closure-two)))
           (test ()
             (handler-case (loop (funcall fun))
               (serious-condition (c) (setf condition c)))))
      (let ((changer (make-thread #'changer))
            (test (make-thread #'test)))
        (handler-case
            (progn
              ;; The two closures above are fairly carefully crafted
              ;; so that if given the wrong lexenv they will tend to
              ;; do some serious damage, but it is of course difficult
              ;; to predict where the various bits and pieces will be
              ;; allocated.  Five seconds failed fairly reliably on
              ;; both my x86 and x86-64 systems.  -- CSR, 2006-09-27.
              (sb-ext:with-timeout 5
                (wait-for-threads (list test)))
              (error "~@<test thread got condition:~2I~_~A~@:>" condition))
          (sb-ext:timeout ()
            (terminate-thread changer)
            (terminate-thread test)
            (wait-for-threads (list changer test))))))))

(format t "~&funcallable-instance test done~%")

(defun random-type (n)
  `(integer ,(random n) ,(+ n (random n))))

(defun subtypep-hash-cache-test ()
  (dotimes (i 10000)
    (let ((type1 (random-type 500))
          (type2 (random-type 500)))
      (let ((a (subtypep type1 type2)))
        (dotimes (i 100)
          (assert (eq (subtypep type1 type2) a))))))
  (format t "ok~%")
  (force-output))

(with-test (:name (:hash-cache :subtypep))
  (dotimes (i 10)
    (sb-thread:make-thread #'subtypep-hash-cache-test)))
(format t "hash-cache tests done~%")

;;;; BLACK BOX TESTS

(in-package :cl-user)
(use-package :test-util)
(use-package "ASSERTOID")

(format t "parallel defclass test -- WARNING, WILL HANG ON FAILURE!~%")
(with-test (:name :parallel-defclass)
  (defclass test-1 () ((a :initform :orig-a)))
  (defclass test-2 () ((b :initform :orig-b)))
  (defclass test-3 (test-1 test-2) ((c :initform :orig-c)))
  (let* ((run t)
         (d1 (sb-thread:make-thread (lambda ()
                                      (loop while run
                                            do (defclass test-1 () ((a :initform :new-a)))
                                            (write-char #\1)
                                            (force-output)))
                                    :name "d1"))
         (d2 (sb-thread:make-thread (lambda ()
                                      (loop while run
                                            do (defclass test-2 () ((b :initform :new-b)))
                                               (write-char #\2)
                                               (force-output)))
                                    :name "d2"))
         (d3 (sb-thread:make-thread (lambda ()
                                      (loop while run
                                            do (defclass test-3 (test-1 test-2) ((c :initform :new-c)))
                                               (write-char #\3)
                                               (force-output)))
                                    :name "d3"))
         (i (sb-thread:make-thread (lambda ()
                                     (loop while run
                                           do (let ((i (make-instance 'test-3)))
                                                (assert (member (slot-value i 'a) '(:orig-a :new-a)))
                                                (assert (member (slot-value i 'b) '(:orig-b :new-b)))
                                                (assert (member (slot-value i 'c) '(:orig-c :new-c))))
                                              (write-char #\i)
                                              (force-output)))
                                   :name "i")))
    (format t "~%sleeping!~%")
    (sleep 2.0)
    (format t "~%stopping!~%")
    (setf run nil)
    (mapc (lambda (th)
            (sb-thread:join-thread th)
            (format t "~%joined ~S~%" (sb-thread:thread-name th)))
          (list d1 d2 d3 i))))
(format t "parallel defclass test done~%")

(with-test (:name (:deadlock-detection :interrupts))
  (let* ((m1 (sb-thread:make-mutex :name "M1"))
         (m2 (sb-thread:make-mutex :name "M2"))
         (t1 (sb-thread:make-thread
              (lambda ()
                (sb-thread:with-mutex (m1)
                  (sleep 0.3)
                  :ok))
              :name "T1"))
         (t2 (sb-thread:make-thread
              (lambda ()
                (sleep 0.1)
                (sb-thread:with-mutex (m1 :wait-p t)
                  (sleep 0.2)
                  :ok))
              :name "T2")))
    (sleep 0.2)
    (sb-thread:interrupt-thread t2 (lambda ()
                                     (sb-thread:with-mutex (m2 :wait-p t)
                                       (sleep 0.3))))
    (sleep 0.05)
    (sb-thread:interrupt-thread t1 (lambda ()
                                     (sb-thread:with-mutex (m2 :wait-p t)
                                       (sleep 0.3))))
    ;; both threads should finish without a deadlock or deadlock
    ;; detection error
    (let ((res (list (sb-thread:join-thread t1)
                     (sb-thread:join-thread t2))))
      (assert (equal '(:ok :ok) res)))))

(with-test (:name (:deadlock-detection :gc))
  ;; To semi-reliably trigger the error (in SBCL's where)
  ;; it was present you had to run this for > 30 seconds,
  ;; but that's a bit long for a single test.
  (let* ((stop (+ 5 (get-universal-time)))
         (m1 (sb-thread:make-mutex :name "m1"))
         (t1 (sb-thread:make-thread
              (lambda ()
                (loop until (> (get-universal-time) stop)
                      do (sb-thread:with-mutex (m1)
                           (eval `(make-array 24))))
                :ok)))
         (t2 (sb-thread:make-thread
              (lambda ()
                (loop until (> (get-universal-time) stop)
                      do (sb-thread:with-mutex (m1)
                           (eval `(make-array 24))))
                :ok))))
    (let ((res (list (sb-thread:join-thread t1)
                     (sb-thread:join-thread t2))))
      (assert (equal '(:ok :ok) res)))))
