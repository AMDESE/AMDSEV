#!/bin/bash

. ./stable-commits

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

	MAKE="make -j $(getconf _NPROCESSORS_ONLN) LOCALVERSION="

	pushd linux
	for V in hv guest; do
		VER="-sev-es-$V"

		run_cmd $MAKE clean
		run_cmd rm -rf .version

		[ -e ".config" ] || run_cmd cp /boot/config-$(uname -r) .config

		./scripts/config --enable AMD_MEM_ENCRYPT
		./scripts/config --enable AMD_MEM_ENCRYPT_ACTIVE_BY_DEFAULT
		./scripts/config --module KVM_AMD
		./scripts/config --enable KVM_AMD_SEV
		./scripts/config --enable KVM_AMD_SEV_ES
		./scripts/config --enable CRYPTO_DEV_CCP
		./scripts/config --module CRYPTO_DEV_CCP_DD
		./scripts/config --enable CRYPTO_DEV_SP_CCP
		./scripts/config --enable CRYPTO_DEV_SP_PSP
		./scripts/config --enable DYNAMIC_DEBUG
		./scripts/config --set-str LOCALVERSION "$VER"
		./scripts/config --disable LOCALVERSION_AUTO
		./scripts/config --disable RANDOMIZE_BASE
		./scripts/config --disable DEBUG_INFO
		[ "$V" = "guest" ] && {
			run_cmd ./scripts/config --enable AMD_SEV_ES_GUEST
		} || {
			run_cmd ./scripts/config --disable AMD_SEV_ES_GUEST
		}

		yes '' | run_cmd $MAKE oldconfig

		# Build 
		run_cmd $MAKE >/dev/null

		if [ "$ID_LIKE" = "debian" ]; then
			run_cmd $MAKE bindeb-pkg
		else
			run_cmd $MAKE "RPMOPTS='--define \"_rpmdir $(pwd)\"'" binrpm-pkg

			run_cmd mv x86_64/*.rpm ..
		fi
	done

	popd
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

		pushd ovmf
		run_cmd git submodule update --init --recursive
		popd
	}

	pushd ovmf
	run_cmd make -C BaseTools
	. ./edksetup.sh --reconfig
	run_cmd $BUILD_CMD

	mkdir -p $DEST
	run_cmd cp -f Build/OvmfX64/DEBUG_$GCCVERS/FV/OVMF_CODE.fd $DEST
	run_cmd cp -f Build/OvmfX64/DEBUG_$GCCVERS/FV/OVMF_VARS.fd $DEST
	popd
}

build_install_qemu()
{
	DEST="$1"

	[ -d qemu ] || run_cmd git clone --single-branch -b ${QEMU_BRANCH} ${QEMU_GIT_URL} qemu

	MAKE="make -j $(getconf _NPROCESSORS_ONLN) LOCALVERSION="

	pushd qemu
	run_cmd ./configure --target-list=x86_64-softmmu --prefix=$DEST
	run_cmd $MAKE
	run_cmd $MAKE install
	popd
}
