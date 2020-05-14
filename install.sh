#!/bin/bash

. /etc/os-release

# This will install all the dependent packages for qemu and ovmf to run
if [ "$ID_LIKE" = "debian" ]; then
	apt-get -y install qemu ovmf
else
	dnf install qemu edk2-ovmf
fi

if [ "$ID_LIKE" = "debian" ]; then
	dpkg -i linux/linux-image-*.deb
else
	rpm -ivh linux/kernel-*.rpm
fi

# update grub.cfg to disable THP
if ! grep "transparent_hugepage=never" /etc/default/grub >/dev/null; then
	orig_cmdline="`grep GRUB_CMDLINE_LINUX /etc/default/grub | cut -f2- -d=`"
	cmdline="${orig_cmdline::-1}"
	cmdline="${cmdline:1}"
	cmdline="${cmdline} transparent_hugepage=never"

	sed -i "/GRUB_CMDLINE_LINUX/c\GRUB_CMDLINE_LINUX=\"${cmdline}\"" /etc/default/grub

	if [ "$ID_LIKE" = "debian" ]; then
		update-grub2
	else
		grub2-mkconfig
	fi
fi

# 
cp kvm.conf /etc/modprobe.d/

echo
echo "Reboot the host and select the SNP kernel"
echo
