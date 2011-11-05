;;;; tests PROFILE with multiple threads

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

(load "assertoid.lisp")
(load "test-util.lisp")

(defpackage :profile-test
  (:use :cl :sb-thread))

(in-package :profile-test)

(defun miller-rabin-prime-p (n &optional (s 50))
 "Miller-Rabin primality test written by R. Matthew Emerson."
 (flet ((witness-p (a n)
          (loop with b = (- n 1)
                for i from (integer-length b) downto 0
                for d = 1 then (mod (* d d) n)
                for x = d
                do (progn
                     (when (and (= d 1) (/= x 1) (/= x (- n 1)))
                       (return-from witness-p t))
                     (when (logbitp i b)
                       (setf d (mod (* d a) n))))
                finally (return (/= d 1)))))
   (dotimes (i s n)
     (let ((w (1+ (random (- n 1)))))
       (when (witness-p w n)
         (return-from miller-rabin-prime-p nil))))))

(defun random-of-bit-size (n-bits)
 "Returns a random number of maximum size `N-BITS'."
 (random (ash 1 n-bits)))

(defun prime-of-bit-size (n-bits)
 "Returns a prime number of maximum size `N-BITS'."
 (loop for maybe-prime = (random-of-bit-size n-bits)
       when (miller-rabin-prime-p maybe-prime)
         do (return maybe-prime)))

(defun waste-cpu-cycles (n-primes n-prime-bits n-workers)
  (if (= n-workers 1)
      (handler-case
          (progn
            (loop repeat n-primes
                  do (prime-of-bit-size n-prime-bits))
            (list t))
        (serious-condition (s)
          s))
      (let* ((r (make-semaphore))
             (w (make-semaphore))
             (workers
              (loop repeat n-workers
                    collect (sb-thread:make-thread
                             (let ((rs (make-random-state)))
                               (lambda ()
                                 (block nil
                                     (handler-bind ((serious-condition (lambda (c)
                                                                         (princ c)
                                                                         (sb-debug:backtrace)
                                                                         (return c))))
                                       (let ((*random-state* rs))
                                         (signal-semaphore r)
                                         (wait-on-semaphore w)
                                         (loop repeat n-primes
                                               do (prime-of-bit-size n-prime-bits))
                                         t)))))))))
        (loop repeat n-workers do (wait-on-semaphore r))
        (signal-semaphore w n-workers)
        (mapcar #'sb-thread:join-thread workers))))

(in-package :cl-user)

(with-test (:name (profile threads))
  (profile "PROFILE-TEST")
  ;; This used to signal an error with threads
  (let* ((n #+sb-thread 5 #-sb-thread 1)
         (res (profile-test::waste-cpu-cycles 10 256 n))
         (want (make-list n :initial-element t)))
    (unless (equal res want)
      (error "wanted ~S, got ~S" want res)))
  (report))

(with-test (:name :profiling-counter)
  ;; Make sure our profiling counters don't miscount
  (let ((c (sb-profile::make-counter))
        (i 0))
    (loop repeat 1000000
          do (let ((n (random (* 12 (ash 1 sb-vm:n-word-bits)))))
               (sb-profile::incf-counter c n)
               (incf i n))
             (let ((n (random (ash 1 sb-vm:n-word-bits))))
               (sb-profile::incf-counter c n)
               (incf i n)))
    (assert (= i (sb-profile::counter-count c)))))
