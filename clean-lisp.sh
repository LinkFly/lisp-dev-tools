#!/bin/sh
cd $(dirname $0)
./remove-lisp.sh
./remove-sources-lisp.sh
./remove-compiler-lisp.sh
./remove-archive-lisp-src.sh
./remove-archive-lisp-bin.sh
