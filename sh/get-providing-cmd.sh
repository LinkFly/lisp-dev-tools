#!/bin/sh
cd "$(dirname "$0")"
. ./includes.sh

case $1 in
    build) get_build_lisp_cmd;
	;;
    install) get_install_lisp_cmd;
	;;
    run) get_run_lisp_cmd;
	;;
    *) echo "Failed. Please use one of the commands: build | install | run";
esac

    