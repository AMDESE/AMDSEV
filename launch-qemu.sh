#!/bin/bash

#
# user changeable parameters
#
HDA_FILE="${HOME}/ubuntu-16.04-desktop.qcow2"
GUEST_SIZE_IN_MB="2048"
SEV_GUEST="1"
SMP_NCPUS="4"
CONSOLE="serial"
QEMU_INSTALL_DIR=`pwd`/bin/
UEFI_BIOS_CODE="`pwd`/share/qemu/OVMF_CODE.fd"
UEFI_BIOS_VARS="`pwd`/OVMF_VARS.fd"
#VNC_PORT=""
AUTOSTART="1"
ALLOW_DEBUG="0"
USE_VIRTIO="0"

usage() {
	echo "$0 [options]"
	echo "Available <commands>:"
	echo " -hda          hard disk ($HDA_FILE)"
	echo " -nosev        disable sev support"
	echo " -mem          guest memory"
	echo " -smp          number of cpus"
	echo " -console      display console to use (serial or graphics)"
	echo " -vnc          VNC port to use"
	echo " -bios         bios to use (default $UEFI_BIOS_CODE)"
	echo " -kernel       kernel to use"
	echo " -initrd       initrd to use"
	echo " -noauto       do not autostart the guest"
	echo " -cdrom        CDROM image"
	echo " -hugetlb      use hugetlbfs"
	echo " -allow-debug  allow debugging the VM"
	echo " -novirtio     do not use virtio devices"
	exit 1  
}

add_opts() {
	echo -n "$* " >> ${QEMU_CMDLINE}
}

stop_network() {
	if [ "$GUEST_TAP_NAME" = "" ]; then
		return
  	fi
	run_cmd "ip tuntap del ${GUEST_TAP_NAME} mode tap"
}

exit_from_int() {
	stop_network

	rm -rf ${QEMU_CMDLINE}
	# restore the mapping
	stty intr ^c
	exit 1
}

run_cmd () {
	$*
	if [ $? -ne 0 ]; then
		echo "command $* failed"
		exit 1
	fi
}

setup_hugetlbfs() {
	HUGETLBFS=`mount | grep hugetlbfs | awk {'print $3'}`
	if [ "${HUGETLBFS}" = "" ]; then
		HUGETLBFS="/hugetlbfs"
		run_cmd "mkdir -p $HUGETLBFS"
		echo "Mounting $HUGETLBFS..."
		run_cmd "mount -t hugetlbfs nodev $HUGETLBFS"
	fi
	# calculate number of hugepage we need for the guest
	HPAGES=$((($GUEST_SIZE_IN_MB / 2) + 50))
	echo -n "Setting hugepage count "
	echo $HPAGES | sudo tee /proc/sys/vm/nr_hugepages

	add_opts "-mem-path ${HUGETLBFS}"
}

setup_bridge_network() {
	# Get last tap device on host
	TAP_NUM=`ifconfig | grep tap | tail -1 | cut -c4- | cut -f1 -d ' ' | cut -f1 -d:`
	if [ "$TAP_NUM" = "" ]; then
		TAP_NUM="1"
	fi
	TAP_NUM=`echo $(( TAP_NUM + 1 ))`
	GUEST_TAP_NAME="tap${TAP_NUM}"
	GUEST_MAC_ADDR=$(printf "02:16:1e:%02x:01:01" 0x${TAP_NUM})

	echo "Starting network adapter '${GUEST_TAP_NAME}' MAC=$GUEST_MAC_ADDR"
	run_cmd "ip tuntap add $GUEST_TAP_NAME mode tap user `whoami`"
	run_cmd "ip link set $GUEST_TAP_NAME up"
	run_cmd "ip link set $GUEST_TAP_NAME master br0"

	if [ "$USE_VIRTIO" = "1" ]; then
		add_opts "-netdev type=tap,script=no,downscript=no,id=net0,ifname=$GUEST_TAP_NAME"
		add_opts "-device virtio-net-pci,netdev=net0,disable-legacy=on,iommu_platform=true,romfile="
	else
		add_opts "-device e1000,mac=${GUEST_MAC_ADDR},netdev=net0"
		add_opts "-netdev tap,id=net0,ifname=$GUEST_TAP_NAME,script=no,downscript=no"
	fi
}

trap exit_from_int SIGINT

if [ `id -u` -ne 0 ]; then
	echo "Must be run as root!"
	exit 1
fi

while [[ $1 != "" ]]; do
	case "$1" in
		-hda) 		HDA_FILE="${2}"
				shift
				;;
		-nosev) 	SEV_GUEST="0"
				;;
		-mem)  		GUEST_SIZE_IN_MB=${2}
				shift
				;;
		-console)	CONSOLE=${2}
				shift
				;;
		-smp)		SMP_NCPUS=$2
				shift
				;;
		-vnc)		VNC_PORT=$2
				shift
				if [ "${VNC_PORT}" = "" ]; then
					usage
				fi
				;;
		-bios)		UEFI_BIOS_CODE="`readlink -f $2`"
				shift
				;;
		-netconsole)	NETCONSOLE_PORT=$2
				shift
				;;
		-initrd)	INITRD_FILE=$2
				shift
				;;
		-kernel)	KERNEL_FILE=$2
				shift
				;;
		-cdrom)		CDROM_FILE=$2
				shift
				;;
        	-noauto)	AUTOSTART="0"
				;;
		-hugetlb)	USE_HUGETLBFS="1"
				;;
		-allow-debug)   ALLOW_DEBUG="1"
				;;
		-novirtio)      USE_VIRTIO="0"
				;;
		*) 		usage;;
	esac
	shift
