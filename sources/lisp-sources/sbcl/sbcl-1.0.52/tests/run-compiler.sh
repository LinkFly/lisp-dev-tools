#!/bin/sh

platform="${SBCL_SOFTWARE_TYPE}-${SBCL_MACHINE_TYPE}"

if [ -z "$CC" ]
then
    CC=cc
fi

args=
case "$platform" in
    Darwin-X86-64) args="-arch x86_64" ;;
    Darwin-X86)    args="-arch i386" ;;
    SunOS-X86-64)  args=-m64 ;;
    Linux-X86)     args="-m32" ;;
esac

while [ $# -gt 0 ]; do
    arg="$1"
    new=
    case "$arg" in
        -sbcl-pic)
            case "$platform" in
                FreeBSD-X86-64)  new=-fPIC ;;
                Linux-MIPS)      new=-fPIC ;;
                Linux-X86-64)    new=-fPIC ;;
                NetBSD-PowerPC)  new=-fPIC ;;
                NetBSD-X86-64)   new=-fPIC ;;
                OpenBSD-PowerPC) new=-fPIC ;;
                OpenBSD-X86-64)  new=-fPIC ;;
                SunOS-SPARC)     new=-fPIC ;;
                SunOS-X86)       new=-fPIC ;;
                SunOS-X86-64)    new=-fPIC ;;
            esac
            ;;

        -sbcl-shared)
            case "$platform" in
                Darwin-*)        new=-bundle ;;
                *)               new=-shared ;;
            esac
            ;;

        *)
            break
            ;;
    esac

    shift
    if [ x"$new" != x ]; then
        args="$args $new"
    fi
done

echo "/ $CC $args $@"
"$CC" $args "$@"
