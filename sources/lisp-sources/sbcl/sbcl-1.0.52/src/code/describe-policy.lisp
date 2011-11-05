;;;; DESCRIBE-COMPILER-POLICY

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; This software is derived from the CMU CL system, which was
;;;; written at Carnegie Mellon University and released into the
;;;; public domain. The software is in the public domain and is
;;;; provided with absolutely no warranty. See the COPYING and CREDITS
;;;; files for more information.

(in-package "SB-C") ;(SB-C, not SB!C, since we're built in warm load.)

(defun describe-compiler-policy (&optional spec)
  #+sb-doc
  "Print all global optimization settings, augmented by SPEC."
  (let ((policy (process-optimize-decl (cons 'optimize spec) *policy*)))
    (fresh-line)
    (format t "  Basic qualities:~%")
    (dolist (quality *policy-qualities*)
      (format t "~S = ~D~%" quality (policy-quality policy quality)))
    (format t "  Dependent qualities:~%")
    (loop for (name . info) in *policy-dependent-qualities*
       for values-documentation = (policy-dependent-quality-values-documentation info)
       for explicit-value = (policy-quality policy name)
       do (if (= explicit-value 1)
              (let* ((getter (policy-dependent-quality-getter info))
                     (value (funcall getter policy))
                     (documentation (elt values-documentation value)))
                (format t "~S = ~D -> ~D (~A)~%"
                        name explicit-value
                        value documentation))
              (let ((documentation (elt values-documentation explicit-value)))
                (format t "~S = ~D (~A)~%"
                        name explicit-value documentation)))))

  (values))
