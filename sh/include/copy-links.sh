#!/bin/sh

if test -z "$(find "$UTILS" -maxdepth 1 -name "*" -type l 2>/dev/null)"
then
    cp -lf "$UTILS/reserv-default-links/*" "$UTILS/" 2>/dev/null
    ln -sf internal-tools/rpm2cpio
fi

