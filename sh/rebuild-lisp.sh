#!/bin/sh
cd "$(dirname "$0")"
./provide-archive-lisp-src.sh
./provide-sources-lisp.sh
./remove-lisp.sh
./build-lisp.sh rebuild