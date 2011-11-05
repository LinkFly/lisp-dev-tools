;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; This software is derived from the CMU CL system, which was
;;;; written at Carnegie Mellon University and released into the
;;;; public domain. The software is in the public domain and is
;;;; provided with absolutely no warranty. See the COPYING and CREDITS
;;;; files for more information.

(in-package "SB!IMPL")

(defmacro-mundanely destructuring-bind (lambda-list expression &body body)
  #!+sb-doc
  "Bind the variables in LAMBDA-LIST to the corresponding values in the
tree structure resulting from the evaluation of EXPRESSION."
  (let ((whole-name (gensym "WHOLE")))
    (multiple-value-bind (body local-decls)
        (parse-defmacro lambda-list whole-name body nil 'destructuring-bind
                        :anonymousp t
                        :doc-string-allowed nil
                        :wrap-block nil)
      `(let ((,whole-name ,expression))
         ;; This declaration-as-assertion should protect us from
         ;; (DESTRUCTURING-BIND (X . Y) 'NOT-A-LIST ...).
         (declare (type list ,whole-name))
         ,@local-decls
         ,body))))
