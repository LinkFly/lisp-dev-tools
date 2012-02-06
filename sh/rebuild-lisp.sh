#!/bin/sh
cd "$(dirname "$0")"
. ./includes.sh

#### Resolving dependencies #######
resolve_deps "$LISP_DEPS_ON_TOOLS"

./provide-archive-lisp-src.sh
./provide-sources-lisp.sh
./remove-lisp.sh
./build-lisp.sh rebuild