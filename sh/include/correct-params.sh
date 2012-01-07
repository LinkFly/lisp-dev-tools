#!/bin/sh

if ! [ "$LISP" = "" ];
then CUR_LISP=$LISP;
fi

D=\$;

if ! [ "$VERSION" = "" ];
then
LISP_VERSION_PARAM=$(uppercase $CUR_LISP)_VERSION;
eval $LISP_VERSION_PARAM="$VERSION"
fi

if ! [ "$ARCH" = "" ];
then
LISP_ARCH_PARAM=$(uppercase $CUR_LISP)_ARCH;
eval $LISP_ARCH_PARAM="$ARCH"
fi

if ! [ "$OS" = "" ];
then
LISP_OS_PARAM=$(uppercase $CUR_LISP)_OS;
eval $LISP_OS_PARAM="$OS"
fi

if ! [ "$ENABLE_QUICKLISP" = "" ];
then
LISP_OS_PARAM=$(uppercase $CUR_LISP)_ENABLE_QUICKLISP;
eval $LISP_OS_PARAM="$ENABLE_QUICKLISP"
fi
