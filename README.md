# Table of contents
* [ Introduction ](#intro)
* [ SLES-15 ](#sles-15)
  * [ Prepare Host OS ](#sles-15-host)
  * [ Prepare VM ](#sles-15-prep-vm)
  * [ Launch SEV VM ](#sles-15-launch-vm)
* [ RHEL-8 ](#rhel-8)
  * [ Prepare Host OS ](#rhel-8-host)
  * [ Prepare VM ](#rhel-8-prep-vm)
  * [ Launch SEV VM ](#rhel-8-launch-vm)  
* [ Fedora-28 ](#fc-28)
  * [ Prepare Host OS ](#fc-28-host)
  * [ Prepare VM ](#fc-28-prep-vm)
  * [ Launch SEV VM ](#fc-28-launch-vm)
* [ Fedora-29 ](#fc-29)
  * [ Prepare Host OS ](#fc-29-host)
  * [ Prepare VM ](#fc-29-prep-vm)
  * [ Launch SEV VM ](#fc-29-launch-vm)
* [ Ubuntu-18.04 ](#ubuntu18)
  * [ Prepare Host OS ](#ubuntu18-host)
  * [ Prepare VM ](#ubuntu18-prep-vm)
  * [ Launch SEV VM ](#ubuntu18-launch-vm)
* [ openSuse-Tumbleweed](#tumbleweed)
  * [ Prepare Host OS ](#tumbleweed-host)
  * [ Launch SEV VM ](#tumbleweed-launch-vm)
* [ SEV Containers ](#kata)
* [ Additional resources ](#resources)
* [ FAQ ](#faq)
  * [ How do I know if Hypervisor supports SEV ](#faq-1)
  * [ How do I know if SEV is enabled in the guest](#faq-2)
  * [ Can I use virt-manager to launch SEV guest](#faq-3)
  * [ How to increase SWIOTLB limit](#faq-4)
  * [ virtio-blk fails with out-of-dma-buffer error](#faq-5)  
  
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

Install the qemu launch script. The launch script can be obtained from this project.

```
# git clone https://github.com/AMDESE/AMDSEV.git
# cd AMDSEV/distros/sles-15
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

## RHEL-8

RedHat Enterprise Linux 8.0 GA includes the SEV support; we do not need
to compile the sources.

<a name="rhel-8-host"></a>
### Prepare Host OS

SEV is not enabled by default, lets enable it through kernel command line:

Append the following in /etc/defaults/grub

```
GRUB_CMDLINE_LINUX_DEFAULT=".... mem_encrypt=on kvm_amd.sev=1"
```

Regenerate grub.cfg and reboot the host

```
# grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg
# reboot
```

Install the qemu launch script. The launch script can be obtained from this project.

```
# git clone https://github.com/AMDESE/AMDSEV.git
# cd AMDSEV/distros/rhel-8
# ./build.sh
```
<a name="rhel-8-prep-vm"></a>
### Prepare VM image

Create empty virtual disk image

```
# qemu-img create -f qcow2 rhel-8.qcow2 30G
```

Create a new copy of OVMF_VARS.fd. The OVMF_VARS.fd is a "template" used
to emulate persistent NVRAM storage. Each VM needs a private, writable
copy of VARS.fd.

```
#cp /usr/share/OVMF/OVMF_VARS.fd OVMF_VARS.fd 
```

Download and install rhel-8 guest

```
# launch-qemu.sh -hda rhel-8.qcow2 -cdrom RHEL-8.0.0-20190404.2-x86_64-dvd1.iso
```
Follow the screen to complete the guest installation.

<a name="rhel-8-launch-vm"></a>
### Launch VM

Use the following command to launch SEV guest

```
# launch-qemu.sh -hda rhel-8.qcow2
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

<a name="fc-29"></a>
## Fedora-29

Fedora-29 contains all the pre-requisite packages to launch an SEV guest. But the SEV feature is not enabled by default, this section documents how to enable the SEV feature.

<a name="fc-29-host"></a>
### Prepare Host OS

* Add new udev rule for the /dev/sev device
  
  ```
  # cat /etc/udev/rules.d/71-sev.rules
  KERNEL=="sev", MODE="0660", GROUP="kvm"
  ```
* Clean libvirt caches so that on restart libvirt re-generates the capabilities

  ```
  # rm -rf /var/cache/libvirt/qemu/capabilities/
  ```
  
* The default FC-29 kernel (4.18) has SEV disabled in config files, but the kernel available through the FC-29 update
  has SEV config set

  Use the following command to upgrade the packages and also install the virtulization packages

   ```
   # yum groupinstall virtualization
   # yum upgrade
   ```

* By default SEV is disabled, append the following in /etc/defaults/grub

    ```
     GRUB_CMDLINE_LINUX_DEFAULT=".... mem_encrypt=on kvm_amd.sev=1"
    ```

    Regenerate grub.cfg and reboot the host

    ```
     # grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg
     # reboot
    ```

* Install the qemu launch script

     ```
      # cd distros/fedora-29
      # ./build.sh
     ```
     
<a name="fc-29-prep-vm"></a>
### Prepare VM image

Create empty virtual disk image

```
# qemu-img create -f qcow2 fedora-29.qcow2 30G
```

Create a new copy of OVMF_VARS.fd. The OVMF_VARS.fd is a "template" used
to emulate persistent NVRAM storage. Each VM needs a private, writable
copy of VARS.fd.

```
# cp /usr/share/edk2/ovmf/OVMF_VARS.fd OVMF_VARS.fd
```

Download and install fedora-29 guest

```
# launch-qemu.sh -hda fedora-29.qcow2 -cdrom  Fedora-Workstation-netinst-x86_64-29-1.1.iso
```
Follow the screen to complete the guest installation.

<a name="fc-29-launch-vm"></a>
### Launch VM

Use the following command to launch SEV guest

```
# launch-qemu.sh -hda fedora-29.qcow2
```

NOTE: when guest is booting, CTRL-C is mapped to CTRL-], use CTRL-] to stop the guest

<a name="ubuntu18"></a>
## Ubuntu 18.04

Ubuntu 18.04 does not includes the newer version of components to be used as SEV
hypervisor hence we will build and install newer kernel, qemu, ovmf.

<a name="ubuntu18-host"></a>
### Prepare Host OS

* Enable source repositories [See](https://askubuntu.com/questions/158871/how-do-i-enable-the-source-code-repositories)

* Build and install newer components

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

<a name="tumbleweed"></a>
## openSUSE-Tumbleweed

Latest version of openSUSE Tumbleweed distro contains all the pre-requisite packages to launch an SEV guest. But the SEV feature is not enabled by default, this section documents how to enable the SEV feature.

<a name="tumbleweed-host"></a>
### Prepare Host OS

* Add new udev rule for the /dev/sev device
  
  ```
  # cat /etc/udev/rules.d/71-sev.rules
  KERNEL=="sev", MODE="0660", GROUP="kvm"
  ```
* Clean libvirt caches so that on restart libvirt re-generates the capabilities

  ```
  # rm -rf /var/cache/libvirt/qemu/capabilities/
  # systemctl restart libvirtd
  ```
* SEV feature is not enabled in kernel by default, lets enable it through kernel command line:

  Append the following in /etc/defaults/grub
  ```
   GRUB_CMDLINE_LINUX_DEFAULT=".... mem_encrypt=on kvm_amd.sev=1"
  ```
  Regenerate grub.cfg and reboot the host

  ```
  # grub2-mkconfig -o /boot/efi/EFI/opensuse/grub.cfg
  # reboot
  ```
  
<a name="tumbleweed-launch-vm"></a>  
### Launch SEV VM

The SEV support is available in the latest libvirt, follow the https://libvirt.org/kbase/launch_security_sev.html to use the libvirt to create and manage the SEV guest.


<a name="kata"></a>
## SEV Containers

Container runtimes that use hardware virtualization to further isolate container workloads can also make use of SEV. As a proof-of-concept, the [kata](https://github.com/AMDESE/AMDSEV/tree/kata) branch contains an SEV-capable version of the Kata Containers runtime that will start all containers inside of SEV virtual machines.

For installation instructions on Ubuntu systems, see the [README](https://github.com/AMDESE/AMDSEV/blob/kata/README.md).

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

[Libvirt SEV](https://libvirt.org/kbase/launch_security_sev.html)

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

<a name="faq-3"></a>
 * <b>Can I use virt-manager to launch SEV guest?</b>

    virt-manager uses libvirt to manage VMs, SEV support has been added in libvirt but virt-manager does use the newly introduced [LaunchSecurity](https://libvirt.org/formatdomain.html#sev) tags yet hence we will not able to launch SEV guest through the virt-manager.
    > If your system is using libvirt >= 4.15 then you can manually edit the xml file to use [LaunchSecurity](https://libvirt.org/formatdomain.html#sev) to enable the SEV support in the guest.

<a name="faq-4"></a>
 * <b>How to increase SWIOTLB limit ?</b>
 
 When SEV is enabled, all the DMA operations inside the guest are performed on the shared memory. Linux kernel uses SWIOTLB  bounce buffer for DMA operations inside SEV guest. A guest panic will occur if kernel runs out of the SWIOTLB pool. Linux kernel default to 64MB SWIOTLB pool. It is recommended to increase the swiotlb pool size to 512MB. The swiotlb pool size can be increased in guest by appending the following in the grub.cfg file
 
 Append the following in /etc/defaults/grub

```
GRUB_CMDLINE_LINUX_DEFAULT=".... swiotlb=262144"
```

And regenerate the grub.cfg.

<a name="faq-5"></a>
 * <b>virtio-blk device runs out-of-dma-buffer error </b>
 
 To support the multiqueue mode, virtio-blk drivers inside the guest allocates large number of DMA buffer. SEV guest uses SWIOTLB for the DMA buffer allocation or mapping hence kernel runs of the SWIOTLB pool quickly and triggers the out-of-memory error. In those cases consider increasing the SWIOTLB pool size or use virtio-scsi device.
 
