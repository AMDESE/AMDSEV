# Table of contents
* [ Introduction ](#intro)
* [ SLES-15 ](#sles-15)
  * [ Prepare Host OS ](#sles-15-host)
  * [ Prepare VM ](#sles-15-prep-vm)
  * [ Launch SEV VM ](#sles-15-launch-vm)
* [ Fedora-28 ](#fc-28)
  * [ Prepare Host OS ](#fc-28-host)
  * [ Prepare VM ](#fc-28-prep-vm)
  * [ Launch SEV VM ](#fc-28-launch-vm)
* [ Ubuntu-18.04 ](#ubuntu18)
  * [ Prepare Host OS ](#ubuntu18-host)
  * [ Prepare VM ](#ubuntu18-prep-vm)
  * [ Launch SEV VM ](#ubuntu18-launch-vm)
* [ Additional resources ](#resources)
* [ FAQ ](#faq)
  * [ How do I know if Hypervisor supports SEV ](#faq-1)
  * [ How do I know if SEV is enabled in the guest](#faq-2)
  
<a name="intro"></a>
# Secure Encrypted Virtualization (SEV)

SEV is an extension to the AMD-V architecture which supports running encrypted
virtual machine (VMs) under the control of KVM. Encrypted VMs have their pages
(code and data) secured such that only the guest itself has access to the
unencrypted version. Each encrypted VM is associated with a unique encryption
key; if its data is accessed to a different entity using a different key the
encrypted guests data will be incorrectly decrypted, leading to unintelligible
data. 

SEV support has been accepted in upstream projects. This repository provides
scripts to build various components to enable SEV support until the distros
pick the newer version of components.

To enable the SEV support we need the following versions.

| Project       | Version                              |
| ------------- |:------------------------------------:|
| kernel        | >= 4.16                              |
| libvirt       | >= 4.5                               |
| qemu          | >= 2.12                              |
| ovmf          | >= commit (75b7aa9528bd 2018-07-06 ) |

> * Installing newer libvirt may conflict with existing setups hence script does
>   not install the newer version of libvirt. If you are interested in launching
>   SEV guest through the virsh commands then build and install libvirt 4.5 or
>   higher. Use LaunchSecurity tag https://libvirt.org/formatdomain.html#sev for
>   creating the SEV enabled guest.
>
> * SEV support is not available in SeaBIOS. Guest must use OVMF.

<a name="sles-15"></a>

## SLES-15

SUSE Linux Enterprise Server 15 GA includes the SEV support; we do not need
to compile the sources.

> SLES-15 does not contain the updated libvirt packages yet hence we will
use QEMU command line interface to launch VMs.

<a name="sles-15-host"></a>
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
<a name="sles-15-prep-vm"></a>
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
# launch-qemu.sh -hda sles-15.qcow2 -cdrom SLE-15-Installer-DVD-x86_64-GM-DVD1.iso -nosev
```
Follow the screen to complete the guest installation.

<a name="sles-15-launch-vm"></a>
### Launch VM

Use the following command to launch SEV guest

```
# launch-qemu.sh -hda sles-15.qcow2
```
NOTE: when guest is booting, CTRL-C is mapped to CTRL-], use CTRL-] to stop the guest

<a name="fc-28"></a>
## Fedora-28

Fedora-28 includes newer kernel and ovmf packages but has older qemu. We will need to update the QEMU to launch SEV guest.

<a name="fc-28-host"></a>
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

<a name="fc-28-prep-vm"></a>
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

<a name="fc-28-launch-vm"></a>
### Launch VM

Use the following command to launch SEV guest

```
# launch-qemu.sh -hda fedora-28.qcow2
```

NOTE: when guest is booting, CTRL-C is mapped to CTRL-], use CTRL-] to stop the guest

<a name="ubuntu18"></a>
## Ubuntu 18.04

Ubuntu 18.04 does not includes the newer version of components to be used as SEV
hypervisor hence we will build and install newer kernel, qemu, ovmf.

<a name="ubuntu18-host"></a>
### Prepare Host OS

Build and install newer components

```
# cd distros/ubuntu-18.04
# ./build.sh
```
<a name="ubuntu18-prep-vm"></a>
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

<a name="ubuntu18-launch-vm"></a>
### Launch VM

Use the following command to launch SEV guest

```
# launch-qemu.sh -hda ubuntu-18.04.qcow2
```
NOTE: when guest is booting, CTRL-C is mapped to CTRL-], use CTRL-] to stop the guest

<a name="resources"></a>
# Additional Resources

[SME/SEV white paper](http://amd-dev.wpengine.netdna-cdn.com/wordpress/media/2013/12/AMD_Memory_Encryption_Whitepaper_v7-Public.pdf)

[SEV API Spec](http://support.amd.com/TechDocs/55766_SEV-KM%20API_Specification.pdf)

[APM Section 15.34](http://support.amd.com/TechDocs/24593.pdf)

[KVM forum slides](http://www.linux-kvm.org/images/7/74/02x08A-Thomas_Lendacky-AMDs_Virtualizatoin_Memory_Encryption_Technology.pdf)

[KVM forum videos](https://www.youtube.com/watch?v=RcvQ1xN55Ew)

[Linux kernel](https://elixir.bootlin.com/linux/latest/source/Documentation/virtual/kvm/amd-memory-encryption.rst)

[Linux kernel](https://elixir.bootlin.com/linux/latest/source/Documentation/x86/amd-memory-encryption.txt)

[Libvirt LaunchSecurity tag](https://libvirt.org/formatdomain.html#sev)

[Libvirt SEV domainCap](https://libvirt.org/formatdomaincaps.html#elementsSEV)

[Qemu doc](https://git.qemu.org/?p=qemu.git;a=blob;f=docs/amd-memory-encryption.txt;h=f483795eaafed8409b1e96806ca743354338c9dc;hb=HEAD)

<a name="faq"></a>
# FAQ

<a name="faq-1"></a>
 * <b>How do I know if hypervisor supports SEV feature ?</b>
   
   a) When using libvirt >= 4.15 run the following command
   
   ```
   # virsh domcapabilities
   ```
   If hypervisor supports SEV feature then <b>sev</b> tag will be present.
   
   >See [Libvirt DomainCapabilities feature](https://libvirt.org/formatdomaincaps.html#elementsSEV)
for additional information.
 
   b) Use qemu QMP 'query-sev-capabilities' command to check the SEV support. If SEV is supported then command will return the full SEV capabilities (which includes host PDH, cert-chain, cbitpos and reduced-phys-bits).
   
     > See [QMP doc](https://github.com/qemu/qemu/blob/master/docs/devel/writing-qmp-commands.txt) for details on how to interact with QMP shell.
  
  <a name="faq-2"></a>
 * <b>How do I know if SEV is enabled in the guest ?</b>
 
   a) Check the kernel log buffer for the following message
   ```
   # dmesg | grep -i sev
   AMD Secure Encrypted Virtualization (SEV) active
   ```
   
   b) MSR 0xc0010131 (MSR_AMD64_SEV) can be used to determine if SEV is active
   
   ```
   # rdmsr -a 0xc0010131
   ```
   <pre>
   Bit[0]:   0 = SEV is not active
             1 = SEV is active
   </pre>
