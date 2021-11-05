#!/bin/bash

[ -e /etc/os-release ] && . /etc/os-release

# This will install all the dependent packages for qemu and ovmf to run
if [[ "$ID_LIKE" = "debian" || "$ID" = "debian" ]]; then
	apt-get -y install qemu ovmf
else
	dnf install qemu edk2-ovmf
fi

if [[ "$ID_LIKE" = "debian" || "$ID" = "debian" ]]; then
	dpkg -i linux/linux-image-*.deb
else
	rpm -ivh linux/kernel-*.rpm
fi

cp kvm.conf /etc/modprobe.d/

echo
echo "Reboot the host and select the SNP kernel"
echo
