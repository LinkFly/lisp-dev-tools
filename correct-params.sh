#!/bin/sh

. ./tools.conf
. ./utils.sh

if ! [ "$LISP" = "" ];
then CUR_LISP=$LISP;
fi

local D=\$;

if ! [ "$VERSION" = "" ];
then
local LISP_VERSION_PARAM=$(uppercase $CUR_LISP)_VERSION;
eval $LISP_VERSION_PARAM="$VERSION"
fi

if ! [ "$ARCH" = "" ];
then
local LISP_ARCH_PARAM=$(uppercase $CUR_LISP)_ARCH;
eval $LISP_ARCH_PARAM="$ARCH"
fi

if ! [ "$OS" = "" ];
then
local LISP_OS_PARAM=$(uppercase $CUR_LISP)_OS;
eval $LISP_OS_PARAM="$OS"
fi