done

# we add all the qemu command line options into a file
QEMU_CMDLINE=/tmp/cmdline.$$
rm -rf ${QEMU_CMDLINE}

add_opts "${QEMU_INSTALL_DIR}qemu-system-x86_64"

# Basic virtual machine property
add_opts "-enable-kvm -cpu EPYC"

# add number of VCPUs
[ ! -z ${SMP_NCPUS} ] && add_opts "-smp ${SMP_NCPUS},maxcpus=64"

# define guest memory
add_opts "-m ${GUEST_SIZE_IN_MB}M,slots=5,maxmem=30G"

# The OVMF binary, including the non-volatile variable store, appears as a
# "normal" qemu drive on the host side, and it is exposed to the guest as a
# persistent flash device.
add_opts "-drive if=pflash,format=raw,unit=0,file=${UEFI_BIOS_CODE},readonly"
add_opts "-drive if=pflash,format=raw,unit=1,file=${UEFI_BIOS_VARS}"

# add CDROM if specified
[ ! -z ${CDROM_FILE} ] && add_opts "-drive file=${CDROM_FILE},media=cdrom,index=0"

# If harddisk file is specified then add the HDD drive
if [ ! -z ${HDA_FILE} ]; then
	if [ "$USE_VIRTIO" = "1" ]; then
		if [[ ${HDA_FILE} = *"qcow2" ]]; then
			add_opts "-drive file=${HDA_FILE},if=none,id=disk0,format=qcow2"
		else
			add_opts "-drive file=${HDA_FILE},if=none,id=disk0,format=raw"
		fi
		add_opts "-device virtio-scsi-pci,id=scsi,disable-legacy=on,iommu_platform=true"
		add_opts "-device scsi-hd,drive=disk0"
		# virtio-blk
		# add_opts "-device virtio-blk-pci,drive=disk0,disable-legacy=on,iommu_platform=true"
	else
		if [[ ${HDA_FILE} = *"qcow2" ]]; then
			add_opts "-drive file=${HDA_FILE},format=qcow2"
		else
			add_opts "-drive file=${HDA_FILE},format=raw"
		fi
	fi
fi

# If this is SEV guest then add the encryption device objects to enable support
if [ ${SEV_GUEST} = "1" ]; then
	if [ "${ALLOW_DEBUG}" = "1" ]; then
		SEV_DEBUG_POLICY=",policy=0x0"
	fi
	add_opts "-object sev-guest,id=sev0${SEV_DEBUG_POLICY}"
	add_opts "-machine memory-encryption=sev0"
fi

# if we are asked to use hugetlbfs
[ ! -z ${USE_HUGETLBFS} ] && setup_hugetlbfs

# if console is serial then disable graphical interface
if [ "${CONSOLE}" = "serial" ]; then
	add_opts "-nographic"
fi

# if -kernel arg is specified then use the kernel provided in command line for boot
if [ "${KERNEL_FILE}" != "" ]; then
	add_opts "-kernel $KERNEL_FILE"
	add_opts "-append \"console=ttyS0 earlyprintk=serial root=/dev/sda2\""
	[ ! -z ${INITRD_FILE} ] && add_opts "-initrd ${INITRD_FILE}"
fi

# start vnc server
[ ! -z ${VNC_PORT} ] && add_opts "-vnc :${VNC_PORT}" && echo "Starting VNC on port ${VNC_PORT}"

# start monitor on pty and named socket 'monitor'
add_opts "-monitor pty -monitor unix:monitor,server,nowait"

# do we do not need to autostart the guest
if [ "${AUTOSTART}" = "0" ]; then
	echo "Disabling autostart"
	add_opts "-S"
fi

# check if host has bridge network
BR0_STATUS="`ifconfig | grep br0`"
if [ "$BR0_STATUS" != "" ]; then
	setup_bridge_network
fi

# start gdbserver
add_opts "-s"

# add virtio ring
if [ "$USE_VIRTIO" = "1" ]; then
	add_opts "-device virtio-rng-pci,disable-legacy=on,iommu_platform=true"
fi

# log the console  output in stdout.log
QEMU_CONSOLE_LOG=`pwd`/stdout.log

# save the command line args into log file
cat $QEMU_CMDLINE | tee ${QEMU_CONSOLE_LOG}
echo | tee -a ${QEMU_CONSOLE_LOG}


# map CTRL-C to CTRL ]
echo "Mapping CTRL-C to CTRL-]"
stty intr ^]

echo "Launching VM ..."
bash ${QEMU_CMDLINE} 2>&1 | tee -a ${QEMU_CONSOLE_LOG}

# restore the mapping
stty intr ^c

rm -rf ${QEMU_CMDLINE}
stop_network
