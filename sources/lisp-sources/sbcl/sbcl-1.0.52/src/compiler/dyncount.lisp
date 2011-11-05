;;;; support for collecting dynamic vop statistics

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; This software is derived from the CMU CL system, which was
;;;; written at Carnegie Mellon University and released into the
;;;; public domain. The software is in the public domain and is
;;;; provided with absolutely no warranty. See the COPYING and CREDITS
;;;; files for more information.

(in-package "SB!DYNCOUNT")

(defvar *collect-dynamic-statistics* nil
  #!+sb-doc
  "When T, emit extra code to collect dynamic statistics about vop usages.")

(defvar *dynamic-counts-tn* nil
  #!+sb-doc
  "Holds the TN for the counts vector.")

(def!struct (dyncount-info (:make-load-form-fun just-dump-it-normally))
  for
  (costs (missing-arg) :type (simple-array (unsigned-byte 32) (*)))
  (counts (missing-arg) :type (simple-array (unsigned-byte 32) (*))))

(defprinter (dyncount-info)
  for
  costs
  counts)
