;;;; This implementation of RANDOM is based on the Mersenne Twister random
;;;; number generator "MT19937" due to Matsumoto and Nishimura. See:
;;;;   Makoto Matsumoto and T. Nishimura, "Mersenne twister: A
;;;;   623-dimensionally equidistributed uniform pseudorandom number
;;;;   generator.", ACM Transactions on Modeling and Computer Simulation,
;;;;   Vol. 8, No. 1, January pp.3-30 (1998) DOI:10.1145/272991.272995
;;;; http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/emt.html

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; This software is derived from the CMU CL system, which was
;;;; written at Carnegie Mellon University and released into the
;;;; public domain. The software is in the public domain and is
;;;; provided with absolutely no warranty. See the COPYING and CREDITS
;;;; files for more information.

(in-package "SB!KERNEL")

;;;; Constants
(defconstant mt19937-n 624)
(defconstant mt19937-m 397)
(defconstant mt19937-upper-mask #x80000000)
(defconstant mt19937-lower-mask #x7FFFFFFF)
(defconstant mt19937-a #x9908B0DF)
(defconstant mt19937-b #x9D2C5680)
(defconstant mt19937-c #xEFC60000)

;;;; RANDOM-STATEs

;;; The state is stored in a (simple-array (unsigned-byte 32) (627))
;;; wrapped in a random-state structure:
;;;
;;;  0-1:   Constant matrix A. [0, #x9908b0df]
;;;  2:     Index k.
;;;  3-626: State.

(deftype random-state-state () `(simple-array (unsigned-byte 32) (,(+ 3 mt19937-n))))

(def!method make-load-form ((random-state random-state) &optional environment)
  (make-load-form-saving-slots random-state :environment environment))

(def!method print-object ((state random-state) stream)
  (if (and *print-readably* (not *read-eval*))
      (restart-case
          (error 'print-not-readable :object state)
        (print-unreadably ()
          :report "Print unreadably."
          (write state :stream stream :readably nil))
        (use-value (object)
          :report "Supply an object to be printed instead."
          :interactive read-unreadable-replacement
          (write object :stream stream)))
      (format stream "#S(~S ~S #.~S)"
              'random-state
              ':state
              `(make-array ,(+ 3 mt19937-n)
                :element-type
                '(unsigned-byte 32)
                :initial-contents
                ',(coerce (random-state-state state) 'list)))))

;;; Generate and initialize a new random-state array. Index is
;;; initialized to 1 and the states to 32bit integers excluding zero.
;;;
;;; Seed - A 32bit number.
;;;
;;; See Knuth TAOCP Vol2. 3rd Ed. P.106 for multiplier.
;;; In the previous versions, MSBs of the seed affect only MSBs of the array.
(defun init-random-state (&optional (seed 5489) state)
  (declare (type (unsigned-byte 32) seed))
  (let ((state (or state (make-array 627 :element-type '(unsigned-byte 32)))))
    (check-type state random-state-state)
    (setf (aref state 0) 0)
    (setf (aref state 1) mt19937-a)
    (setf (aref state 2) mt19937-n)
    (loop for i below mt19937-n
      for p from 3
      for s = seed then
      (logand #xFFFFFFFF
              (+ (* 1812433253
                    (logxor s (ash s -30)))
                 i))
      do (setf (aref state p) s))
    state))

(defvar *random-state*)
(defun !random-cold-init ()
  (/show0 "entering !RANDOM-COLD-INIT")
  (setf *random-state* (%make-random-state))
  (/show0 "returning from !RANDOM-COLD-INIT"))

(defun make-random-state (&optional state)
  #!+sb-doc
  "Make a random state object. The optional STATE argument specifies a seed
  for deterministic pseudo-random number generation.

  As per the Common Lisp standard,
  - If STATE is NIL or not supplied or is NIL, return a copy of the default
  *RANDOM-STATE*.
  - If STATE is a random state, return a copy of it.
  - If STATE is T, return a randomly initialized state (using operating-system
  provided randomness source where available, otherwise a poor substitute
  based on internal time and pid)

  See SB-EXT:SEED-RANDOM-STATE for a SBCL extension to this functionality."
  (/show0 "entering MAKE-RANDOM-STATE")
  (check-type state (or boolean random-state))
  (seed-random-state state))

(defun seed-random-state (&optional state)
  #!+sb-doc
  "Make a random state object. The optional STATE argument specifies a seed
  for deterministic pseudo-random number generation.

  As per the Common Lisp standard for MAKE-RANDOM-STATE,
  - If STATE is NIL or not supplied or is NIL, return a copy of the default
  *RANDOM-STATE*.
  - If STATE is a random state, return a copy of it.
  - If STATE is T, return a randomly initialized state (using operating-system
  provided randomness source where available, otherwise a poor substitute
  based on internal time and pid)

  As a supported SBCL extension, we also support receiving as a seed an object
  of the following types:
  - (SIMPLE-ARRAY (UNSIGNED-BYTE 8) (*))
  - UNSIGNED-BYTE
  While we support arguments of any size and will mix the provided bits into
  the random state, it is probably overkill to provide more than 256 bits worth
  of actual information.

  This particular SBCL version also accepts an argument of the following type:
  - (SIMPLE-ARRAY (UNSIGNED-BYTE 32) (*))

  This particular SBCL version uses the popular MT19937 PRNG algorithm, and its
  internal state only effectively contains about 19937 bits of information.
  http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/emt.html
"
  (etypecase state
    ;; Easy standard cases
    (null
     (/show0 "copying *RANDOM-STATE*")
     (%make-random-state :state (copy-seq (random-state-state *random-state*))))
    (random-state
     (/show0 "copying the provided RANDOM-STATE")
     (%make-random-state :state (copy-seq (random-state-state state))))
    ;; Standard case, less easy: try to randomly initialize a state.
    ((eql t)
     (/show0 "getting randomness from the operating system")
     (seed-random-state
      (or
       ;; On unices, we try to read from /dev/urandom and pass the results
       ;; to our (simple-array (unsigned-byte 32) (*)) processor below.
       ;; More than 256 bits would provide a false sense of security.
       ;; If you need more bits than that, you probably also need
       ;; a better algorithm too.
       #!-win32
       (ignore-errors
         (with-open-file (r "/dev/urandom" :element-type '(unsigned-byte 32)
                            :direction :input :if-does-not-exist :error)
           (let ((a (make-array '(8) :element-type '(unsigned-byte 32))))
             (assert (= 8 (read-sequence a r)))
             a)))
       ;; When /dev/urandom is not available, we make do with time and pid
       ;; Thread ID and/or address of a CONS cell would be even better, but...
       (progn
         (/show0 "No /dev/urandom, using randomness from time and pid")
         (+ (get-internal-real-time)
            #!+unix (ash (sb!unix:unix-getpid) 32))))))
    ;; For convenience to users, we accept (simple-array (unsigned-byte 8) (*))
    ;; We just convert it to (simple-array (unsigned-byte 32) (*)) in a
    ;; completely straightforward way.
    ;; TODO: probably similarly accept other word sizes.
    ((simple-array (unsigned-byte 8) (*))
     (/show0 "getting random seed from byte vector (converting to 32-bit-word vector)")
     (let* ((l (length state))
            (m (ceiling l 4))
            (r (if (>= l 2496) 0 (mod l 4)))
            (y (make-array (list m) :element-type '(unsigned-byte 32))))
             (loop for i from 0 below (- m (if (zerop r) 0 1))
               for j = (* i 4) do
               (setf (aref y i)
                     (+ (aref state j)
                        (ash (aref state (+ j 1)) 8)
                        (ash (aref state (+ j 2)) 16)
                        (ash (aref state (+ j 3)) 24))))
             (unless (zerop r) ;; The last word may require special treatment.
               (let* ((p (1- m)) (q (* 4 p)))
                 (setf (aref y p)
                     (+ (aref state q)
                        (if (< 1 r) (ash (aref state (+ q 1)) 8) 0)
                        (if (= 3 r) (ash (aref state (+ q 2)) 16) 0)))))
             (seed-random-state y)))
    ;; Also for convenience, we accept non-negative integers as seeds.
    ;; Small ones get passed to init-random-state, as before.
    ((unsigned-byte 32)
     (/show0 "getting random seed from 32-bit word")
     (%make-random-state :state (init-random-state state)))
    ;; Larger ones ones get trivially chopped into an array of (unsigned-byte 32)
    ((unsigned-byte)
     (/show0 "getting random seed from bignum (converting to 32-bit-word vector)")
     (loop with l = (ceiling (integer-length state) 32)
       with s = (make-array (list l) :element-type '(unsigned-byte 32))
       for i below l
       for p from 0 by 32
       do (setf (aref s i) (ldb (byte 32 p) state))
       finally (return (seed-random-state s))))
    ;; Last but not least, when provided an array of 32-bit words, we truncate
    ;; it to 19968 bits and mix these into an initial state. We reuse the same
    ;; method as the authors of the original algorithm. See
    ;; http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/MT2002/CODES/mt19937ar.c
    ;; NB: their mt[i] is our (aref s (+ 3 i))
    ((simple-array (unsigned-byte 32) (*))
     (/show0 "getting random seed from 32-bit-word vector")
     (let ((s (init-random-state 19650218))
           (i 1) (j 0) (l (length state)))
       (loop for k downfrom (max mt19937-n l) above 0 do
         (setf (aref s (+ i 3))
               (logand #xFFFFFFFF
                       (+ (logxor (aref s (+ i 3))
                                  (* 1664525
                                     (logxor (aref s (+ i 2))
                                             (ash (aref s (+ i 2)) -30))))
                          (aref state j) j))) ;; non-linear
         (incf i) (when (>= i mt19937-n) (setf (aref s 3) (aref s (+ 2 mt19937-n)) i 1))
         (incf j) (when (>= j l) (setf j 0)))
       (loop for k downfrom (1- mt19937-n) above 0 do
         (setf (aref s (+ i 3))
               (logand #xFFFFFFFF
                       (- (logxor (aref s (+ i 3))
                                  (* 1566083941
                                     (logxor (aref s (+ i 2))
                                             (ash (aref s (+ i 2)) -30))))
                          i))) ;; non-linear
         (incf i) (when (>= i mt19937-n) (setf (aref s 3) (aref s (+ 2 mt19937-n)) i 1)))
       (setf (aref s 3) #x80000000) ;; MSB is 1; assuring non-zero initial array
       (%make-random-state :state s)))))

;;;; random entries

;;; This function generates a 32bit integer between 0 and #xffffffff
;;; inclusive.
#!-sb-fluid (declaim (inline random-chunk))
;;; portable implementation
#!-x86
(defun random-mt19937-update (state)
  (declare (type random-state-state state)
           (optimize (speed 3) (safety 0)))
  (let ((y 0))
    (declare (type (unsigned-byte 32) y))
    (do ((kk 3 (1+ kk)))
        ((>= kk (+ 3 (- mt19937-n mt19937-m))))
      (declare (type (mod 628) kk))
      (setf y (logior (logand (aref state kk) mt19937-upper-mask)
                      (logand (aref state (1+ kk)) mt19937-lower-mask)))
      (setf (aref state kk) (logxor (aref state (+ kk mt19937-m))
                                    (ash y -1) (aref state (logand y 1)))))
    (do ((kk (+ (- mt19937-n mt19937-m) 3) (1+ kk)))
        ((>= kk (+ (1- mt19937-n) 3)))
      (declare (type (mod 628) kk))
      (setf y (logior (logand (aref state kk) mt19937-upper-mask)
                      (logand (aref state (1+ kk)) mt19937-lower-mask)))
      (setf (aref state kk) (logxor (aref state (+ kk (- mt19937-m mt19937-n)))
                                    (ash y -1) (aref state (logand y 1)))))
    (setf y (logior (logand (aref state (+ 3 (1- mt19937-n)))
                            mt19937-upper-mask)
                    (logand (aref state 3) mt19937-lower-mask)))
    (setf (aref state (+ 3 (1- mt19937-n)))
          (logxor (aref state (+ 3 (1- mt19937-m)))
                  (ash y -1) (aref state (logand y 1)))))
  (values))
#!-x86
(defun random-chunk (state)
  (declare (type random-state state))
  (let* ((state (random-state-state state))
         (k (aref state 2)))
    (declare (type (mod 628) k))
    (when (= k mt19937-n)
      (random-mt19937-update state)
      (setf k 0))
    (setf (aref state 2) (1+ k))
    (let ((y (aref state (+ 3 k))))
      (declare (type (unsigned-byte 32) y))
      (setf y (logxor y (ash y -11)))
      (setf y (logxor y (ash (logand y (ash mt19937-b -7)) 7)))
      (setf y (logxor y (ash (logand y (ash mt19937-c -15)) 15)))
      (setf y (logxor y (ash y -18)))
      y)))

;;; Using inline VOP support, only available on the x86 so far.
;;;
;;; FIXME: It would be nice to have some benchmark numbers on this.
;;; My inclination is to get rid of the nonportable implementation
;;; unless the performance difference is just enormous.
#!+x86
(defun random-chunk (state)
  (declare (type random-state state))
  (sb!vm::random-mt19937 (random-state-state state)))

#!-sb-fluid (declaim (inline big-random-chunk))
(defun big-random-chunk (state)
  (declare (type random-state state))
  (logand (1- (expt 2 64))
          (logior (ash (random-chunk state) 32)
                  (random-chunk state))))

;;; Handle the single or double float case of RANDOM. We generate a
;;; float between 0.0 and 1.0 by clobbering the significand of 1.0
;;; with random bits, then subtracting 1.0. This hides the fact that
;;; we have a hidden bit.
#!-sb-fluid (declaim (inline %random-single-float %random-double-float))
(declaim (ftype (function ((single-float (0f0)) random-state)
                          (single-float 0f0))
                %random-single-float))
(defun %random-single-float (arg state)
  (declare (type (single-float (0f0)) arg)
           (type random-state state))
  (* arg
     (- (make-single-float
         (dpb (ash (random-chunk state)
                   (- sb!vm:single-float-digits random-chunk-length))
              sb!vm:single-float-significand-byte
              (single-float-bits 1.0)))
        1.0)))
(declaim (ftype (function ((double-float (0d0)) random-state)
                          (double-float 0d0))
                %random-double-float))

;;; 32-bit version
#!+nil
(defun %random-double-float (arg state)
  (declare (type (double-float (0d0)) arg)
           (type random-state state))
  (* (float (random-chunk state) 1d0) (/ 1d0 (expt 2 32))))

;;; 53-bit version
#!-x86
(defun %random-double-float (arg state)
  (declare (type (double-float (0d0)) arg)
           (type random-state state))
  (* arg
     (- (sb!impl::make-double-float
         (dpb (ash (random-chunk state)
                   (- sb!vm:double-float-digits random-chunk-length 32))
              sb!vm:double-float-significand-byte
              (sb!impl::double-float-high-bits 1d0))
         (random-chunk state))
        1d0)))

;;; using a faster inline VOP
#!+x86
(defun %random-double-float (arg state)
  (declare (type (double-float (0d0)) arg)
           (type random-state state))
  (let ((state-vector (random-state-state state)))
    (* arg
       (- (sb!impl::make-double-float
           (dpb (ash (sb!vm::random-mt19937 state-vector)
                     (- sb!vm:double-float-digits random-chunk-length
                        sb!vm:n-word-bits))
                sb!vm:double-float-significand-byte
                (sb!impl::double-float-high-bits 1d0))
           (sb!vm::random-mt19937 state-vector))
          1d0))))


;;;; random integers

(defun %random-integer (arg state)
  (declare (type (integer 1) arg) (type random-state state))
  (let ((shift (- random-chunk-length random-integer-overlap)))
    (do ((bits (random-chunk state)
               (logxor (ash bits shift) (random-chunk state)))
         (count (+ (integer-length arg)
                   (- random-integer-extra-bits shift))
                (- count shift)))
        ((minusp count)
         (rem bits arg))
      (declare (fixnum count)))))

(defun random (arg &optional (state *random-state*))
  (declare (inline %random-single-float %random-double-float
                   #!+long-float %random-long-float))
  (cond
    ((and (fixnump arg) (<= arg random-fixnum-max) (> arg 0))
     (rem (random-chunk state) arg))
    ((and (typep arg 'single-float) (> arg 0.0f0))
     (%random-single-float arg state))
    ((and (typep arg 'double-float) (> arg 0.0d0))
     (%random-double-float arg state))
    #!+long-float
    ((and (typep arg 'long-float) (> arg 0.0l0))
     (%random-long-float arg state))
    ((and (integerp arg) (> arg 0))
     (%random-integer arg state))
    (t
     (error 'simple-type-error
            :expected-type '(or (integer 1) (float (0))) :datum arg
            :format-control "~@<Argument is neither a positive integer nor a ~
                             positive float: ~2I~_~S~:>"
            :format-arguments (list arg)))))
