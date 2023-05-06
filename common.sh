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
	set -x
	kernel_type=$1
	shift
	mkdir -p linux
	pushd linux >/dev/null

	if [ ! -d guest ]; then
		run_cmd git clone ${KERNEL_GIT_URL} guest
		pushd guest >/dev/null
		run_cmd git remote add current ${KERNEL_GIT_URL}
		popd
	fi

	if [ ! -d host ]; then
		# use a copy of guest repo as the host repo
		run_cmd cp -r guest host
	fi

	for V in guest host; do
		# Check if only a "guest" or "host" or kernel build is requested
		if [ "$kernel_type" != "" ]; then
			if [ "$kernel_type" != "$V" ]; then
				continue
			fi
		fi

		if [ "${V}" = "guest" ]; then
			BRANCH="${KERNEL_GUEST_BRANCH}"
		else
			BRANCH="${KERNEL_HOST_BRANCH}"
		fi

		# Nuke any previously built packages so they don't end up in new tarballs
		# when ./build.sh --package is specified
		rm -f linux-*-snp-${V}*

		VER="-snp-${V}"

		MAKE="make -C ${V} -j $(getconf _NPROCESSORS_ONLN) LOCALVERSION="

		run_cmd $MAKE distclean

		pushd ${V} >/dev/null
			# If ${KERNEL_GIT_URL} is ever changed, 'current' remote will be out
			# of date, so always update the remote URL first
			run_cmd git remote set-url current ${KERNEL_GIT_URL}
			run_cmd git fetch current
			run_cmd git checkout current/${BRANCH}
			COMMIT=$(git log --format="%h" -1 HEAD)

			run_cmd "cp /boot/config-$(uname -r) .config"
			run_cmd ./scripts/config --set-str LOCALVERSION "$VER-$COMMIT"
			run_cmd ./scripts/config --disable LOCALVERSION_AUTO
			run_cmd ./scripts/config --enable  DEBUG_INFO
			run_cmd ./scripts/config --enable  DEBUG_INFO_REDUCED
			run_cmd ./scripts/config --enable  AMD_MEM_ENCRYPT
			run_cmd ./scripts/config --disable AMD_MEM_ENCRYPT_ACTIVE_BY_DEFAULT
			run_cmd ./scripts/config --enable  KVM_AMD_SEV
			run_cmd ./scripts/config --module  CRYPTO_DEV_CCP_DD
			run_cmd ./scripts/config --disable SYSTEM_TRUSTED_KEYS
			run_cmd ./scripts/config --disable SYSTEM_REVOCATION_KEYS
			run_cmd ./scripts/config --module  SEV_GUEST
			run_cmd ./scripts/config --disable IOMMU_DEFAULT_PASSTHROUGH
			run_cmd ./scripts/config --disable PREEMPT_COUNT
			run_cmd ./scripts/config --disable PREEMPTION
			run_cmd ./scripts/config --disable PREEMPT_DYNAMIC
			run_cmd ./scripts/config --disable DEBUG_PREEMPT
			run_cmd ./scripts/config --enable  CGROUP_MISC
		popd >/dev/null

		yes "" | $MAKE olddefconfig

		# Build 
		run_cmd $MAKE >/dev/null

		if [ "$ID" = "debian" ] || [ "$ID_LIKE" = "debian" ]; then
			run_cmd $MAKE bindeb-pkg
		else
			run_cmd $MAKE "RPMOPTS='--define \"_rpmdir .\"'" binrpm-pkg
			run_cmd mv ${V}/x86_64/*.rpm .
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

	# A race condition exists in edk2 build - set threads to 1 for now
	# Previous value: -n $(getconf _NPROCESSORS_ONLN)
	# Only seen the error on Bergamo systems
	BUILD_CMD="nice build -q --cmd-len=64436 -DDEBUG_ON_SERIAL_PORT=TRUE -n 1 ${GCCVERS:+-t $GCCVERS} -a X64 -p OvmfPkg/AmdSev/AmdSevX64.dsc"

	[ -d ovmf ] || {
		run_cmd git clone --single-branch -b ${OVMF_BRANCH} ${OVMF_GIT_URL} ovmf

		pushd ovmf >/dev/null
			run_cmd git submodule update --init --recursive
		popd >/dev/null
	}

	pushd ovmf >/dev/null
		run_cmd make -C BaseTools
		. ./edksetup.sh --reconfig
		touch OvmfPkg/AmdSev/Grub/grub.efi
		run_cmd $BUILD_CMD

		mkdir -p $DEST
		run_cmd cp -f Build/AmdSev/DEBUG_$GCCVERS/FV/OVMF.fd $DEST
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
