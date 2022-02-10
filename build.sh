#!/bin/bash

SCRIPT_DIR="$(dirname $0)"
. ${SCRIPT_DIR}/common.sh
. ${SCRIPT_DIR}/stable-commits
[ -e /etc/os-release ] && . /etc/os-release

function usage()
{
	echo "Usage: $0 [OPTIONS] [COMPONENT]"
	echo "  where COMPONENT is an individual component to build:"
	echo "    qemu, ovmf, kernel [host|guest]"
	echo "    (default is to build all components)"
	echo "  where OPTIONS are:"
	echo "  --install PATH          Installation path (default $INSTALL_DIR)"
	echo "  --package               Create a tarball containing built components"
	echo "  -h|--help               Usage information"

	exit 1
}

INSTALL_DIR="`pwd`/usr/local"

while [ -n "$1" ]; do
	case "$1" in
	--install)
		[ -z "$2" ] && usage
		INSTALL_DIR="$2"
		shift; shift
		;;
	-h|--help)
		usage
		;;
	--package)
		BUILD_PACKAGE="1"
		shift
		;;
	-*|--*)
		echo "Unsupported option: [$1]"
		usage
		;;
	*)
		break
		;;
	esac
done

mkdir -p $INSTALL_DIR
IDIR=$INSTALL_DIR
INSTALL_DIR=$(readlink -e $INSTALL_DIR)
[ -n "$INSTALL_DIR" -a -d "$INSTALL_DIR" ] || {
	echo "Installation directory [$IDIR] does not exist, exiting"
	exit 1
}

if [ -z "$1" ]; then
	build_install_qemu "$INSTALL_DIR"
	build_install_ovmf "$INSTALL_DIR/share/qemu"
	build_kernel $2
else
	case "$1" in
	qemu)
		build_install_qemu "$INSTALL_DIR"
		;;
	ovmf)
		build_install_ovmf "$INSTALL_DIR/share/qemu"
		;;
	kernel)
		# additional argument of "host" or "guest" can be added to limit build to that type
		build_kernel $2
		;;
	esac
fi

if [[ "$BUILD_PACKAGE" = "1" ]]; then
	OUTPUT_DIR="snp-release-`date "+%F"`"
	rm -rf $OUTPUT_DIR
	mkdir -p $OUTPUT_DIR/linux/guest
	mkdir -p $OUTPUT_DIR/linux/host
	mkdir -p $OUTPUT_DIR/usr
	cp -dpR $INSTALL_DIR $OUTPUT_DIR/usr/

	if [ "$ID_LIKE" = "debian" ]; then
		cp linux/linux-*-guest-*.deb $OUTPUT_DIR/linux/guest -v
		cp linux/linux-*-host-*.deb $OUTPUT_DIR/linux/host -v
	else
		cp kernel-*.rpm $OUTPUT_DIR/linux -v
	fi

	cp launch-qemu.sh ${OUTPUT_DIR} -v
	cp install.sh ${OUTPUT_DIR} -v
	cp kvm.conf ${OUTPUT_DIR} -v
	tar zcvf ${OUTPUT_DIR}.tar.gz ${OUTPUT_DIR}
fi
