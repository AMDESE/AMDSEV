# Table of contents
* [ Introduction ](#intro)
* [ Enabling SEV-ES ](#sev-es)
  * [ Prepare Hypervisor/Host OS ](#sev-es-prep-hv)
  * [ Prepare Guest ](#sev-es-prep-guest)
  * [ Launch SEV-ES Guest ](#sev-es-launch-guest)
* [ Additional resources ](#resources)
* [ FAQ ](#faq)
  * [ How do I know if Hypervisor supports SEV ](#faq-1)
  * [ How do I know if SEV is enabled in the guest](#faq-2)
  * [ Can I use virt-manager to launch SEV guest](#faq-3)
  * [ How to increase SWIOTLB limit](#faq-4)
  * [ virtio-blk fails with out-of-dma-buffer error](#faq-5)  
  
<a name="intro"></a>
# Secure Encrypted Virtualization - Encrypted State (SEV-ES)

SEV-ES is an extension to SEV that protects the guest register state from the
hypervisor. An SEV-ES guest's register state is encrypted during world switches
and cannot be directly accessed or modified by the hypervisor. SEV-ES includes
architectural support for notifying a guest's operating system when certain
types of world switches are about to occur through a new exception. This allows
the guest operating system to selective share information with the hypervisor
when needed for functionality.

SEV-ES support has not yet been submitted/accepted in upstream projects. This
project contains repositories that provide proof-of-concept patches to show how
an SEV-ES guest would function. It is intended that these patches will be
improved upon for eventual submission upstream.

Currently a different kernel configuration is required for the hypervisor and
the guest. The scripts that build the kernels will make the necessary changes,
but example configurations are present in the kernel repository.

Scripts are provided to pull the repositories from this project and  build the
various components to enable SEV-ES.

To enable the SEV-ES support the following are the current levels:

| Project       | Repository and Branch                             |
| ------------- |:-------------------------------------------------:|
| kernel        | https://github.com/AMDESE/linux.git sev-es-5.9-v1 |
| qemu          | https://github.com/AMDESE/qemu.git  sev-es-v12    |
| ovmf          | https://github.com/AMDESE/ovmf.git  sev-es-v26    |

> * SEV-ES support is not available in SeaBIOS, OVMF must be used.

<a name="sev-es"></a>
## Enabling SEV-ES

All three of the repositories listed above must be used to run an SEV-ES guest.
The kernel must be run in both the hypervisor and the guest.

<a name="sev-es-prep-hv"></a>
### Prepare Hypervisor/Host OS

Build and install newer components
* This will build qemu, ovmf and the kernel with SEV-ES support.
* Qemu and OVMF files will be installed in /usr/local/.
* Use the apppropriate tool (rpm, dpkg, etc.) to install the hypervisor
  kernel package.

NOTE: The script WILL NOT install the packages needed to build everything
sucessfully. It is up to you to install the required packages to build the
components successfully. There are tools that can help with this:

* Ubuntu
  * apt-get build-dep <PKG_NAME>
* Fedora
  * dnf builddep <PKG_NAME>

Ensure SEV-ES ASIDs are available
* Look for a BIOS setting to set the SEV-ES ASID limit (naming of this
  option may vary from OEM to OEM (e.g. "SEV-ES ASID Space Limit").
  * It may require enabling a separate BIOS option to expose the SEV-ES
    ASID Space Limit setting (e.g. "SEV-ES ASID Space Limit Control").
* After booting the Hypervisor/Host OS, dmesg should contain something
  similar to the following:

	[   27.715445] SVM: SEV supported: 478 ASIDs
	[   27.715447] SVM: SEV-ES supported: 31 ASIDs


```
# ./build.sh
```

<a name="sev-es-prep-guest"></a>
### Prepare Guest

Create an empty virtual disk image:

```
# qemu-img create -f qcow2 <IMAGE_NAME>.qcow2 30G
```

Install <IMAGE_NAME> guest:

```
# ./launch-qemu.sh -hda <IMAGE_NAME>.qcow2 -cdrom <DISTRO_ISO>.iso -vnc 1
```
The guest must have been initially created/installed with a UEFI BIOS in order
to run an SEV-ES guest later. Using the launch-qemu.sh command to initially
install your guest will do this.

The script will copy the recently installed OVMF_VARS.fd file to the local
directory for use by the guest under name <IMAGE_NAME>.fd (unless already
present).

Connect to the VNC session and follow the screen to complete the guest
installation.

After guest installation completes, reboot into the guest, transfer the kernel
package that was build earlier to the guest and use the apppropriate tool (rpm,
dpkg, etc.) to install the kernel.

<a name="sev-es-launch-guest"></a>
### Launch SEV-ES guest

Use the following command to launch an SEV-ES guest

```
# ./launch-qemu.sh -hda <IMAGE_NAME>.qcow2 -vnc 1 -console serial -sev-es
```
NOTE: when guest is booting, CTRL-C is mapped to CTRL-], use CTRL-] to stop the guest

Select the newly installed SEV-ES kernel to boot.

<a name="resources"></a>
# Additional Resources

[AMD Secure Encrypted Virtualization (SEV) Home Page](https://developer.amd.com/sev/)

[AMD Memory Encryption Introduction](https://developer.amd.com/wordpress/media/2013/12/AMD_Memory_Encryption_Whitepaper_v7-Public.pdf)

[Protecting VM Register State With SEV-ES](https://www.amd.com/system/files/TechDocs/Protecting%20VM%20Register%20State%20with%20SEV-ES.pdf)

[APM Section 15.34 and 15.35](http://support.amd.com/TechDocs/24593.pdf)

[SEV API Spec](http://support.amd.com/TechDocs/55766_SEV-KM%20API_Specification.pdf)

[Linux kernel - SEV](https://elixir.bootlin.com/linux/latest/source/Documentation/virt/kvm/amd-memory-encryption.rst)

[Linux kernel - SME](https://elixir.bootlin.com/linux/latest/source/Documentation/x86/amd-memory-encryption.rst)

[Libvirt LaunchSecurity tag](https://libvirt.org/formatdomain.html#sev)

[Libvirt SEV domainCap](https://libvirt.org/formatdomaincaps.html#elementsSEV)

[Qemu doc](https://git.qemu.org/?p=qemu.git;a=blob;f=docs/amd-memory-encryption.txt;h=f483795eaafed8409b1e96806ca743354338c9dc;hb=HEAD)

<a name="faq"></a>
# FAQ

<a name="faq-1"></a>
 * <b>How do I know if my hypervisor supports the SEV feature?</b>
   
   a) When using libvirt >= 4.15 run the following command
   
   ```
   # virsh domcapabilities
   ```
   If hypervisor supports SEV feature then <b>sev</b> tag will be present.
   
   >See [Libvirt DomainCapabilities feature](https://libvirt.org/formatdomaincaps.html#elementsSEV)
for additional information.
 
   b) Use qemu QMP 'query-sev-capabilities' command to check the SEV support. If SEV is supported then command will return the full SEV capabilities (which includes host PDH, cert-chain, cbitpos and reduced-phys-bits).
   
     > See [QMP doc](https://github.com/qemu/qemu/blob/master/docs/devel/writing-qmp-commands.txt) for details on how to interact with QMP shell.

   c) Check the kernel log buffer for the following messages (SEV API version may differ)
   ```
   # dmesg | grep SEV
   [   27.306251] ccp 0000:22:00.1: SEV API:0.23 build:4
   [   29.373901] SEV supported: 446 ASIDs
   [   29.373902] SEV-ES supported: 63 ASIDs
   ```
  
<a name="faq-2"></a>
 * <b>How do I know if SEV or SEV-ES is enabled in the guest?</b>
 
   a) Check the kernel log buffer for the following message
   ```
   # dmesg | grep SEV
   [    0.374549] AMD Memory Encryption Features active: SEV SEV-ES
   ```
   
   b) MSR 0xc0010131 (MSR_AMD64_SEV) can be used to determine if SEV is active
   
   ```
   # rdmsr -a 0xc0010131
   ```
   <pre>
   Bit[0]:   0 = SEV is not active
             1 = SEV is active
   Bit[1]:   0 = SEV-ES is not active
             1 = SEV-ES is active
   </pre>

<a name="faq-3"></a>
 * <b>Can I use virt-manager to launch an SEV or SEV-ES guest?</b>

    virt-manager uses libvirt to manage VMs, SEV support has been added in libvirt but virt-manager does use the newly introduced [LaunchSecurity](https://libvirt.org/formatdomain.html#sev) tags yet, so you will not able to launch SEV guest through the virt-manager.
    > If your system is using libvirt >= 4.15 then you can manually edit the xml file to use [LaunchSecurity](https://libvirt.org/formatdomain.html#sev) and enable the SEV support in the guest.

<a name="faq-4"></a>
 * <b>How to increase SWIOTLB limit?</b>
 
 When SEV is enabled, all the DMA operations inside the guest are performed in shared memory. The Linux kernel uses the SWIOTLB bounce buffer for DMA operations inside an SEV guest. A guest panic can occur if the kernel runs out of SWIOTLB memory. The Linux kernel defaults to 64MB of SWIOTLB memory. It is recommended to increase the SWIOTLB memory size to 512MB. This can be done by appending the following to the kernel command line (edit /etc/defaults/grub):
 
```
GRUB_CMDLINE_LINUX_DEFAULT=".... swiotlb=262144"
```

And regenerate the grub.cfg.
