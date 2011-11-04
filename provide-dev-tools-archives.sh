#!/bin/sh

######### Configuring variables ####
SBCL_BIN=sbcl-1.0.52-x86-linux-binary.tar.bz2
SBCL_BIN_URL=http://prdownloads.sourceforge.net/sbcl/sbcl-1.0.52-x86-linux-binary.tar.bz2

SBCL_SOURCE=sbcl-1.0.52-source.tar.bz2
SBCL_SOURCE_URL=http://downloads.sourceforge.net/project/sbcl/sbcl/1.0.52/sbcl-1.0.52-source.tar.bz2

SLIME=slime-current.tgz
SLIME_URL=http://common-lisp.net/project/slime/snapshots/slime-current.tgz

EMACS=emacs-23.1.tar.gz
EMACS_URL=http://ftp.gnu.org/pub/gnu/emacs/emacs-23.1.tar.gz
#########################################

ARCHIVE_NAME=$SBCL_BIN URL=$SBCL_BIN_URL ./provide-archive.sh
ARCHIVE_NAME=$SBCL_SOURCE URL=$SBCL_SOURCE_URL ./provide-archive.sh
ARCHIVE_NAME=$SLIME URL=$SLIME_URL ./provide-archive.sh
ARCHIVE_NAME=$EMACS URL=$EMACS_URL ./provide-archive.sh
