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
(use-package "ASSERTOID")

;;;; examples from, or close to, the Common Lisp DEFSTRUCT spec

;;; Type mismatch of slot default init value isn't an error until the
;;; default init value is actually used. (The justification is
;;; somewhat bogus, but the requirement is clear.)
(defstruct person age (name 007 :type string)) ; not an error until 007 used
(make-person :name "James") ; not an error, 007 not used

#+#.(cl:if (cl:eq sb-ext:*evaluator-mode* :compile) '(and) '(or))
(assert (raises-error? (make-person) type-error))
#+#.(cl:if (cl:eq sb-ext:*evaluator-mode* :compile) '(and) '(or))
(assert (raises-error? (setf (person-name (make-person :name "Q")) 1)
                       type-error))

;;; An &AUX variable in a boa-constructor without a default value
;;; means "do not initialize slot" and does not cause type error
(declaim (notinline opaque-identity))
(defun opaque-identity (x) x)

(defstruct (boa-saux (:constructor make-boa-saux (&aux a (b 3) (c))))
    (a #\! :type (integer 1 2))
    (b #\? :type (integer 3 4))
    (c #\# :type (integer 5 6)))
(let ((s (make-boa-saux)))
  (locally (declare (optimize (safety 3))
                    (inline boa-saux-a))
    (assert (raises-error? (opaque-identity (boa-saux-a s)) type-error)))
  (setf (boa-saux-a s) 1)
  (setf (boa-saux-c s) 5)
  (assert (eql (boa-saux-a s) 1))
  (assert (eql (boa-saux-b s) 3))
  (assert (eql (boa-saux-c s) 5)))
                                        ; these two checks should be
                                        ; kept separated

#+#.(cl:if (cl:eq sb-ext:*evaluator-mode* :compile) '(and) '(or))
(let ((s (make-boa-saux)))
  (locally (declare (optimize (safety 0))
                    (inline boa-saux-a))
    (assert (eql (opaque-identity (boa-saux-a s)) 0)))
  (setf (boa-saux-a s) 1)
  (setf (boa-saux-c s) 5)
  (assert (eql (boa-saux-a s) 1))
  (assert (eql (boa-saux-b s) 3))
  (assert (eql (boa-saux-c s) 5)))

(let ((s (make-boa-saux)))
  (locally (declare (optimize (safety 3))
                    (notinline boa-saux-a))
    (assert (raises-error? (opaque-identity (boa-saux-a s)) type-error)))
  (setf (boa-saux-a s) 1)
  (setf (boa-saux-c s) 5)
  (assert (eql (boa-saux-a s) 1))
  (assert (eql (boa-saux-b s) 3))
  (assert (eql (boa-saux-c s) 5)))

;;; basic inheritance
(defstruct (astronaut (:include person)
                      (:conc-name astro-))
  helmet-size
  (favorite-beverage 'tang))
(let ((x (make-astronaut :name "Buzz" :helmet-size 17.5)))
  (assert (equal (person-name x) "Buzz"))
  (assert (equal (astro-name x) "Buzz"))
  (assert (eql (astro-favorite-beverage x) 'tang))
  (assert (null (astro-age x))))
(defstruct (ancient-astronaut (:include person (age 77)))
  helmet-size
  (favorite-beverage 'tang))
(assert (eql (ancient-astronaut-age (make-ancient-astronaut :name "John")) 77))

;;; interaction of :TYPE and :INCLUDE and :INITIAL-OFFSET
(defstruct (binop (:type list) :named (:initial-offset 2))
  (operator '? :type symbol)
  operand-1
  operand-2)
(defstruct (annotated-binop (:type list)
                            (:initial-offset 3)
                            (:include binop))
  commutative associative identity)
(assert (equal (make-annotated-binop :operator '*
                                     :operand-1 'x
                                     :operand-2 5
                                     :commutative t
                                     :associative t
                                     :identity 1)
               '(nil nil binop * x 5 nil nil nil t t 1)))

;;; effect of :NAMED on :TYPE
(defstruct (named-binop (:type list) :named)
  (operator '? :type symbol)
  operand-1
  operand-2)
(let ((named-binop (make-named-binop :operator '+ :operand-1 'x :operand-2 5)))
  ;; The data representation is specified to look like this.
  (assert (equal named-binop '(named-binop + x 5)))
  ;; A meaningful NAMED-BINOP-P is defined.
  (assert (named-binop-p named-binop))
  (assert (named-binop-p (copy-list named-binop)))
  (assert (not (named-binop-p (cons 11 named-binop))))
  (assert (not (named-binop-p (find-package :cl)))))

;;; example 1
(defstruct town
  area
  watertowers
  (firetrucks 1 :type fixnum)
  population
  (elevation 5128 :read-only t))
(let ((town1 (make-town :area 0 :watertowers 0)))
  (assert (town-p town1))
  (assert (not (town-p 1)))
  (assert (eql (town-area town1) 0))
  (assert (eql (town-elevation town1) 5128))
  (assert (null (town-population town1)))
  (setf (town-population town1) 99)
  (assert (eql (town-population town1) 99))
  (let ((town2 (copy-town town1)))
    (dolist (slot-accessor-name '(town-area
                                  town-watertowers
                                  town-firetrucks
                                  town-population
                                  town-elevation))
      (assert (eql (funcall slot-accessor-name town1)
                   (funcall slot-accessor-name town2))))
    (assert (not (fboundp '(setf town-elevation)))))) ; 'cause it's :READ-ONLY

;;; example 2
(defstruct (clown (:conc-name bozo-))
  (nose-color 'red)
  frizzy-hair-p
  polkadots)
(let ((funny-clown (make-clown)))
  (assert (eql (bozo-nose-color funny-clown) 'red)))
(defstruct (klown (:constructor make-up-klown)
                  (:copier clone-klown)
                  (:predicate is-a-bozo-p))
  nose-color
  frizzy-hair-p
  polkadots)
(assert (is-a-bozo-p (make-up-klown)))

;;;; systematically testing variants of DEFSTRUCT:
;;;;   * native, :TYPE LIST, and :TYPE VECTOR

;;; FIXME: things to test:
;;;   * Slot readers work.
;;;   * Slot writers work.
;;;   * Predicates work.

;;; FIXME: things that would be nice to test systematically someday:
;;;   * constructors (default, boa..)
;;;   * copiers
;;;   * no type checks when (> SPEED SAFETY)
;;;   * Tests of inclusion would be good. (It's tested very lightly
;;;     above, and then tested a fair amount by the system compiling
;;;     itself.)

(defun string+ (&rest rest)
  (apply #'concatenate 'string
         (mapcar #'string rest)))
(defun symbol+ (&rest rest)
  (values (intern (apply #'string+ rest))))

(defun accessor-name (conc-name slot-name)
  (symbol+ conc-name slot-name))

;;; Use the ordinary FDEFINITIONs of accessors (not inline expansions)
;;; to read and write a structure slot.
(defun read-slot-notinline (conc-name slot-name instance)
  (funcall (accessor-name conc-name slot-name) instance))
(defun write-slot-notinline (new-value conc-name slot-name instance)
  (funcall (fdefinition `(setf ,(accessor-name conc-name slot-name)))
           new-value instance))

;;; Use inline expansions of slot accessors, if possible, to read and
;;; write a structure slot.
(defun read-slot-inline (conc-name slot-name instance)
  (funcall (compile nil
                    `(lambda (instance)
                       (,(accessor-name conc-name slot-name) instance)))
           instance))
(defun write-slot-inline (new-value conc-name slot-name instance)
  (funcall (compile nil
                    `(lambda (new-value instance)
                       (setf (,(accessor-name conc-name slot-name) instance)
                             new-value)))
           new-value
           instance))

;;; Read a structure slot, checking that the inline and out-of-line
;;; accessors give the same result.
(defun read-slot (conc-name slot-name instance)
  (let ((inline-value (read-slot-inline conc-name slot-name instance))
        (notinline-value (read-slot-notinline conc-name slot-name instance)))
    (assert (eql inline-value notinline-value))
    inline-value))

;;; Write a structure slot, using INLINEP argument to decide
;;; on inlineness of accessor used.
(defun write-slot (new-value conc-name slot-name instance inlinep)
  (if inlinep
      (write-slot-inline new-value conc-name slot-name instance)
      (write-slot-notinline new-value conc-name slot-name instance)))

;;; bound during the tests so that we can get to it even if the
;;; debugger is having a bad day
(defvar *instance*)

(declaim (optimize (debug 2)))

(defmacro test-variant (defstructname &key colontype boa-constructor-p)
  `(progn

     (format t "~&/beginning PROGN for COLONTYPE=~S~%" ',colontype)

     (defstruct (,defstructname
                  ,@(when colontype `((:type ,colontype)))
                  ,@(when boa-constructor-p
                          `((:constructor ,(symbol+ "CREATE-" defstructname)
                             (id
                              &optional
                              (optional-test 2 optional-test-p)
                              &key
                              (home nil home-p)
                              (no-home-comment "Home package CL not provided.")
                              (comment (if home-p "" no-home-comment))
                              (refcount (if optional-test-p optional-test nil))
                              hash
                              weight)))))

       ;; some ordinary tagged slots
       id
       (home nil :type package :read-only t)
       (comment "" :type simple-string)
       ;; some raw slots
       (weight 1.0 :type single-float)
       (hash 1 :type (integer 1 #.(* 3 most-positive-fixnum)) :read-only t)
       ;; more ordinary tagged slots
       (refcount 0 :type (and unsigned-byte fixnum)))

     (format t "~&/done with DEFSTRUCT~%")

     (let* ((cn (string+ ',defstructname "-")) ; conc-name
            (ctor (symbol-function ',(symbol+ (if boa-constructor-p
                                               "CREATE-"
                                               "MAKE-")
                                             defstructname)))
            (*instance* (funcall ctor
                                 ,@(unless boa-constructor-p
                                           `(:id)) "some id"
                                 ,@(when boa-constructor-p
                                         '(1))
                                 :home (find-package :cl)
                                 :hash (+ 14 most-positive-fixnum)
                                 ,@(unless boa-constructor-p
                                           `(:refcount 1)))))

       ;; Check that ctor set up slot values correctly.
       (format t "~&/checking constructed structure~%")
       (assert (string= "some id" (read-slot cn "ID" *instance*)))
       (assert (eql (find-package :cl) (read-slot cn "HOME" *instance*)))
       (assert (string= "" (read-slot cn "COMMENT" *instance*)))
       (assert (= 1.0 (read-slot cn "WEIGHT" *instance*)))
       (assert (eql (+ 14 most-positive-fixnum)
                    (read-slot cn "HASH" *instance*)))
       (assert (= 1 (read-slot cn "REFCOUNT" *instance*)))

       ;; There should be no writers for read-only slots.
       (format t "~&/checking no read-only writers~%")
       (assert (not (fboundp `(setf ,(symbol+ cn "HOME")))))
       (assert (not (fboundp `(setf ,(symbol+ cn "HASH")))))
       ;; (Read-only slot values are checked in the loop below.)

       (dolist (inlinep '(t nil))
         (format t "~&/doing INLINEP=~S~%" inlinep)
         ;; Fiddle with writable slot values.
         (let ((new-id (format nil "~S" (random 100)))
               (new-comment (format nil "~X" (random 5555)))
               (new-weight (random 10.0)))
           (write-slot new-id cn "ID" *instance* inlinep)
           (write-slot new-comment cn "COMMENT" *instance* inlinep)
           (write-slot new-weight cn "WEIGHT" *instance* inlinep)
           (assert (eql new-id (read-slot cn "ID" *instance*)))
           (assert (eql new-comment (read-slot cn "COMMENT" *instance*)))
           ;;(unless (eql new-weight (read-slot cn "WEIGHT" *instance*))
           ;;  (error "WEIGHT mismatch: ~S vs. ~S"
           ;;         new-weight (read-slot cn "WEIGHT" *instance*)))
           (assert (eql new-weight (read-slot cn "WEIGHT" *instance*)))))
       (format t "~&/done with INLINEP loop~%")

       ;; :TYPE FOO objects don't go in the Lisp type system, so we
       ;; can't test TYPEP stuff for them.
       ;;
       ;; FIXME: However, when they're named, they do define
       ;; predicate functions, and we could test those.
       ,@(unless colontype
           `(;; Fiddle with predicate function.
             (let ((pred-name (symbol+ ',defstructname "-P")))
               (format t "~&/doing tests on PRED-NAME=~S~%" pred-name)
               (assert (funcall pred-name *instance*))
               (assert (not (funcall pred-name 14)))
               (assert (not (funcall pred-name "test")))
               (assert (not (funcall pred-name (make-hash-table))))
               (let ((compiled-pred
                      (compile nil `(lambda (x) (,pred-name x)))))
                 (format t "~&/doing COMPILED-PRED tests~%")
                 (assert (funcall compiled-pred *instance*))
                 (assert (not (funcall compiled-pred 14)))
                 (assert (not (funcall compiled-pred #()))))
               ;; Fiddle with TYPEP.
               (format t "~&/doing TYPEP tests, COLONTYPE=~S~%" ',colontype)
               (assert (typep *instance* ',defstructname))
               (assert (not (typep 0 ',defstructname)))
               (assert (funcall (symbol+ "TYPEP") *instance* ',defstructname))
               (assert (not (funcall (symbol+ "TYPEP") nil ',defstructname)))
               (let* ((typename ',defstructname)
                      (compiled-typep
                       (compile nil `(lambda (x) (typep x ',typename)))))
                 (assert (funcall compiled-typep *instance*))
                 (assert (not (funcall compiled-typep nil))))))))

     (format t "~&/done with PROGN for COLONTYPE=~S~%" ',colontype)))

(test-variant vanilla-struct)
(test-variant vector-struct :colontype vector)
(test-variant list-struct :colontype list)
(test-variant vanilla-struct :boa-constructor-p t)
(test-variant vector-struct :colontype vector :boa-constructor-p t)
(test-variant list-struct :colontype list :boa-constructor-p t)


;;;; testing raw slots harder
;;;;
;;;; The offsets of raw slots need to be rescaled during the punning
;;;; process which is used to access them. That seems like a good
;;;; place for errors to lurk, so we'll try hunting for them by
;;;; verifying that all the raw slot data gets written successfully
;;;; into the object, can be copied with the object, and can then be
;;;; read back out (with none of it ending up bogusly outside the
;;;; object, so that it couldn't be copied, or bogusly overwriting
;;;; some other raw slot).

(defstruct manyraw
  (a (expt 2 30) :type (unsigned-byte #.sb-vm:n-word-bits))
  (b 0.1 :type single-float)
  (c 0.2d0 :type double-float)
  (d #c(0.3 0.3) :type (complex single-float))
  unraw-slot-just-for-variety
  (e #c(0.4d0 0.4d0) :type (complex double-float))
  (aa (expt 2 30) :type (unsigned-byte #.sb-vm:n-word-bits))
  (bb 0.1 :type single-float)
  (cc 0.2d0 :type double-float)
  (dd #c(0.3 0.3) :type (complex single-float))
  (ee #c(0.4d0 0.4d0) :type (complex double-float)))

(defvar *manyraw* (make-manyraw))

(assert (eql (manyraw-a *manyraw*) (expt 2 30)))
(assert (eql (manyraw-b *manyraw*) 0.1))
(assert (eql (manyraw-c *manyraw*) 0.2d0))
(assert (eql (manyraw-d *manyraw*) #c(0.3 0.3)))
(assert (eql (manyraw-e *manyraw*) #c(0.4d0 0.4d0)))
(assert (eql (manyraw-aa *manyraw*) (expt 2 30)))
(assert (eql (manyraw-bb *manyraw*) 0.1))
(assert (eql (manyraw-cc *manyraw*) 0.2d0))
(assert (eql (manyraw-dd *manyraw*) #c(0.3 0.3)))
(assert (eql (manyraw-ee *manyraw*) #c(0.4d0 0.4d0)))

(setf (manyraw-aa *manyraw*) (expt 2 31)
      (manyraw-bb *manyraw*) 0.11
      (manyraw-cc *manyraw*) 0.22d0
      (manyraw-dd *manyraw*) #c(0.33 0.33)
      (manyraw-ee *manyraw*) #c(0.44d0 0.44d0))

(let ((copy (copy-manyraw *manyraw*)))
  (assert (eql (manyraw-a copy) (expt 2 30)))
  (assert (eql (manyraw-b copy) 0.1))
  (assert (eql (manyraw-c copy) 0.2d0))
  (assert (eql (manyraw-d copy) #c(0.3 0.3)))
  (assert (eql (manyraw-e copy) #c(0.4d0 0.4d0)))
  (assert (eql (manyraw-aa copy) (expt 2 31)))
  (assert (eql (manyraw-bb copy) 0.11))
  (assert (eql (manyraw-cc copy) 0.22d0))
  (assert (eql (manyraw-dd copy) #c(0.33 0.33)))
  (assert (eql (manyraw-ee copy) #c(0.44d0 0.44d0))))


;;;; Since GC treats raw slots specially now, let's try this with more objects
;;;; and random values as a stress test.

(setf *manyraw* nil)

(defconstant +n-manyraw+ 10)
(defconstant +m-manyraw+ 1000)

(defun check-manyraws (manyraws)
  (assert (eql (length manyraws) (* +n-manyraw+ +m-manyraw+)))
  (loop
      for m in (reverse manyraws)
      for i from 0
      do
        ;; Compare the tagged reference values with raw reffer results.
        (destructuring-bind (j a b c d e)
            (manyraw-unraw-slot-just-for-variety m)
          (assert (eql i j))
          (assert (= (manyraw-a m) a))
          (assert (= (manyraw-b m) b))
          (assert (= (manyraw-c m) c))
          (assert (= (manyraw-d m) d))
          (assert (= (manyraw-e m) e)))
        ;; Test the funny out-of-line OAOOM-style closures, too.
        (mapcar (lambda (fn value)
                  (assert (= (funcall fn m) value)))
                (list #'manyraw-a
                      #'manyraw-b
                      #'manyraw-c
                      #'manyraw-d
                      #'manyraw-e)
                (cdr (manyraw-unraw-slot-just-for-variety m)))))

(defstruct (manyraw-subclass (:include manyraw))
  (stolperstein 0 :type (unsigned-byte 32)))

;;; create lots of manyraw objects, triggering GC every now and then
(dotimes (y +n-manyraw+)
  (dotimes (x +m-manyraw+)
    (let ((a (random (expt 2 32)))
          (b (random most-positive-single-float))
          (c (random most-positive-double-float))
          (d (complex
              (random most-positive-single-float)
              (random most-positive-single-float)))
          (e (complex
              (random most-positive-double-float)
              (random most-positive-double-float))))
      (push (funcall (if (zerop (mod x 3))
                         #'make-manyraw-subclass
                         #'make-manyraw)
                     :unraw-slot-just-for-variety
                     (list (+ x (* y +m-manyraw+)) a b c d e)
                     :a a
                     :b b
                     :c c
                     :d d
                     :e e)
            *manyraw*)))
  (room)
  (sb-ext:gc))
(with-test (:name defstruct-raw-slot-gc)
  (check-manyraws *manyraw*))

;;; try a full GC, too
(sb-ext:gc :full t)
(with-test (:name (defstruct-raw-slot-gc :full))
  (check-manyraws *manyraw*))

;;; fasl dumper and loader also have special handling of raw slots, so
;;; dump all of them into a fasl
(defmethod make-load-form ((self manyraw) &optional env)
  self env
  :sb-just-dump-it-normally)
(with-open-file (s "tmp-defstruct.manyraw.lisp"
                 :direction :output
                 :if-exists :supersede)
  (write-string "(defun dumped-manyraws () '#.*manyraw*)" s))
(compile-file "tmp-defstruct.manyraw.lisp")
(delete-file "tmp-defstruct.manyraw.lisp")

;;; nuke the objects and try another GC just to be extra careful
(setf *manyraw* nil)
(sb-ext:gc :full t)

;;; re-read the dumped structures and check them
(load "tmp-defstruct.manyraw.fasl")
(with-test (:name (defstruct-raw-slot load))
  (check-manyraws (dumped-manyraws)))


;;;; miscellaneous old bugs

(defstruct ya-struct)
(when (ignore-errors (or (ya-struct-p) 12))
  (error "YA-STRUCT-P of no arguments should signal an error."))
(when (ignore-errors (or (ya-struct-p 'too 'many 'arguments) 12))
  (error "YA-STRUCT-P of three arguments should signal an error."))

;;; bug 210: Until sbcl-0.7.8.32 BOA constructors had SAFETY 0
;;; declared inside on the theory that slot types were already
;;; checked, which bogusly suppressed unbound-variable and other
;;; checks within the evaluation of initforms.
(defvar *bug210*)
(defstruct (bug210a (:constructor bug210a ()))
  (slot *bug210*))
(defstruct bug210b
  (slot *bug210*))
;;; Because of bug 210, this assertion used to fail.
(assert (typep (nth-value 1 (ignore-errors (bug210a))) 'unbound-variable))
;;; Even with bug 210, these assertions succeeded.
(assert (typep (nth-value 1 (ignore-errors *bug210*)) 'unbound-variable))
(assert (typep (nth-value 1 (ignore-errors (make-bug210b))) 'unbound-variable))

;;; In sbcl-0.7.8.53, DEFSTRUCT blew up in non-toplevel contexts
;;; because it implicitly assumed that EVAL-WHEN (COMPILE) stuff
;;; setting up compiler-layout information would run before the
;;; constructor function installing the layout was compiled. Make sure
;;; that doesn't happen again.
(defun foo-0-7-8-53 () (defstruct foo-0-7-8-53 x (y :not)))
(assert (not (find-class 'foo-0-7-8-53 nil)))
(foo-0-7-8-53)
(assert (find-class 'foo-0-7-8-53 nil))
(let ((foo-0-7-8-53 (make-foo-0-7-8-53 :x :s)))
  (assert (eq (foo-0-7-8-53-x foo-0-7-8-53) :s))
  (assert (eq (foo-0-7-8-53-y foo-0-7-8-53) :not)))

;;; tests of behaviour of colliding accessors.
(defstruct (bug127-foo (:conc-name bug127-baz-)) a)
(assert (= (bug127-baz-a (make-bug127-foo :a 1)) 1))
(defstruct (bug127-bar (:conc-name bug127-baz-) (:include bug127-foo)) b)
(assert (= (bug127-baz-a (make-bug127-bar :a 1 :b 2)) 1))
(assert (= (bug127-baz-b (make-bug127-bar :a 1 :b 2)) 2))
(assert (= (bug127-baz-a (make-bug127-foo :a 1)) 1))

(defun bug127-flurble (x)
  x)
(defstruct bug127 flurble)
(assert (= (bug127-flurble (make-bug127 :flurble 7)) 7))

(defstruct bug127-a b-c)
(assert (= (bug127-a-b-c (make-bug127-a :b-c 9)) 9))
(defstruct (bug127-a-b (:include bug127-a)) c)
(assert (= (bug127-a-b-c (make-bug127-a :b-c 9)) 9))
(assert (= (bug127-a-b-c (make-bug127-a-b :b-c 11 :c 13)) 11))

(defstruct (bug127-e (:conc-name bug127--)) foo)
(assert (= (bug127--foo (make-bug127-e :foo 3)) 3))
(defstruct (bug127-f (:conc-name bug127--)) foo)
(assert (= (bug127--foo (make-bug127-f :foo 3)) 3))
(assert (raises-error? (bug127--foo (make-bug127-e :foo 3)) type-error))

;;; FIXME: should probably do the same tests on DEFSTRUCT :TYPE

;;; As noted by Paul Dietz for CMUCL, :CONC-NAME handling was a little
;;; too fragile:
(defstruct (conc-name-syntax :conc-name) a-conc-name-slot)
(assert (eq (a-conc-name-slot (make-conc-name-syntax :a-conc-name-slot 'y))
            'y))
;;; and further :CONC-NAME NIL was being wrongly treated:
(defpackage "DEFSTRUCT-TEST-SCRATCH")
(defstruct (conc-name-nil :conc-name)
  defstruct-test-scratch::conc-name-nil-slot)
(assert (= (defstruct-test-scratch::conc-name-nil-slot
            (make-conc-name-nil :conc-name-nil-slot 1)) 1))
(assert (raises-error? (conc-name-nil-slot (make-conc-name-nil))
                       undefined-function))

;;; The named/typed predicates were a little fragile, in that they
;;; could throw errors on innocuous input:
(defstruct (list-struct (:type list) :named) a-slot)
(assert (list-struct-p (make-list-struct)))
(assert (not (list-struct-p nil)))
(assert (not (list-struct-p 1)))
(defstruct (offset-list-struct (:type list) :named (:initial-offset 1)) a-slot)
(assert (offset-list-struct-p (make-offset-list-struct)))
(assert (not (offset-list-struct-p nil)))
(assert (not (offset-list-struct-p 1)))
(assert (not (offset-list-struct-p '(offset-list-struct))))
(assert (not (offset-list-struct-p '(offset-list-struct . 3))))
(defstruct (vector-struct (:type vector) :named) a-slot)
(assert (vector-struct-p (make-vector-struct)))
(assert (not (vector-struct-p nil)))
(assert (not (vector-struct-p #())))


;;; bug 3d: type safety with redefined type constraints on slots
#+#.(cl:if (cl:eq sb-ext:*evaluator-mode* :compile) '(and) '(or))
(macrolet
    ((test (type)
       (let* ((base-name (intern (format nil "bug3d-~A" type)))
              (up-name (intern (format nil "~A-up" base-name)))
              (accessor (intern (format nil "~A-X" base-name)))
              (up-accessor (intern (format nil "~A-X" up-name)))
              (type-options (when type `((:type ,type)))))
         `(progn
            (defstruct (,base-name ,@type-options)
              x y)
            (defstruct (,up-name (:include ,base-name
                                           (x "x" :type simple-string)
                                           (y "y" :type simple-string))
                                 ,@type-options))
            (let ((ob (,(intern (format nil "MAKE-~A" up-name)))))
              (setf (,accessor ob) 0)
              (loop for decl in '(inline notinline)
                    for fun = `(lambda (s)
                                 (declare (optimize (safety 3))
                                          (,decl ,',up-accessor))
                                 (,',up-accessor s))
                    do (assert (raises-error? (funcall (compile nil fun) ob)
                                              type-error))))))))
  (test nil)
  (test list)
  (test vector))

(let* ((name (gensym))
       (form `(defstruct ,name
                (x nil :type (or null (function (integer)
                                                (values number &optional foo)))))))
  (eval (copy-tree form))
  (eval (copy-tree form)))

;;; 322: "DEFSTRUCT :TYPE LIST predicate and improper lists"
;;; reported by Bruno Haible sbcl-devel "various SBCL bugs" from CLISP
;;; test suite.
(defstruct (bug-332a (:type list) (:initial-offset 5) :named))
(defstruct (bug-332b (:type list) (:initial-offset 2) :named (:include bug-332a)))
(assert (not (bug-332b-p (list* nil nil nil nil nil 'foo73 nil 'tail))))
(assert (not (bug-332b-p 873257)))
(assert (not (bug-332b-p '(1 2 3 4 5 x 1 2 bug-332a))))
(assert (bug-332b-p '(1 2 3 4 5 x 1 2 bug-332b)))

;;; Similar test for vectors, just for good measure.
(defstruct (bug-332a-aux (:type vector)
                         (:initial-offset 5) :named))
(defstruct (bug-332b-aux (:type vector)
                         (:initial-offset 2) :named
                         (:include bug-332a-aux)))
(assert (not (bug-332b-aux-p #(1 2 3 4 5 x 1 premature-end))))
(assert (not (bug-332b-aux-p 873257)))
(assert (not (bug-332b-aux-p #(1 2 3 4 5 x 1 2 bug-332a-aux))))
(assert (bug-332b-aux-p #(1 2 3 4 5 x 1 2 bug-332b-aux)))

;;; In sbcl-0.8.11.8 FBOUNDPness potential collisions of structure
;;; slot accessors signalled a condition at macroexpansion time, not
;;; when the code was actually compiled or loaded.
(let ((defstruct-form '(defstruct bug-in-0-8-11-8 x)))
  (defun bug-in-0-8-11-8-x (z) (print "some unrelated thing"))
  (handler-case (macroexpand defstruct-form)
    (warning (c)
      (error "shouldn't warn just from macroexpansion here"))))

;;; bug 318 symptom no 1. (rest not fixed yet)
(catch :ok
  (handler-bind ((error (lambda (c)
                          ;; Used to cause stack-exhaustion
                          (unless (typep c 'storage-condition)
                            (throw :ok t)))))
    (eval '(progn
            (defstruct foo a)
            (setf (find-class 'foo) nil)
            (defstruct foo slot-1)))))

;;; bug 348, evaluation order of slot writer arguments. Fixed by Gabor
;;; Melis.
(defstruct bug-348 x)

(assert (eql -1 (let ((i (eval '-2))
                      (x (make-bug-348)))
                  (funcall #'(setf bug-348-x)
                           (incf i)
                           (aref (vector x) (incf i)))
                  (bug-348-x x))))

;;; obsolete instance trapping
;;;
;;; FIXME: Both error conditions below should possibly be instances
;;; of the same class. (Putting this FIXME here, since this is the only
;;; place where they appear together.)

(with-test (:name obsolete-defstruct/print-object)
  (eval '(defstruct born-to-change))
  (let ((x (make-born-to-change)))
    (handler-bind ((error 'continue))
      (eval '(defstruct born-to-change slot)))
    (assert (eq :error
                (handler-case
                    (princ-to-string x)
                  (sb-pcl::obsolete-structure ()
                    :error))))))

(with-test (:name obsolete-defstruct/typep)
  (eval '(defstruct born-to-change-2))
  (let ((x (make-born-to-change-2)))
    (handler-bind ((error 'continue))
      (eval '(defstruct born-to-change-2 slot)))
      (assert (eq :error2
                  (handler-case
                      (typep x (find-class 'standard-class))
                    (sb-kernel:layout-invalid ()
                      :error2))))))

;; EQUALP didn't work for structures with float slots (reported by
;; Vjacheslav Fyodorov).
(defstruct raw-slot-equalp-bug
  (b 0s0 :type single-float)
  c
  (a 0d0 :type double-float))

(with-test (:name raw-slot-equalp)
  (assert (equalp (make-raw-slot-equalp-bug :a 1d0 :b 2s0)
                  (make-raw-slot-equalp-bug :a 1d0 :b 2s0)))
  (assert (equalp (make-raw-slot-equalp-bug :a 1d0 :b 0s0)
                  (make-raw-slot-equalp-bug :a 1d0 :b -0s0)))
  (assert (not (equalp (make-raw-slot-equalp-bug :a 1d0 :b 2s0)
                       (make-raw-slot-equalp-bug :a 1d0 :b 3s0))))
  (assert (not (equalp (make-raw-slot-equalp-bug :a 1d0 :b 2s0)
                       (make-raw-slot-equalp-bug :a 2d0 :b 2s0)))))

;;; Check that all slot types (non-raw and raw) can be initialized with
;;; constant arguments.
(defstruct constant-arg-inits
  (a 42 :type t)
  (b 1 :type fixnum)
  (c 2 :type sb-vm:word)
  (d 3.0 :type single-float)
  (e 4.0d0 :type double-float)
  (f #c(5.0 5.0) :type (complex single-float))
  (g #c(6.0d0 6.0d0) :type (complex double-float)))
(defun test-constant-arg-inits ()
  (let ((foo (make-constant-arg-inits)))
    (declare (dynamic-extent foo))
    (assert (eql 42 (constant-arg-inits-a foo)))
    (assert (eql 1 (constant-arg-inits-b foo)))
    (assert (eql 2 (constant-arg-inits-c foo)))
    (assert (eql 3.0 (constant-arg-inits-d foo)))
    (assert (eql 4.0d0 (constant-arg-inits-e foo)))
    (assert (eql #c(5.0 5.0) (constant-arg-inits-f foo)))
    (assert (eql #c(6.0d0 6.0d0) (constant-arg-inits-g foo)))))
(make-constant-arg-inits)

;;; bug reported by John Morrison, 2008-07-22 on sbcl-devel
(defstruct (raw-slot-struct-with-unknown-init (:constructor make-raw-slot-struct-with-unknown-init ()))
 (x (#:unknown-function) :type double-float))

;;; Some checks for the behavior of incompatibly redefining structure
;;; classes.  We don't actually check that our detection of
;;; "incompatible" is comprehensive, only that if an incompatible
;;; definition is processed, we do various things.
(defmacro with-files ((&rest vars) &body body)
  "Evaluate BODY with VARS bound to a number of filenames, then
delete the files at the end."
  (let* ((paths (loop for var in vars
                      as index upfrom 0
                      collect (make-pathname
                                   :case :common
                                   :name (format nil
                                                 "DEFSTRUCT-REDEF-TEST-~D"
                                                 index)
                                   :type "LISP")))
         (binding-spec (mapcar
                        (lambda (var path) `(,var ,path)) vars paths)))
    (labels ((frob (n)
               `((unwind-protect
                     (progn
                       ,@(if (plusp n)
                             (frob (1- n))
                             body))
                   (delete-file ,(elt paths n))))))
      `(let ,binding-spec
         ,@(frob (1- (length vars)))))))

(defun noclobber (pathspec &rest forms)
  "Write FORMS to the file named by PATHSPEC, erroring if
PATHSPEC already names an existing file."
  (with-open-file (*standard-output* pathspec :direction :output
                                     :if-exists :error)
    (print '(in-package "CL-USER"))
    (mapc #'print forms)))

(defun compile-file-assert (file &optional (want-error-p t) (want-warning-p t))
  "Compile FILE and assert some things about the results."
  (multiple-value-bind (fasl errors-p warnings-p)
      (compile-file file)
    (assert fasl)
    (assert (eq errors-p want-error-p))
    (assert (eq warnings-p want-warning-p))
    fasl))

(defun continue-from-incompatible-defstruct-error (error)
  "Invoke the CONTINUE restart for an incompatible DEFSTRUCT
redefinition."
  ;; FIXME: want distinct error type for incompatible defstruct.
  (when (search "attempt to redefine" (simple-condition-format-control error))
    (when (find-restart 'continue)
      (invoke-restart 'continue))))

(defun recklessly-continue-from-incompatible-defstruct-error (error)
  "Invoke the RECKLESSLY-CONTINUE restart for an incompatible DEFSTRUCT
redefinition."
  ;; FIXME: want distinct error type for incompatible defstruct.
  (when (search "attempt to redefine" (simple-condition-format-control error))
    (when (find-restart 'sb-kernel::recklessly-continue)
      (invoke-restart 'sb-kernel::recklessly-continue))))

(defun assert-is (predicate instance)
  (assert (funcall predicate instance)))

(defun assert-invalid (predicate instance)
  (assert (typep (nth-value 1 (ignore-errors (funcall predicate instance)))
                 'sb-kernel::layout-invalid)))

;; Don't try to understand this macro; just look at its expansion.
(defmacro with-defstruct-redefinition-test (name
                                            (&rest defstruct-form-bindings)
                                            (&rest path-form-specs)
                                            handler-function
                                            &body body)
  (labels ((make-defstruct-form (&key class-name super-name slots)
             (let* ((predicate-name
                     (read-from-string (format nil "~A-p" class-name)))
                    (constructor-name
                     (read-from-string (format nil "make-~A" class-name))))
               `(values
                 '(defstruct (,class-name
                             (:constructor ,constructor-name)
                             ,@(when super-name
                                 `((:include ,super-name))))
                    ,@slots)
                 ',constructor-name
                 ',predicate-name)))
           (frob (bindspecs classno)
             (if bindspecs
                 `((multiple-value-bind ,(first (first bindspecs))
                       ,(apply #'make-defstruct-form (rest (first bindspecs)))
                     (declare (ignorable ,@(first (first bindspecs))))
                     ,@(frob (rest bindspecs) (1+ classno))))
                 `((with-files ,(mapcar #'first path-form-specs)
                     ,@(mapcar (lambda (path-form) `(noclobber ,@path-form))
                               path-form-specs)
                     (handler-bind
                         ((simple-error ',handler-function))
                       ,@body))))))
    `(with-test (:name ,name)
      ,(first (frob defstruct-form-bindings 0)))))

;; When eyeballing these, it's helpful to see when various things are
;; happening.
(setq *compile-verbose* t *load-verbose* t)

;;; Tests begin.
;; Base case: recklessly-continue.
(with-defstruct-redefinition-test defstruct/recklessly
    (((defstruct ctor pred) :class-name redef-test-1 :slots (a))
     ((defstruct*) :class-name redef-test-1 :slots (a b)))
    ((path1 defstruct)
     (path2 defstruct*))
    recklessly-continue-from-incompatible-defstruct-error
  (load path1)
  (let ((instance (funcall ctor)))
    (load path2)
    (assert-is pred instance)))

;; Base case: continue (i.e., invalidate instances).
(with-defstruct-redefinition-test defstruct/continue
    (((defstruct ctor pred) :class-name redef-test-2 :slots (a))
     ((defstruct*) :class-name redef-test-2 :slots (a b)))
    ((path1 defstruct)
     (path2 defstruct*))
    continue-from-incompatible-defstruct-error
  (load path1)
  (let ((instance (funcall ctor)))
    (load path2)
    (assert-invalid pred instance)))

;; Compiling a file with an incompatible defstruct should emit a
;; warning and an error, but the fasl should be loadable.
(with-defstruct-redefinition-test defstruct/compile-file-should-warn
    (((defstruct) :class-name redef-test-3 :slots (a))
     ((defstruct*) :class-name redef-test-3 :slots (a b)))
    ((path1 defstruct)
     (path2 defstruct*))
    continue-from-incompatible-defstruct-error
  (load path1)
  (load (compile-file-assert path2)))

;; After compiling a file with an incompatible DEFSTRUCT, load the
;; fasl and ensure that an old instance remains valid.
(with-defstruct-redefinition-test defstruct/compile-file-reckless
    (((defstruct ctor pred) :class-name redef-test-4 :slots (a))
     ((defstruct*) :class-name redef-test-4 :slots (a b)))
    ((path1 defstruct)
     (path2 defstruct*))
    recklessly-continue-from-incompatible-defstruct-error
  (load path1)
  (let ((instance (funcall ctor)))
    (load (compile-file-assert path2))
    (assert-is pred instance)))

;; After compiling a file with an incompatible DEFSTRUCT, load the
;; fasl and ensure that an old instance has become invalid.
(with-defstruct-redefinition-test defstruct/compile-file-continue
    (((defstruct ctor pred) :class-name redef-test-5 :slots (a))
     ((defstruct*) :class-name redef-test-5 :slots (a b)))
    ((path1 defstruct)
     (path2 defstruct*))
    continue-from-incompatible-defstruct-error
  (load path1)
  (let ((instance (funcall ctor)))
    (load (compile-file-assert path2))
    (assert-invalid pred instance)))

;;; Subclasses.
;; Ensure that recklessly continuing DT(expected)T to instances of
;; subclasses.  (This is a case where recklessly continuing is
;; actually dangerous, but we don't care.)
(with-defstruct-redefinition-test defstruct/subclass-reckless
    (((defstruct ignore pred1) :class-name redef-test-6 :slots (a))
     ((substruct ctor pred2) :class-name redef-test-6-sub
                             :super-name redef-test-6 :slots (z))
     ((defstruct*) :class-name redef-test-6 :slots (a b)))
    ((path1 defstruct substruct)
     (path2 defstruct* substruct))
    recklessly-continue-from-incompatible-defstruct-error
  (load path1)
  (let ((instance (funcall ctor)))
    (load (compile-file-assert path2))
    (assert-is pred1 instance)
    (assert-is pred2 instance)))

;; Ensure that continuing invalidates instances of subclasses.
(with-defstruct-redefinition-test defstruct/subclass-continue
    (((defstruct) :class-name redef-test-7 :slots (a))
     ((substruct ctor pred) :class-name redef-test-7-sub
                            :super-name redef-test-7 :slots (z))
     ((defstruct*) :class-name redef-test-7 :slots (a b)))
    ((path1 defstruct substruct)
     (path2 defstruct* substruct))
    continue-from-incompatible-defstruct-error
  (load path1)
  (let ((instance (funcall ctor)))
    (load (compile-file-assert path2))
    (assert-invalid pred instance)))

;; Reclkessly continuing doesn't invalidate instances of subclasses.
(with-defstruct-redefinition-test defstruct/subclass-in-other-file-reckless
    (((defstruct ignore pred1) :class-name redef-test-8 :slots (a))
     ((substruct ctor pred2) :class-name redef-test-8-sub
                             :super-name redef-test-8 :slots (z))
     ((defstruct*) :class-name redef-test-8 :slots (a b)))
    ((path1 defstruct)
     (path2 substruct)
     (path3 defstruct*))
    recklessly-continue-from-incompatible-defstruct-error
  (load path1)
  (load path2)
  (let ((instance (funcall ctor)))
    (load (compile-file-assert path3))
    (assert-is pred1 instance)
    (assert-is pred2 instance)))

;; This is an icky case: when a subclass is defined in a separate
;; file, CONTINUE'ing from LOAD of a file containing an incompatible
;; superclass definition leaves the predicates and accessors into the
;; subclass in a bad way until the subclass form is evaluated.
(with-defstruct-redefinition-test defstruct/subclass-in-other-file-continue
    (((defstruct ignore pred1) :class-name redef-test-9 :slots (a))
     ((substruct ctor pred2) :class-name redef-test-9-sub
                             :super-name redef-test-9 :slots (z))
     ((defstruct*) :class-name redef-test-9 :slots (a b)))
    ((path1 defstruct)
     (path2 substruct)
     (path3 defstruct*))
    continue-from-incompatible-defstruct-error
  (load path1)
  (load path2)
  (let ((instance (funcall ctor)))
    (load (compile-file-assert path3))
    ;; At this point, the instance of the subclass will not count as
    ;; an instance of the superclass or of the subclass, but PRED2's
    ;; predicate will error with "an obsolete structure accessor
    ;; function was called".
    (assert-invalid pred1 instance)
    (format t "~&~A~%" (nth-value 1 (ignore-errors (funcall pred2 instance))))
    ;; After loading PATH2, we'll get the desired LAYOUT-INVALID error.
    (load path2)
    (assert-invalid pred2 instance)))

;; Some other subclass wrinkles have to do with splitting definitions
;; accross files and compiling and loading things in a funny order.
(with-defstruct-redefinition-test
    defstruct/subclass-in-other-file-funny-operation-order-continue
    (((defstruct ignore pred1) :class-name redef-test-10 :slots (a))
     ((substruct ctor pred2) :class-name redef-test-10-sub
                             :super-name redef-test-10 :slots (z))
     ((defstruct*) :class-name redef-test-10 :slots (a b)))
    ((path1 defstruct)
     (path2 substruct)
     (path3 defstruct*))
    continue-from-incompatible-defstruct-error
  (load path1)
  (load path2)
  (let ((instance (funcall ctor)))
    ;; First we clobber the compiler's layout for the superclass.
    (compile-file-assert path3)
    ;; Then we recompile the subclass definition (which generates a
    ;; warning about the compiled layout for the superclass being
    ;; incompatible with the loaded layout, because we haven't loaded
    ;; path3 since recompiling).
    (compile-file path2)
    ;; Ugh.  I don't want to think about loading these in the wrong
    ;; order.
    (load (compile-file-pathname path3))
    (load (compile-file-pathname path2))
    (assert-invalid pred1 instance)
    (assert-invalid pred2 instance)))

(with-defstruct-redefinition-test
    defstruct/subclass-in-other-file-funny-operation-order-continue
    (((defstruct ignore pred1) :class-name redef-test-11 :slots (a))
     ((substruct ctor pred2) :class-name redef-test-11-sub
                             :super-name redef-test-11 :slots (z))
     ((defstruct*) :class-name redef-test-11 :slots (a b)))
    ((path1 defstruct)
     (path2 substruct)
     (path3 defstruct*))
    continue-from-incompatible-defstruct-error
  (load path1)
  (load path2)
  (let ((instance (funcall ctor)))
    ;; This clobbers the compiler's layout for REDEF-TEST-11.
    (compile-file-assert path3)
    ;; This recompiles REDEF-TEST-11-SUB, using the new REDEF-TEST-11
    ;; compiler-layout.
    (load (compile-file-pathname path2))
    ;; Note that because we haven't loaded PATH3, we haven't clobbered
    ;; the class's layout REDEF-TEST-11, so REDEF-11's predicate will
    ;; still work.  That's probably bad.
    (assert-is pred1 instance)
    (assert-is pred2 instance)))

(with-test (:name :raw-slot/circle-subst)
  ;; CIRCLE-SUBSTS used %INSTANCE-REF on raw slots
  (multiple-value-bind (list n)
      (eval '(progn
              (defstruct raw-slot/circle-subst
                (x 0.0 :type single-float))
              (read-from-string "((#1=#S(raw-slot/circle-subst :x 2.7158911)))")))
    (destructuring-bind ((struct)) list
      (assert (raw-slot/circle-subst-p struct))
      (assert (eql 2.7158911 (raw-slot/circle-subst-x struct)))
      (assert (eql 45 n)))))

(defstruct (bug-3b (:constructor make-bug-3b (&aux slot)))
  (slot nil :type string))

(with-test (:name :bug-3b)
  (handler-case
      (progn
        (bug-3b-slot (make-bug-3b))
        (error "fail"))
    (type-error (e)
      (assert (eq 'string (type-error-expected-type e)))
      (assert (zerop (type-error-datum e))))))

(with-test (:name defstruct-copier-typechecks-argument)
  (assert (not (raises-error? (copy-person (make-astronaut :name "Neil")))))
  (assert (raises-error? (copy-astronaut (make-person :name "Fred")))))

(with-test (:name :bug-528807)
  (let ((*evaluator-mode* :compile))
    (handler-bind ((style-warning #'error))
      (eval `(defstruct (bug-528807 (:constructor make-528807 (&aux x)))
               (x nil :type fixnum))))))

(with-test (:name :bug-520607)
  (assert
    (raises-error?
      (eval '(defstruct (typed-struct (:type list) (:predicate typed-struct-p))
              (a 42 :type fixnum)))))
  ;; NIL is ok, though.
  (eval '(defstruct (typed-struct (:type list) (:predicate nil))
          (a 42 :type fixnum)))
  ;; So's empty.
  (eval '(defstruct (typed-struct2 (:type list) (:predicate))
          (a 42 :type fixnum))))

(with-test (:name (:boa-supplied-p &optional))
  (handler-bind ((warning #'error))
    (eval `(defstruct (boa-supplied-p.1 (:constructor make-boa-supplied-p.1
                                            (&optional (bar t barp))))
             bar
             barp)))
  (let ((b1 (make-boa-supplied-p.1))
        (b2 (make-boa-supplied-p.1 t)))
    (assert (eq t (boa-supplied-p.1-bar b1)))
    (assert (eq t (boa-supplied-p.1-bar b2)))
    (assert (eq nil (boa-supplied-p.1-barp b1)))
    (assert (eq t (boa-supplied-p.1-barp b2)))))

(with-test (:name (:boa-supplied-p &key))
  (handler-bind ((warning #'error))
    (eval `(defstruct (boa-supplied-p.2 (:constructor make-boa-supplied-p.2
                                            (&key (bar t barp))))
             bar
             barp)))
  (let ((b1 (make-boa-supplied-p.2))
        (b2 (make-boa-supplied-p.2 :bar t)))
    (assert (eq t (boa-supplied-p.2-bar b1)))
    (assert (eq t (boa-supplied-p.2-bar b2)))
    (assert (eq nil (boa-supplied-p.2-barp b1)))
    (assert (eq t (boa-supplied-p.2-barp b2)))))
