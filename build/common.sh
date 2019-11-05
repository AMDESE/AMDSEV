#!/bin/bash

run_cmd()
{
	echo "$*"

	eval "$*" || {
		echo "ERROR: $*"
		exit 1
	}
}

build_kernel()
{
	[ -d linux ] || {
		run_cmd git clone --single-branch -b ${KERNEL_BRANCH} ${KERNEL_GIT_URL} linux
	}

	[ -d linux-patches ] && {
		pushd linux >/dev/null
			run_cmd git checkout .
		popd >/dev/null

		for P in linux-patches/*.patch; do
			run_cmd patch -p1 -d linux < $P
		done
	}

	MAKE="make -C linux -j $(getconf _NPROCESSORS_ONLN) LOCALVERSION="

	for V in host guest; do
		VER="-sev-es-$V"

		run_cmd $MAKE distclean

		pushd linux >/dev/null
			run_cmd cp kernel-$V.config .config
			run_cmd ./scripts/config --set-str LOCALVERSION "$VER"
			run_cmd ./scripts/config --disable LOCALVERSION_AUTO
		popd >/dev/null

		run_cmd $MAKE olddefconfig

		# Build 
		run_cmd $MAKE >/dev/null

		if [ "$ID_LIKE" = "debian" ]; then
			run_cmd $MAKE bindeb-pkg
		else
			run_cmd $MAKE "RPMOPTS='--define \"_rpmdir .\"'" binrpm-pkg

			run_cmd mv linux/x86_64/*.rpm .
		fi
	done
}

build_install_ovmf()
{
	DEST="$1"

	GCC_VERSION=$(gcc -v 2>&1 | tail -1 | awk '{print $3}')
	GCC_MAJOR=$(echo $GCC_VERSION | awk -F . '{print $1}')
	GCC_MINOR=$(echo $GCC_VERSION | awk -F . '{print $2}')
	if [ "$GCC_MAJOR" == "4" ]; then
		GCCVERS="GCC${GCC_MAJOR}${GCC_MINOR}"
	else
		GCCVERS="GCC5"
	fi

	BUILD_CMD="nice build -q --cmd-len=64436 -DDEBUG_ON_SERIAL_PORT=TRUE -n $(getconf _NPROCESSORS_ONLN) ${GCCVERS:+-t $GCCVERS} -a X64 -p OvmfPkg/OvmfPkgX64.dsc"

	[ -d ovmf ] || {
		run_cmd git clone --single-branch -b ${OVMF_BRANCH} ${OVMF_GIT_URL} ovmf

		pushd ovmf >/dev/null
			run_cmd git submodule update --init --recursive
		popd >/dev/null
	}

	pushd ovmf >/dev/null
		run_cmd make -C BaseTools
		. ./edksetup.sh --reconfig
		run_cmd $BUILD_CMD

		mkdir -p $DEST
		run_cmd cp -f Build/OvmfX64/DEBUG_$GCCVERS/FV/OVMF_CODE.fd $DEST
		run_cmd cp -f Build/OvmfX64/DEBUG_$GCCVERS/FV/OVMF_VARS.fd $DEST
	popd >/dev/null
}

build_install_qemu()
{
	DEST="$1"

	[ -d qemu ] || run_cmd git clone --single-branch -b ${QEMU_BRANCH} ${QEMU_GIT_URL} qemu

	MAKE="make -j $(getconf _NPROCESSORS_ONLN) LOCALVERSION="

	pushd qemu >/dev/null
		run_cmd ./configure --target-list=x86_64-softmmu --prefix=$DEST
		run_cmd $MAKE
		run_cmd $MAKE install
	popd >/dev/null
}
