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
  * [ SWIOTLB allocation failure causing kernel panic](#faq-5)
  * [ virtio-blk fails with out-of-dma-buffer error](#faq-6)
  * [ SEV-INIT fails with error 0x13](#faq-7)
  * [ SEV Firmware Updates](#faq-8)
  
<a name="intro"></a>
# Secure Encrypted Virtualization - Encrypted State (SEV-ES)

SEV-ES is an extension to SEV that protects the guest register state from the
hypervisor. An SEV-ES guest's register state is encrypted during world switches
and cannot be directly accessed or modified by the hypervisor. SEV-ES includes
architectural support for notifying a guest's operating system when certain
types of world switches are about to occur through a new exception. This allows
the guest operating system to selective share information with the hypervisor
when needed for functionality.

SEV-ES support has been submitted and accepted in upstream projects. The
upstream version of the projects should be used.

Scripts are provided to pull the minimum required levels of the repositories
to build the various components to enable SEV-ES.

To enable the SEV-ES support, the following levels of software are required:

| Project       | Version                         |
| ------------- |:-------------------------------:|
| kernel        | >= 5.11                         |
| qemu          | >= 6.0                          |
| ovmf          | >= edk2-stable202102            |

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
  * Note: The type of kernel package built is based a test in the
    build_kernel() function of the build/common.sh script. If the test
    [ "$ID_LIKE" = "debian" ] returns true then a deb package is built,
    otherwise an rpm is built. If this test is not working on your system
    or you desire a specific type of package, you can edit the script
    to build the desired package.

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

* If you built the kernel without using the script, then you may need to
  ensure that SEV and SEV-ES are enabled in KVM. Append the following to
  the the kernel command line options:
  * "kvm_amd.sev=1 kvm_amd.sev_es=1"

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

NOTE: If the guest reboots into the installation CD again, you should terminate
the guest (using CTRL-]) and relaunch the guest without the -cdrom option.

<a name="sev-es-launch-guest"></a>
### Launch SEV-ES guest

Use the following command to launch an SEV-ES guest

```
# ./launch-qemu.sh -hda <IMAGE_NAME>.qcow2 -vnc 1 -console serial -sev-es
```
NOTE: when the guest is booting, CTRL-C is mapped to CTRL-], use CTRL-] to stop
the guest

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

<a name="faq-5"></a>
 * <b>SWIOTLB allocation failure causing kernel panic </b>

 SWIOTLB size, when not specifically specified, is automatically calculated based on the amount of guest memory, up to 1GB maximum. However, the guest may not have enough contiguous memory below 4GB to satisify the SWIOTLB allocation requirement, in which case the kernel will panic:

 <pre>
 [    0.004318] software IO TLB: SWIOTLB bounce buffer size adjusted to 965MB
 ...
 [    1.015953] Kernel panic - not syncing: Can not allocate SWIOTLB buffer earlier and can't now provide you with the DMA bounce buffer
 </pre>

 In this situation, please specify the SWIOTLB size, as shown in [ How to increase SWIOTLB limit](#faq-4), to a value that allows the guest to boot.

<a name="faq-6"></a>
 * <b>virtio-blk device runs out-of-dma-buffer error </b>

 To support the multiqueue mode, virtio-blk drivers inside the guest allocates large number of DMA buffer. SEV guest uses SWIOTLB for the DMA buffer allocation or mapping hence kernel runs of the SWIOTLB pool quickly and triggers the out-of-memory error. In those cases consider increasing the SWIOTLB pool size or use virtio-scsi device.

 <a name="faq-7"></a>
 * <b>SEV_INIT fails with error 0x13 </b>

 The error 0x13 is a defined as HWERROR_PLATFORM in the SEV specification. The error indicates that memory encryption support is not enabled in the host BIOS. Look for  the SMEE setting in your BIOS menu and explicitly enable it. You can verify that SMEE is enabled on your machine by running the below command
 ```
 $ sudo modprobe msr
 $ sudo rdmsr  0xc0010010
 3f40000

 Verify that BIT23 is memory encryption (aka SMEE) is set.
 ```

<a name="faq-8"></a>
 * <b>SEV Firmware Updates</b>

SEV firmware is part of the AMD Secure Processor and is responsible for
much of the life cycle management of an SEV guest. Updates to the firmware
can be made available outside the traditional BIOS update path.

On Linux, the AMD Secure Processor driver (ccp) is responsible for updating
the SEV firmware when the driver is loaded. The driver searches for the firmware
using the kernel's firmware loading interface. The kernel's firmware loading
interface will search for the firmware, by name, in a number of locations
(see <a href="https://github.com/torvalds/linux/blob/master/Documentation/driver-api/firmware/fw_search_path.rst">fw_search_path.rst</a>),
with the traditional path being /lib/firmware.

The ccp driver searches for three different possible SEV firmware files under
the "amd" directory, using the first file that is found. The first file that
is searched for is a firmware file with a CPU family and model specific name,
then a firmware file with a CPU family and model range name, and finally a
generic name. The naming convention uses the following format:

* Model specific: amd_sev_famXXh_modelYYh.sbin
  - where XX is the hex representation of the CPU family
  - where YY is the hex representation of the CPU model

* Range specific: amd_sev_famXXh_modelYxh.sbin
  - where XX is the hex representation of the CPU family
  - where  Y is the hex representation of the first digit of the CPU model

* Generic: sev.fw

For example, for an EPYC processor with a family of 0x19 and a model of 0x01,
the search order would be::

1.  amd/amd_sev_fam19h_model01h.sbin
1.  amd/amd_sev_fam19h_model0xh.sbin
1.  amd/sev.fw

The level of firmware that is loaded can be viewed in the kernel log. For example, issuing
the command "dmesg | grep ccp":
<pre>
[   13.879283] ccp 0000:01:00.5: enabling device (0000 -> 0002)
[   13.887532] ccp 0000:01:00.5: sev enabled
[   13.899646] ccp 0000:01:00.5: psp enabled
[   14.560461] ccp 0000:01:00.5: SEV API:1.55 build:24
[   14.644793] ccp 0000:01:00.5: SEV-SNP API:1.55 build:24
</pre>

Since, on Linux, the firmware is updated on driver load of the ccp module, it is possible
to update the firmware level after the system has booted. At this time, all guests would
need to be shutdown and the kvm_amd module unloaded before the ccp module could be unloaded
and reloaded.

SEV firmware can be obtained from the <a href="https://www.amd.com/sev">AMD Secure Encrypted Virtualization
web portal</a> or through the <a href="https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/tree/amd">Linux Firmware repository</a>.
