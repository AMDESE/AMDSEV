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

		# If ${KERNEL_GIT_URL} is ever changed, 'current' remote will be out
		# of date, so always update the remote URL first. Also handle case
		# where AMDSEV scripts are updated while old kernel repos are still in
		# the directory without a 'current' remote
		pushd ${V} >/dev/null
		if git remote get-url current 2>/dev/null; then
			run_cmd git remote set-url current ${KERNEL_GIT_URL}
		else
			run_cmd git remote add current ${KERNEL_GIT_URL}
		fi
		popd >/dev/null

		# Nuke any previously built packages so they don't end up in new tarballs
		# when ./build.sh --package is specified
		rm -f linux-*-snp-${V}*

		VER="-snp-${V}"

		MAKE="make -C ${V} -j $(getconf _NPROCESSORS_ONLN) LOCALVERSION="

		run_cmd $MAKE distclean

		pushd ${V} >/dev/null
			run_cmd git fetch current
			run_cmd git checkout current/${BRANCH}
			COMMIT=$(git log --format="%h" -1 HEAD)

			run_cmd "cp /boot/config-$(uname -r) .config"
			run_cmd ./scripts/config --set-str LOCALVERSION "$VER-$COMMIT"
			run_cmd ./scripts/config --disable LOCALVERSION_AUTO
			run_cmd ./scripts/config --enable  EXPERT
			run_cmd ./scripts/config --enable  DEBUG_INFO
			run_cmd ./scripts/config --enable  DEBUG_INFO_REDUCED
			run_cmd ./scripts/config --enable  AMD_MEM_ENCRYPT
			run_cmd ./scripts/config --disable AMD_MEM_ENCRYPT_ACTIVE_BY_DEFAULT
			run_cmd ./scripts/config --enable  KVM_AMD_SEV
			run_cmd ./scripts/config --module  CRYPTO_DEV_CCP_DD
			run_cmd ./scripts/config --disable SYSTEM_TRUSTED_KEYS
			run_cmd ./scripts/config --disable SYSTEM_REVOCATION_KEYS
			run_cmd ./scripts/config --disable MODULE_SIG_KEY
			run_cmd ./scripts/config --module  SEV_GUEST
			run_cmd ./scripts/config --disable IOMMU_DEFAULT_PASSTHROUGH
			run_cmd ./scripts/config --disable PREEMPT_COUNT
			run_cmd ./scripts/config --disable PREEMPTION
			run_cmd ./scripts/config --disable PREEMPT_DYNAMIC
			run_cmd ./scripts/config --disable DEBUG_PREEMPT
			run_cmd ./scripts/config --enable  CGROUP_MISC
			run_cmd ./scripts/config --module  X86_CPUID
			run_cmd ./scripts/config --disable UBSAN
			run_cmd ./scripts/config --disable MLX4_EN
			run_cmd ./scripts/config --module MLX4_EN
			run_cmd ./scripts/config --enable MLX4_EN_DCB
			run_cmd ./scripts/config --module MLX4_CORE
			run_cmd ./scripts/config --enable MLX4_DEBUG
			run_cmd ./scripts/config --enable MLX4_CORE_GEN2
			run_cmd ./scripts/config --module MLX5_CORE
			run_cmd ./scripts/config --enable MLX5_FPGA
			run_cmd ./scripts/config --enable MLX5_CORE_EN
			run_cmd ./scripts/config --enable MLX5_EN_ARFS
			run_cmd ./scripts/config --enable MLX5_EN_RXNFC
			run_cmd ./scripts/config --enable MLX5_MPFS
			run_cmd ./scripts/config --enable MLX5_ESWITCH
			run_cmd ./scripts/config --enable MLX5_BRIDGE
			run_cmd ./scripts/config --enable MLX5_CLS_ACT
			run_cmd ./scripts/config --enable MLX5_TC_CT
			run_cmd ./scripts/config --enable MLX5_TC_SAMPLE
			run_cmd ./scripts/config --enable MLX5_CORE_EN_DCB
			run_cmd ./scripts/config --enable MLX5_CORE_IPOIB
			run_cmd ./scripts/config --enable MLX5_SW_STEERING
			run_cmd ./scripts/config --module MLXSW_CORE
			run_cmd ./scripts/config --enable MLXSW_CORE_HWMON
			run_cmd ./scripts/config --enable MLXSW_CORE_THERMAL
			run_cmd ./scripts/config --module MLXSW_PCI
			run_cmd ./scripts/config --module MLXSW_I2C
			run_cmd ./scripts/config --module MLXSW_SPECTRUM
			run_cmd ./scripts/config --enable MLXSW_SPECTRUM_DCB
			run_cmd ./scripts/config --module MLXSW_MINIMAL
			run_cmd ./scripts/config --module MLXFW

			run_cmd echo $COMMIT >../../source-commit.kernel.$V
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

	BUILD_CMD="nice build -q --cmd-len=64436 -DDEBUG_ON_SERIAL_PORT=TRUE -n $(getconf _NPROCESSORS_ONLN) ${GCCVERS:+-t $GCCVERS} -a X64 -p OvmfPkg/OvmfPkgX64.dsc"

	# initialize git repo, or update existing remote to currently configured one
	if [ -d ovmf ]; then
		pushd ovmf >/dev/null
		if git remote get-url current 2>/dev/null; then
			run_cmd git remote set-url current ${OVMF_GIT_URL}
		else
			run_cmd git remote add current ${OVMF_GIT_URL}
		fi
		popd >/dev/null
	else
		run_cmd git clone --single-branch -b ${OVMF_BRANCH} ${OVMF_GIT_URL} ovmf
		pushd ovmf >/dev/null
		run_cmd git remote add current ${OVMF_GIT_URL}
		popd >/dev/null
	fi

	pushd ovmf >/dev/null
		run_cmd git fetch current
		run_cmd git checkout current/${OVMF_BRANCH}
		run_cmd git submodule update --init --recursive
		run_cmd make -C BaseTools
		. ./edksetup.sh --reconfig
		run_cmd $BUILD_CMD

		mkdir -p $DEST
		run_cmd cp -f Build/OvmfX64/DEBUG_$GCCVERS/FV/OVMF_CODE.fd $DEST
		run_cmd cp -f Build/OvmfX64/DEBUG_$GCCVERS/FV/OVMF_VARS.fd $DEST

		COMMIT=$(git log --format="%h" -1 HEAD)
		run_cmd echo $COMMIT >../source-commit.ovmf
	popd >/dev/null
}

build_install_qemu()
{
	DEST="$1"

	# initialize git repo, or update existing remote to currently configured one
	if [ -d qemu ]; then
		pushd qemu >/dev/null
		if git remote get-url current 2>/dev/null; then
			run_cmd git remote set-url current ${QEMU_GIT_URL}
		else
			run_cmd git remote add current ${QEMU_GIT_URL}
		fi
		popd >/dev/null
	else
		run_cmd git clone --single-branch -b ${QEMU_BRANCH} ${QEMU_GIT_URL} qemu
		pushd qemu >/dev/null
		run_cmd git remote add current ${QEMU_GIT_URL}
		popd >/dev/null
	fi

	MAKE="make -j $(getconf _NPROCESSORS_ONLN) LOCALVERSION="

	pushd qemu >/dev/null
		run_cmd git fetch current
		run_cmd git checkout current/${QEMU_BRANCH}
		run_cmd ./configure --target-list=x86_64-softmmu --prefix=$DEST
		run_cmd $MAKE
		run_cmd $MAKE install

		COMMIT=$(git log --format="%h" -1 HEAD)
		run_cmd echo $COMMIT >../source-commit.qemu
	popd >/dev/null
}
