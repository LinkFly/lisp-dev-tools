;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; This software is derived from the CMU CL system, which was
;;;; written at Carnegie Mellon University and released into the
;;;; public domain. The software is in the public domain and is
;;;; provided with absolutely no warranty. See the COPYING and CREDITS
;;;; files for more information.

(in-package "SB-COLD")

;;; Either load or compile-then-load the cross-compiler into the
;;; cross-compilation host Common Lisp.
(defun load-or-cload-xcompiler (load-or-cload-stem)

  (declare (type function load-or-cload-stem))

  ;; The running-in-the-host-Lisp Python cross-compiler defines its
  ;; own versions of a number of functions which should not overwrite
  ;; host-Lisp functions. Instead we put them in a special package.
  ;;
  ;; The common theme of the functions, macros, constants, and so
  ;; forth in this package is that they run in the host and affect the
  ;; compilation of the target.
  (let ((package-name "SB-XC"))
    (make-package package-name :use nil :nicknames nil)
    (dolist (name '(;; the constants (except for T and NIL which have
                    ;; a specially hacked correspondence between
                    ;; cross-compilation host Lisp and target Lisp)
                    "ARRAY-DIMENSION-LIMIT"
                    "ARRAY-RANK-LIMIT"
                    "ARRAY-TOTAL-SIZE-LIMIT"
                    "BOOLE-1"
                    "BOOLE-2"
                    "BOOLE-AND"
                    "BOOLE-ANDC1"
                    "BOOLE-ANDC2"
                    "BOOLE-C1"
                    "BOOLE-C2"
                    "BOOLE-CLR"
                    "BOOLE-EQV"
                    "BOOLE-IOR"
                    "BOOLE-NAND"
                    "BOOLE-NOR"
                    "BOOLE-ORC1"
                    "BOOLE-ORC2"
                    "BOOLE-SET"
                    "BOOLE-XOR"
                    "CALL-ARGUMENTS-LIMIT"
                    "CHAR-CODE-LIMIT"
                    "DOUBLE-FLOAT-EPSILON"
                    "DOUBLE-FLOAT-NEGATIVE-EPSILON"
                    "INTERNAL-TIME-UNITS-PER-SECOND"
                    "LAMBDA-LIST-KEYWORDS"
                    "LAMBDA-PARAMETERS-LIMIT"
                    "LEAST-NEGATIVE-DOUBLE-FLOAT"
                    "LEAST-NEGATIVE-LONG-FLOAT"
                    "LEAST-NEGATIVE-NORMALIZED-DOUBLE-FLOAT"
                    "LEAST-NEGATIVE-NORMALIZED-LONG-FLOAT"
                    "LEAST-NEGATIVE-NORMALIZED-SHORT-FLOAT"
                    "LEAST-NEGATIVE-NORMALIZED-SINGLE-FLOAT"
                    "LEAST-NEGATIVE-SHORT-FLOAT"
                    "LEAST-NEGATIVE-SINGLE-FLOAT"
                    "LEAST-POSITIVE-DOUBLE-FLOAT"
                    "LEAST-POSITIVE-LONG-FLOAT"
                    "LEAST-POSITIVE-NORMALIZED-DOUBLE-FLOAT"
                    "LEAST-POSITIVE-NORMALIZED-LONG-FLOAT"
                    "LEAST-POSITIVE-NORMALIZED-SHORT-FLOAT"
                    "LEAST-POSITIVE-NORMALIZED-SINGLE-FLOAT"
                    "LEAST-POSITIVE-SHORT-FLOAT"
                    "LEAST-POSITIVE-SINGLE-FLOAT"
                    "LONG-FLOAT-EPSILON"
                    "LONG-FLOAT-NEGATIVE-EPSILON"
                    "MOST-NEGATIVE-DOUBLE-FLOAT"
                    "MOST-NEGATIVE-FIXNUM"
                    "MOST-NEGATIVE-LONG-FLOAT"
                    "MOST-NEGATIVE-SHORT-FLOAT"
                    "MOST-NEGATIVE-SINGLE-FLOAT"
                    "MOST-POSITIVE-DOUBLE-FLOAT"
                    "MOST-POSITIVE-FIXNUM"
                    "MOST-POSITIVE-LONG-FLOAT"
                    "MOST-POSITIVE-SHORT-FLOAT"
                    "MOST-POSITIVE-SINGLE-FLOAT"
                    "MULTIPLE-VALUES-LIMIT"
                    "PI"
                    "SHORT-FLOAT-EPSILON"
                    "SHORT-FLOAT-NEGATIVE-EPSILON"
                    "SINGLE-FLOAT-EPSILON"
                    "SINGLE-FLOAT-NEGATIVE-EPSILON"

                    ;; everything else which needs a separate
                    ;; existence in xc and target
                    "BOOLE"
                    "BOOLE-CLR" "BOOLE-SET" "BOOLE-1" "BOOLE-2"
                    "BOOLE-C1" "BOOLE-C2" "BOOLE-AND" "BOOLE-IOR"
                    "BOOLE-XOR" "BOOLE-EQV" "BOOLE-NAND" "BOOLE-NOR"
                    "BOOLE-ANDC1" "BOOLE-ANDC2" "BOOLE-ORC1" "BOOLE-ORC2"
                    "BUILT-IN-CLASS"
                    "BYTE" "BYTE-POSITION" "BYTE-SIZE"
                    "CHAR-CODE"
                    "CLASS" "CLASS-NAME" "CLASS-OF"
                    "CODE-CHAR"
                    "COMPILE-FILE"
                    "COMPILE-FILE-PATHNAME"
                    "*COMPILE-FILE-PATHNAME*"
                    "*COMPILE-FILE-TRUENAME*"
                    "*COMPILE-PRINT*"
                    "*COMPILE-VERBOSE*"
                    "COMPILER-MACRO-FUNCTION"
                    "CONSTANTP"
                    "DEFCONSTANT"
                    "DEFINE-MODIFY-MACRO"
                    "DEFINE-SETF-EXPANDER"
                    "DEFMACRO" "DEFSETF" "DEFSTRUCT" "DEFTYPE"
                    "DEPOSIT-FIELD" "DPB"
                    "FBOUNDP" "FDEFINITION" "FMAKUNBOUND"
                    "FIND-CLASS"
                    "GENSYM" "*GENSYM-COUNTER*"
                    "GET-SETF-EXPANSION"
                    "LDB" "LDB-TEST"
                    "LISP-IMPLEMENTATION-TYPE" "LISP-IMPLEMENTATION-VERSION"
                    "MACRO-FUNCTION"
                    "MACROEXPAND" "MACROEXPAND-1" "*MACROEXPAND-HOOK*"
                    "MAKE-LOAD-FORM"
                    "MAKE-LOAD-FORM-SAVING-SLOTS"
                    "MASK-FIELD"
                    "PACKAGE" "PACKAGEP"
                    "PROCLAIM"
                    "SPECIAL-OPERATOR-P"
                    "STANDARD-CLASS"
                    "STRUCTURE-CLASS"
                    "SUBTYPEP"
                    "TYPE-OF" "TYPEP"
                    "UPGRADED-ARRAY-ELEMENT-TYPE"
                    "UPGRADED-COMPLEX-PART-TYPE"
                    "WITH-COMPILATION-UNIT"))
      (export (intern name package-name) package-name)))
  ;; don't watch:
  (dolist (package (list-all-packages))
    (when (= (mismatch (package-name package) "SB!") 3)
      (shadowing-import
       (mapcar (lambda (name) (find-symbol name "SB-XC"))
               '("BYTE" "BYTE-POSITION" "BYTE-SIZE"
                 "DPB" "LDB" "LDB-TEST"
                 "DEPOSIT-FIELD" "MASK-FIELD"

                 "BOOLE"
                 "BOOLE-CLR" "BOOLE-SET" "BOOLE-1" "BOOLE-2"
                 "BOOLE-C1" "BOOLE-C2" "BOOLE-AND" "BOOLE-IOR"
                 "BOOLE-XOR" "BOOLE-EQV" "BOOLE-NAND" "BOOLE-NOR"
                 "BOOLE-ANDC1" "BOOLE-ANDC2" "BOOLE-ORC1" "BOOLE-ORC2"))
       package)))

  ;; Build a version of Python to run in the host Common Lisp, to be
  ;; used only in cross-compilation.
  ;;
  ;; Note that files which are marked :ASSEM, to cause them to be
  ;; processed with SB!C:ASSEMBLE-FILE when we're running under the
  ;; cross-compiler or the target lisp, are still processed here, just
  ;; with the ordinary Lisp compiler, and this is intentional, in
  ;; order to make the compiler aware of the definitions of assembly
  ;; routines.
  (do-stems-and-flags (stem flags)
    (unless (find :not-host flags)
      (funcall load-or-cload-stem stem flags)
      #!+sb-show (warn-when-cl-snapshot-diff *cl-snapshot*)))

  ;; If the cross-compilation host is SBCL itself, we can use the
  ;; PURIFY extension to freeze everything in place, reducing the
  ;; amount of work done on future GCs. In machines with limited
  ;; memory, this could help, by reducing the amount of memory which
  ;; needs to be juggled in a full GC. And it can hardly hurt, since
  ;; (in the ordinary build procedure anyway) essentially everything
  ;; which is reachable at this point will remain reachable for the
  ;; entire run.
  ;;
  ;; (Except that purifying actually slows down GENCGC). -- JES, 2006-05-30
  #+(and sbcl (not gencgc))
  (sb-ext:purify)

  (values))
