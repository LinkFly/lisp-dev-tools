;;;; Lock-free mailbox implementation using SB-QUEUE.
;;;;
;;;; Written by Nikodemus Siivola for SBCL.
;;;; Extended by Tobias C Rittweiler.
;;;;
;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; This software is derived from the CMU CL system, which was written at
;;;; Carnegie Mellon University and released into the public domain. The
;;;; software is in the public domain and is provided with absolutely no
;;;; warranty. See the COPYING and CREDITS files for more information.

(in-package :sb-concurrency)

;; TODO: type and values decls

(defstruct (mailbox (:constructor %make-mailbox (queue semaphore name))
                    (:copier nil)
                    (:predicate mailboxp))
  "Mailbox aka message queue."
  (queue (missing-arg) :type queue)
  (semaphore (missing-arg) :type semaphore)
  (name nil))

(setf (documentation 'mailboxp 'function)
      "Returns true if argument is a MAILBOX, NIL otherwise."
      (documentation 'mailbox-name 'function)
      "Name of a MAILBOX. SETFable.")

(defun make-mailbox (&key name initial-contents)
  "Returns a new MAILBOX with messages in INITIAL-CONTENTS enqueued."
  (flet ((genname (thing name)
           (format nil "~:[Mailbox ~A~;~A for mailbox ~S~]" name thing name)))
    (%make-mailbox (make-queue
                    :name (genname "Queue" name)
                    :initial-contents initial-contents)
                   (make-semaphore
                    :name (genname "Semaphore" name)
                    :count (length initial-contents))
                   name)))

(defmethod print-object ((mailbox mailbox) stream)
  (print-unreadable-object (mailbox stream :type t :identity t)
    (format stream "~@[~S ~](~D msgs pending)"
            (mailbox-name mailbox)
            (mailbox-count mailbox)))
  mailbox)

(defun mailbox-count (mailbox)
  "Returns the number of messages currently in the mailbox."
  (semaphore-count (mailbox-semaphore mailbox)))

(defun mailbox-empty-p (mailbox)
  "Returns true if MAILBOX is currently empty, NIL otherwise."
  (zerop (mailbox-count mailbox)))

(defun list-mailbox-messages (mailbox)
  "Returns a fresh list containing all the messages in the
mailbox. Does not remove messages from the mailbox."
  (list-queue-contents (mailbox-queue mailbox)))

(defun send-message (mailbox message)
  "Adds a MESSAGE to MAILBOX. Message can be any object."
  (sb-sys:without-interrupts
    (enqueue message (mailbox-queue mailbox))
    (signal-semaphore (mailbox-semaphore mailbox))))

;;; TODO: TIMEOUT argument.
(defun receive-message (mailbox &key)
  "Removes the oldest message from MAILBOX and returns it as the
primary value. If MAILBOX is empty waits until a message arrives."
  (tagbody
     ;; Disable interrupts for keeping semaphore count in sync with
     ;; #msgs in the mailbox.
     (sb-sys:without-interrupts
       (sb-sys:allow-with-interrupts
         (wait-on-semaphore (mailbox-semaphore mailbox)))
       (multiple-value-bind (value ok) (dequeue (mailbox-queue mailbox))
         (if ok
             (return-from receive-message value)
             (go :error))))
   :error
     (sb-int:bug "Mailbox ~S empty after WAIT-ON-SEMAPHORE."
                 mailbox)))

(defun receive-message-no-hang (mailbox)
  "The non-blocking variant of RECEIVE-MESSAGE. Returns two values,
the message removed from MAILBOX, and a flag specifying whether a
message could be received."
  (prog ((semaphore (mailbox-semaphore mailbox))
         (queue     (mailbox-queue mailbox)))
     ;; Disable interrupts, v.s.
     (sb-sys:without-interrupts
       (unless (sb-sys:allow-with-interrupts
                 (sb-thread::try-semaphore semaphore))
         (return (values nil nil)))
       (multiple-value-bind (value ok) (dequeue queue)
         (if ok
             (return (values value t))
             (go :error))))
   :error
     (sb-int:bug "Mailbox ~S empty after successfull TRY-SEMAPHORE."
                 mailbox)))

(defun receive-pending-messages (mailbox &optional n)
  "Removes and returns all (or at most N) currently pending messages
from MAILBOX, or returns NIL if no messages are pending.

Note: Concurrent threads may be snarfing messages during the run of
this function, so even though X,Y appear right next to each other in
the result, does not necessarily mean that Y was the message sent
right after X."
  (prog* ((msgs  '())
          (sem   (mailbox-semaphore mailbox))
          (queue (mailbox-queue mailbox))
          (avail (mailbox-count mailbox))
          (count (if n (min n avail) avail)))
     (when (zerop count)
       (go :finish))
     ;; Disable interrupts, v.s.
     (sb-sys:without-interrupts
       (unless (sb-sys:allow-with-interrupts
                 (sb-thread::try-semaphore sem count))
         (go :slow-path))
       ;; Safe because QUEUE is private; other threads may be snarfing
       ;; messages under our feet, though, hence the out of order bit
       ;; in the docstring. Same for the slow path.
       (loop
         (multiple-value-bind (msg ok) (dequeue queue)
           (unless ok (go :error))
           (push msg msgs)
           (when (zerop (decf count))
             (go :finish)))))
   ;; This is the slow path as RECEIVE-MESSAGE-NO-HANG will have to
   ;; lock the semaphore's mutex again and again.
   :slow-path
     ;; No need for disabling interrupts because we never leave the
     ;; mailbox in an inconsistent state here.
     (loop
       (multiple-value-bind (msg ok)
           (receive-message-no-hang mailbox)
         (unless ok (go :finish))
         (push msg msgs)
         (when (zerop (decf count))
           (go :finish))))
   :finish
       (return (nreverse msgs))
   :error
       (sb-int:bug "Mailbox ~S empty after successfull TRY-SEMAPHORE."
                   mailbox)))
