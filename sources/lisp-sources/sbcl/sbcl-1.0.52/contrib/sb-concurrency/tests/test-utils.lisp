(in-package :sb-concurrency-test)

#+sb-thread
(progn

(defparameter +timeout+ 30.0)

(defun make-threads (n name fn)
  (loop for i from 1 to n
        collect (make-thread fn :name (format nil "~A-~D" name i))))

(defun timed-join-thread (thread &optional (timeout +timeout+))
  (handler-case (sb-sys:with-deadline (:seconds timeout)
                  (join-thread thread :default :aborted))
    (sb-ext:timeout ()
      :timeout)))

(defun hang ()
  (join-thread *current-thread*))

(defun kill-thread (thread)
  (when (thread-alive-p thread)
    (ignore-errors
      (terminate-thread thread))))

) ;; #+sb-thread (progn ...