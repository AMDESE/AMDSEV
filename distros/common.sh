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
	yes "" | make olddefconfig

	run_cmd "make -j `getconf _NPROCESSORS_ONLN` bindeb-pkg LOCALVERSION=-sev"
	popd
}

install_kernel()
{
	pushd $BUILD_DIR
	run_cmd "sudo dpkg -i *.deb"
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
	run_cmd "sudo mkdir -p /usr/local/share/qemu"
	run_cmd "sudo cp Build/Ovmf3264/DEBUG_GCC5/FV/OVMF_CODE.fd $*"
	run_cmd "sudo cp Build/Ovmf3264/DEBUG_GCC5/FV/OVMF_VARS.fd $*"
	popd
}

build_install_kata_ovmf()
{
	if [ ! -d $BUILD_DIR/edk2-kata ]; then
		run_cmd "mkdir -p ${BUILD_DIR}/edk2-kata"
		run_cmd "git clone ${EDK2_GIT_URL} ${BUILD_DIR}/edk2-kata"
		pushd $BUILD_DIR/edk2-kata
		run_cmd "git submodule update --init --recursive"
		popd
	fi

	pushd $BUILD_DIR/edk2-kata
	run_cmd "make -C BaseTools"
	. ./edksetup.sh --reconfig
	run_cmd "nice build --cmd-len=64436 \
		-DDEBUG_ON_SERIAL_PORT=TRUE \
		-n $(getconf _NPROCESSORS_ONLN) \
		-a X64 \
		-t GCC5 \
	        -p OvmfPkg/OvmfPkgX64.dsc"
	run_cmd "sudo mkdir -p /usr/local/share/qemu"
	run_cmd "sudo cp Build/OvmfX64/DEBUG_GCC5/FV/OVMF_CODE.fd $*/OVMF_CODE.fd.kata"
	run_cmd "sudo cp Build/OvmfX64/DEBUG_GCC5/FV/OVMF_VARS.fd $*/OVMF_VARS.fd.kata"
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
	run_cmd "sudo make -j$(getconf _NPROCESSORS_ONLN) install"
	popd
}

