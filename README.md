# Secure Encrypted Virtualization (SEV)

SEV is an extension to the AMD-V architecture which supports running encrypted
virtual machine (VMs) under the control of KVM. Encrypted VMs have their pages
(code and data) secured such that only the guest itself has access to the
unencrypted version. Each encrypted VM is associated with a unique encryption
key; if its data is accessed to a different entity using a different key the
encrypted guests data will be incorrectly decrypted, leading to unintelligible
data. 

## Getting Started

SEV support has been accepted in upstream projects. This repository provides
scripts to build various components to enable SEV support until the distros
pick the newer version of components.

To enable the SEV support we need the following versions:
kernel >= 4.16
qemu >= 2.15
libvirt >= 4.5
ovmf  >= commit  (75b7aa9528bd 2018-07-06 OvmfPkg/QemuFlashFvbServicesRuntimeDxe: Restore C-bit when SEV is active)

NOTES: 

1. Installing newer libvirt may conflict with existing setups hence script does
   not install the newer version of libvirt. If you are interested in launching
   SEV guest through the virsh commands then build and install libvirt 4.5 or
   higher. Use LaunchSecurity tag https://libvirt.org/formatdomain.html#sev for
   creating the SEV enabled guest.

2. SEV support is not available in SeaBIOS. Guest must use OVMF.


## SLES-15

SUSE Linux Enterprise Server 15 GA includes the SEV support; we do not need
to compile the sources.

NOTE: SLES-15 does not contain the updated libvirt packages yet hence we will
use QEMU command line interface to launch VMs.

### Prepare Host OS

SEV is not enabled by default, lets enable it through kernel command line:

Append the following in /etc/defaults/grub

```
GRUB_CMDLINE_LINUX_DEFAULT=".... mem_encrypt=on kvm_amd.sev=1"
```

Regenerate grub.cfg and reboot the host

```
# grub2-mkconfig -o /boot/efi/EFI/sles/grub.cfg
# reboot
```

Install the qemu launch script

```
# cd distros/sles-15
# ./build.sh
```

### Prepare VM image

Create empty virtual disk image

```
# qemu-img create -f qcow2 sles-15.qcow2 30G
```

Create a new copy of OVMF_VARS.fd. The OVMF_VARS.fd is a "template" used
to emulate persistent NVRAM storage. Each VM needs a private, writable
copy of VARS.fd.

```
#cp /usr/share/qemu/ovmf-x86_64-suse-4m-vars.bin OVMF_VARS.fd 
```

Download and install sles-15 guest

```
# launch-qemu.sh -hda sles-15.qcow2 -cdrom SLE-15-Installer-DVD-x86_64-GM-DVD1.iso
```
Follow the screen to complete the guest installation.

### Launch VM

Use the following command to launch SEV guest

```
# launch-qemu.sh -hda sles-15.qcow2
```
NOTE: when guest is booting, CTRL-C is mapped to CTRL-], use CTRL-] to stop the guest

## Fedora-28

Fedora-28 includes newer kernel and ovmf packages but has older version qemu.

### Prepare Host OS

SEV is not enabled by default, lets enable it through kernel command line:

Append the following in /etc/defaults/grub

```
GRUB_CMDLINE_LINUX_DEFAULT=".... mem_encrypt=on kvm_amd.sev=1"
```

Regenerate grub.cfg and reboot the host

```
# grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg
# reboot
```

Build and install newer qemu

```
# cd distros/fedora-28
# ./build.sh
```

### Prepare VM image

Create empty virtual disk image

```
# qemu-img create -f qcow2 fedora-28.qcow2 30G
```

Create a new copy of OVMF_VARS.fd. The OVMF_VARS.fd is a "template" used
to emulate persistent NVRAM storage. Each VM needs a private, writable
copy of VARS.fd.

```
# cp /usr/share/OVMF/OVMF_VARS.fd OVMF_VARS.fd
```

Download and install fedora-28 guest

```
# launch-qemu.sh -hda fedora-28.qcow2 -cdrom  Fedora-Workstation-netinst-x86_64-28-1.1.iso
```
Follow the screen to complete the guest installation.

### Launch VM

Use the following command to launch SEV guest

```
# launch-qemu.sh -hda fedora-28.qcow2
```

NOTE: when guest is booting, CTRL-C is mapped to CTRL-], use CTRL-] to stop the guest


## Ubuntu 18.04

Ubuntu 18.04 does not includes the newer version of components to be used as SEV
hypervisor hence we will build and install newer kernel, qemu, ovmf.

### Prepare Host OS

Build and install newer components

```
# cd distros/ubuntu-18.04
# ./build.sh
```

### Prepare VM image

Create empty virtual disk image

```
# qemu-img create -f qcow2 ubuntu-18.04.qcow2 30G
```

Create a new copy of OVMF_VARS.fd. The OVMF_VARS.fd is a "template" used
to emulate persistent NVRAM storage. Each VM needs a private, writable
copy of VARS.fd.

```
# cp /usr/local/share/qemu/OVMF_VARS.fd OVMF_VARS.fd
```

Install ubuntu-18.04 guest

```
# launch-qemu.sh -hda ubuntu-18.04.qcow2 -cdrom ubuntu-18.04-desktop-amd64.iso
```
Follow the screen to complete the guest installation.

### Launch VM

Use the following command to launch SEV guest

```
# launch-qemu.sh -hda ubuntu-18.04.qcow2
```
NOTE: when guest is booting, CTRL-C is mapped to CTRL-], use CTRL-] to stop the guest
