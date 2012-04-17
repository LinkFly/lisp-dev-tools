#!/bin/sh

if test -z "$(find "$UTILS" -maxdepth 1 -name "*" -type l 2>/dev/null)"
then

    if ! test "$NO_COPY_LINKS_P" = "yes"
    then
	cp -lf "$UTILS/reserv-default-links/"* "$UTILS/" 2>/dev/null
    fi

    ln -sf "internal-tools/rpm2cpio" "$UTILS/rpm2cpio"
fi