build_install_kata_qemu()
{
	# Remove 'https://' from the repo url to be able to clone the repo using 'go get'
	QEMU_REPO=${QEMU_GIT_URL/https:\/\//}
	PACKAGING_REPO="github.com/kata-containers/packaging"
	QEMU_CONFIG_SCRIPT="${BUILD_DIR}/packaging/scripts/configure-hypervisor.sh"
	PREFIX=/usr/local

	if [ ! -d $BUILD_DIR/packaging ]; then
		run_cmd "git clone https://${PACKAGING_REPO}.git $BUILD_DIR/packaging"
	fi

	if [ ! -d ${BUILD_DIR}/qemu ]; then
		run_cmd "mkdir -p ${BUILD_DIR}/qemu"
		run_cmd "git clone --single-branch -b ${QEMU_COMMIT} ${QEMU_GIT_URL} ${BUILD_DIR}/qemu"
	fi

	pushd "${BUILD_DIR}/qemu"
	[ -d "capstone" ] || run_cmd "git clone https://github.com/qemu/capstone.git capstone"
	[ -d "ui/keycodemapdb" ] || run_cmd "git clone  https://github.com/qemu/keycodemapdb.git ui/keycodemapdb"

	# Apply required patches
	QEMU_PATCHES_PATH="${BUILD_DIR}/packaging/obs-packaging/qemu-lite/patches"
	run_cmd "git am -3  ${QEMU_PATCHES_PATH}/*.patch"

	echo "Build Qemu"
	run_cmd "make clean"
	PREFIX=${PREFIX} "${QEMU_CONFIG_SCRIPT}" "qemu" | xargs ./configure
	run_cmd "make -j $(getconf _NPROCESSORS_ONLN)"

	echo "Install Qemu"
	run_cmd "sudo -E make install"
	popd
}

install_kata()
{
	# If a kata config file exists, back it up
	config_file=/etc/kata-containers/configuration.toml
	[ -f ${config_file} ] && run_cmd "sudo mv ${config_file} ${config_file}.orig"

	# The default kata config is not bootable until the user chooses
	# how to pass the container roorfs. If a default kata config
	# exists, then make it bootable using the initrd image by
	# removing the 'image' line
	default_config=/usr/share/defaults/kata-containers/configuration.toml
	[ -f ${default_config} ] && sudo sed -i "s/^\(image =.*\)/# \1/g" ${default_config}

	# Install the packaged kata binaries using kata-manager
	repo="github.com/kata-containers/tests"
        [ ! -d ${BUILD_DIR}/tests ] && run_cmd "git clone https://$repo.git ${BUILD_DIR}/tests"
        pushd ${BUILD_DIR}/tests
	PATH=${PATH}:${BUILD_DIR}/tests/.ci
	go_dir=/usr/local
        run_cmd "sudo env PATH=${PATH} install_go.sh -d ${go_dir} 1.8"
        GOPATH=${HOME}/go
	PATH=${PATH}:${GOPATH}/bin:${go_dir}/go/bin:${BUILD_DIR}/tests/cmd/kata-manager
        run_cmd "go get -d $repo"
	run_cmd "sudo env PATH=${PATH} kata-manager.sh install-docker-system"
        popd

	# Build the kata-runtime with SEV support
	sudo curl https://raw.githubusercontent.com/golang/dep/master/install.sh | sh
	go get -d github.com/AMDESE/runtime
	pushd $GOPATH/src/github.com/AMDESE/runtime
	BRANCH="sev-v1.1.0"
	if git branch | grep ${BRANCH}; then
		run_cmd "git checkout ${BRANCH}"
		run_cmd "git checkout Gopkg.toml"
	else
		run_cmd "git checkout -b ${BRANCH} origin/${BRANCH}"
	fi
	cat >> Gopkg.toml <<- EOF

	[[override]]
	  name = "github.com/kata-containers/runtime"
	  source = "github.com/AMDESE/runtime"
	  branch = "sev-v1.1.0"

	[[override]]
	  name = "github.com/intel/govmm"
	  source = "github.com/AMDESE/govmm"
	  branch = "sev-v1.1.0"

	[[override]]
	  name = "github.com/intel-go/cpuid"
	  source = "github.com/AMDESE/cpuid"
	  branch = "sev"
	EOF
	run_cmd "tail -15 Gopkg.toml"
	run_cmd "dep ensure"
	run_cmd "make -j$(getconf _NPROCESSORS_ONLN)"
	run_cmd "sudo -E PATH=$PATH make install"
	popd
}

build_kata_kernel()
{
	if [ ! -d $BUILD_DIR/packaging ]; then
		run_cmd "git clone https://github.com/kata-containers/packaging.git $BUILD_DIR/packaging"
	fi

	if [ ! -d $BUILD_DIR/linux/ ]; then
		build_kernel
	fi

	pushd $BUILD_DIR/linux

	if ! git branch -r | grep ${KATA_KERNEL_COMMIT}; then
		run_cmd "git remote add -f -t ${KATA_KERNEL_COMMIT} kata ${KATA_KERNEL_GIT_URL}"
		run_cmd "git checkout -b ${KATA_KERNEL_COMMIT} kata/${KATA_KERNEL_COMMIT}"
	else
		run_cmd "git checkout kata/${KATA_KERNEL_COMMIT}"
	fi

	run_cmd "cp $BUILD_DIR/packaging/kernel/configs/x86_64_kata_kvm_* .config"
	./scripts/config --enable CONFIG_AMD_MEM_ENCRYPT
	./scripts/config --enable AMD_MEM_ENCRYPT_ACTIVE_BY_DEFAULT
	./scripts/config --enable CONFIG_KVM_AMD_SEV
	./scripts/config --disable CONFIG_DEBUG_INFO
	./scripts/config --disable CRYPTO_DEV_SP_PSP		# The PSP is not currently exposed to guests
	./scripts/config --disable CRYPTO_DEV_CCP_DD		# Ditto for the CCP
	./scripts/config --disable CONFIG_CRYPTO_DEV_CCP	# Same here
	./scripts/config --disable CONFIG_LOCALVERSION_AUTO
	./scripts/config --enable CONFIG_X86_PAT
	./scripts/config --disable CONFIG_CPU_SUP_INTEL
	./scripts/config --enable CONFIG_CPU_SUP_AMD
	yes "" | make olddefconfig
	run_cmd "make ARCH=x86_64 -j `getconf _NPROCESSORS_ONLN` LOCALVERSION=-${KATA_KERNEL_COMMIT}.container"
	run_cmd "sudo cp vmlinux /usr/share/kata-containers/vmlinux-${KATA_KERNEL_COMMIT}.container"
	run_cmd "sudo cp arch/x86_64/boot/bzImage /usr/share/kata-containers/vmlinuz-${KATA_KERNEL_COMMIT}.container"
	popd
}

configure_kata_runtime()
{
	config_file=/etc/systemd/system/docker.service.d/kata-containers.conf
	runtime="\/usr\/local\/bin\/kata-runtime"

	# Configure docker to use the SEV runtime
	if [ -f ${config_file} ]; then
		echo -n "Configuring ${config_file} for SEV..."
		sudo sed -i -e \
			"s/\(--add-runtime kata-runtime=[^ ]*kata-runtime\)/\1 --add-runtime sev-runtime=${runtime}/" ${config_file}
		sudo sed -i -e "s/--default-runtime=kata-runtime/--default-runtime=sev-runtime/" ${config_file}
		echo "Done."
		run_cmd "sudo systemctl daemon-reload"
		run_cmd "sudo systemctl restart docker"
	fi

	default_config=/usr/share/defaults/kata-containers/configuration.toml
	config_file=/etc/kata-containers/configuration.toml
	sev_qemu="\/usr\/local\/bin\/qemu-system-x86_64"
	sev_machine="q35"
	sev_kernel="\/usr\/share\/kata-containers\/vmlinuz-sev.container"
	sev_kernel_params="root=\/dev\/vda1 rootflags=data=ordered,errors=remount\-ro"
	sev_firmware="\/usr\/local\/share\/qemu\/OVMF_CODE\.fd.kata"
	sev_blk_dev_drv="virtio-blk"

	# Copy the default config to /etc
	run_cmd "sudo cp ${default_config} ${config_file}"

	echo -n "Configuring ${config_file} for SEV..."

	# Pass the container rootfs via initrd
	sudo sed -i "s/^\(image =.*\)/# \1/g" ${config_file}

	# Set the SEV qemu
	sudo sed -i "s/^path *=.*qemu.*\$/path = \"${sev_qemu}\"/g" $config_file

	# Set the SEV machine type
	sudo sed -i "s/^machine_type *=.*\$/machine_type = \"${sev_machine}\"/g" $config_file

	# Set the SEV kernel
	sudo sed -i "s/^kernel *=.*\$/kernel = \"${sev_kernel}\"/g" $config_file

	# Set the SEV OVMF firmware
	sudo sed -i "s/^firmware *=.*\$/firmware = \"${sev_firmware}\"/g" $config_file

	# Set the default block device driver
	sudo sed -i "s/^block_device_driver *=.*\$/block_device_driver = \"${sev_blk_dev_drv}\"/g" $config_file

	# Set the default block device driver
	sudo sed -i "s/^block_device_driver *=.*\$/block_device_driver = \"${sev_blk_dev_drv}\"/g" $config_file

	# Enable memory encryption
	sudo sed -i -e "s/^# *\(enable_mem_encryption\).*=.*$/\1 = true/g" $config_file

	# When booting from the rootfs image, the rootfs is on the vda device
	sudo sed -i -e "s/^kernel_params = \"\(.*\)\"/kernel_params = \"\1 ${sev_kernel_params[*]}\"/g" $config_file

	# Enable all debug options
	sudo sed -i -e "s/^# *\(enable_debug\).*=.*$/\1 = true/g" ${config_file}
	sudo sed -i -e "s/^kernel_params = \"\(.*\)\"/kernel_params = \"\1 agent.log=debug initcall_debug\"/g" ${config_file}

	# Remove any "//" occurances
	sudo sed -i -e "s/\/\//\//g" ${config_file}

	echo "Done."
}

