#!/bin/bash

. ../stable-commits

BUILD_DIR=`pwd`/src
NUM_OF_CORES=`grep -c ^processor /proc/cpuinfo`

run_cmd()
{
	echo "$*"

	$*
	if [ $? -ne 0 ]; then
		echo "ERROR: $*"
		exit 1
	fi
}

build_kernel()
{
	if [ ! -d $BUILD_DIR/linux ]; then
		run_cmd "mkdir -p ${BUILD_DIR}/linux"
		run_cmd "git clone --single-branch -b ${KERNEL_COMMIT} ${KERNEL_GIT_URL} ${BUILD_DIR}/linux"
	fi

	pushd $BUILD_DIR/linux
	run_cmd "cp /boot/config-$(uname -r) .config"
	./scripts/config --enable CONFIG_AMD_MEM_ENCRYPT
	./scripts/config --enable AMD_MEM_ENCRYPT_ACTIVE_BY_DEFAULT
	./scripts/config --enable CONFIG_KVM_AMD_SEV
	./scripts/config --disable CONFIG_DEBUG_INFO
	./scripts/config --enable CRYPTO_DEV_SP_PSP
	./scripts/config --module CRYPTO_DEV_CCP_DD
	./scripts/config --enable CONFIG_CRYPTO_DEV_CCP
	./scripts/config --disable CONFIG_LOCALVERSION_AUTO
	./scripts/config --disable CONFIG_HW_RANDOM_VIRTIO
	./scripts/config --disable CONFIG_CRYPTO_DEV_VIRTIO
	yes "" | make olddefconfig

	run_cmd "make -j `getconf _NPROCESSORS_ONLN` bindeb-pkg LOCALVERSION=-sev"
	popd
}

install_kernel()
{
	pushd $BUILD_DIR
	run_cmd "dpkg -i *.deb"
	popd
}

build_install_ovmf()
{
	if [ ! -d $BUILD_DIR/edk2 ]; then
		run_cmd "mkdir -p ${BUILD_DIR}/edk2"
		run_cmd "git clone ${EDK2_GIT_URL} ${BUILD_DIR}/edk2"
		pushd $BUILD_DIR/edk2
		run_cmd "git submodule update --init --recursive"
		popd
	fi

	pushd $BUILD_DIR/edk2
	run_cmd "make -C BaseTools"
	. ./edksetup.sh --reconfig
	run_cmd "nice build --cmd-len=64436 \
		-DDEBUG_ON_SERIAL_PORT=TRUE \
		-n $(getconf _NPROCESSORS_ONLN) \
		-a X64 \
		-a IA32 \
		-t GCC5 \
		-DSMM_REQUIRE \
		-DSECURE_BOOT_ENABLE=TRUE \
	        -p OvmfPkg/OvmfPkgIa32X64.dsc"
	run_cmd "mkdir -p /usr/local/share/qemu"
	run_cmd "cp Build/Ovmf3264/DEBUG_GCC5/FV/OVMF_CODE.fd $*"
	run_cmd "cp Build/Ovmf3264/DEBUG_GCC5/FV/OVMF_VARS.fd $*"
	popd
}

build_install_qemu()
{
	if [ ! -d $BUILD_DIR/qemu ]; then
		run_cmd "mkdir -p ${BUILD_DIR}/qemu"
		run_cmd "git clone --single-branch -b ${QEMU_COMMIT} ${QEMU_GIT_URL} ${BUILD_DIR}/qemu"
	fi

	pushd $BUILD_DIR/qemu
	run_cmd "./configure --target-list=x86_64-softmmu --prefix=$*"
	run_cmd "make -j$(getconf _NPROCESSORS_ONLN)"
	run_cmd "make -j$(getconf _NPROCESSORS_ONLN) install"
	popd
}
