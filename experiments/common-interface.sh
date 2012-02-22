#!/bin/sh

cur_lisp=sbcl

tmp=$(mktemp)
trap "rm -f '$tmp'" EXIT

while test $# -gt 0; do
	case "$1" in
		-i) shift; cur_lisp=$1 ;;
		-e) shift; echo "$1" >> $tmp ;;
		-f) shift; echo "(load \"$1\")" >> $tmp ;;
		-h)
			echo 'Usage: run-lisp [-i implementation] [-e eval] [-f file]' >&2
			exit 1
			;;
		*) break
	esac
	shift
done

init_expr="(unwind-protect (load \"$tmp\") (delete-file \"$tmp\"))"

run_lisp_ecl() {
	exec ecl -eval "$init_expr"
}

run_lisp_sbcl() {
	exec sbcl --eval "$init_expr"
}

run_lisp_clisp() {
	exec clisp -x "$init_expr"
}

run_lisp_$cur_lisp "$@"
