## Overview

This repo will build host/guest kernel, QEMU, and OVMF packages that are known to work in conjunction with the latest development trees for SNP host/hypervisor support. The build scripts will utilize the latest published [development tree for the SNP host kernel](https://github.com/amdese/linux/tree/snp-host-latest), which will generally correspond to the latest patchset posted upstream along with fixes/changes on top resulting from continued development/testing and upstream review. It will also utilize the latest published [development tree for QEMU](https://github.com/amdese/qemu/tree/snp-latest).

Note that SNP hypervisor support is still being actively developed/upstreamed. Branhes of this repository provide early snapshots of new features. Please report any issues with it or any other components built by these scripts via the issue tracker for this repo [here](https://github.com/AMDESE/AMDSEV/issues).

Follow the below steps to build the required components and launch an SEV-SNP guest. These steps are tested primarily in conjunction with Ubuntu 22.04 hosts/guests, but other distros are supported to some degree by contributors to this repo.

NOTE: If you're building from an existing checkout of this repo and have build issues with edk2, delete the ovmf/ directory prior to starting the build so that it can be re-initialized cleanly.

## Upstream support

SEV is an extension to the AMD-V architecture which supports running encrypted
virtual machine (VMs) under the control of KVM. Encrypted VMs have their pages
(code and data) secured such that only the guest itself has access to the
unencrypted version. Each encrypted VM is associated with a unique encryption
key; if its data is accessed by a different entity using a different key, the
encrypted guests data will be incorrectly decrypted, leading to unintelligible
data.

SEV support has been accepted in upstream projects. This repository provides
scripts to build various components to enable SEV support until the distros
pick the newer version of components.

To enable SEV support we need the following versions.

| Project       | Version                              |
| ------------- |:------------------------------------:|
| kernel        | >= 4.16                              |
| libvirt       | >= 4.5                               |
| qemu          | >= 2.12                              |
| ovmf          | >= commit (75b7aa9528bd 2018-07-06 ) |

SEV-ES is an extension to SEV that protects the guest register state from the
hypervisor. An SEV-ES guest's register state is encrypted during world switches
and cannot be directly accessed or modified by the hypervisor. SEV-ES includes
architectural support for notifying a guest's operating system when certain
types of world switches are about to occur through a new exception. This allows
the guest operating system to selective share information with the hypervisor
when needed for functionality.

SEV-ES support has been submitted and accepted in upstream projects. The
upstream version of the projects should be used.

To enable SEV-ES support we need the following versions.

| Project       | Version/Tag                          |
| ------------- |:------------------------------------:|
| kernel        | >= 5.11                              |
| libvirt       | >= 4.5                               |
| qemu          | >= 6.00                              |
| ovmf          | >= edk2-stable202102                 |

* SEV support is not available in SeaBIOS. Guest must use OVMF.

SEV-SNP is an extension to SEV-ES that protects guest memory integrity and
prevents unauthorized memory remapping attacks by the hypervisor.
An SEV-SNP guest's memory is protected by the Reverse Map Table (RMP),
a system-managed data structure that tracks the ownership and state of
each physical page. The RMP enforces that each page can only be assigned to
a single guest at a time and validates all memory state transitions.

To enable SEV-SNP support we need the following versions.

| Project       | Version/Tag                          |
| ------------- |:------------------------------------:|
| kernel        | >= 6.11                              |
| libvirt       | >= (FIXME)                           |
| qemu          | >= 10.00 (FIXME)                     |
| ovmf          | >= (FIXME)                           |

## Build

The following command builds the host and guest Linux kernel, qemu and ovmf bios used for launching SEV-SNP guest.

````
# git clone https://github.com/AMDESE/AMDSEV.git
# git checkout snp-latest
# ./build.sh --package
# sudo cp kvm.conf /etc/modprobe.d/
````
On succesful build, the binaries will be available in `snp-release-<DATE>`.

## Prepare Host

Verify that the following BIOS settings are enabled. The setting may vary based on the vendor BIOS. The menu options below are from an AMD BIOS.

```
Advanced → AMD CBS → CPU Common Options
    SMEE → Enable
    SEV Control → Enable
    SEV-ES ASID Space Limit → 99
    SNP Memory (RMP Table) Coverage → Enabled
Advanced → NBIO Common Options → IOMMU/Security
    SEV-SNP Support → Enable
```

Run the following command to install the Linux kernel on the host machine.

```
# cd snp-release-<date>
# ./install.sh
```

Reboot the machine and choose SNP Host kernel from the grub menu.

Run the following commands to verify that SNP is enabled in the host.

````
# dmesg | grep -e SEV-SNP -e RMP
SEV-SNP: Segmented RMP base table physical range [0x000000009ba00000 - 0x000000009ba05000]
SEV-SNP: Reserving start/end of RMP table on a 2MB boundary [0x0000000055a00000]
SEV-SNP: Reserving start/end of RMP table on a 2MB boundary [0x0000000075a00000]
SEV-SNP: Segmented RMP using 128GB segments
SEV-SNP: RMP segment 0 physical address [0x8800000 - 0x10ffffff] covering [0x0 - 0x87fffffff]
SEV-SNP: RMP segment 8 physical address [0x55b00000 - 0x75afffff] covering [0x10000000000 - 0x11fffffffff]
SEV-SNP: RMP segment 9 physical address [0x35a00000 - 0x559fffff] covering [0x12000000000 - 0x13fffffffff]
ccp 0000:a9:00.5: SEV-SNP API:1.58 build:5
kvm_amd: SEV-SNP enabled (ASIDs 1 - 98)
# cat /sys/module/kvm_amd/parameters/sev
Y
# cat /sys/module/kvm_amd/parameters/sev_es
Y
# cat /sys/module/kvm_amd/parameters/sev_snp
Y

````

*NOTE: If your SEV-SNP firmware is older than 1.54, see the "Upgrade SEV firmware" section to upgrade the firmware*
## Prepare Guest

Note: SNP requires OVMF be used as the guest BIOS in order to boot. This implies that the guest must have been initially installed using OVMF so that a UEFI partition is present.

If you do not already have an installed guest, you can use the launch-qemu.sh script to create it (be sure to append "console=ttyS0,115200n8" to the installation kernel command line in order to perform the installation via the serial console):

````
# ./launch-qemu.sh -hda <your_qcow2_file> -cdrom <your_distro_installation_iso_file>
````

Boot up a guest (tested with Ubuntu 22.04 and 24.04, but any standard *.deb or *.rpm-based distro should work) and install the guest kernel packages built in the previous step. The guest kernel packages are available in 'snp-release-<DATE>/linux/guest' directory.

## Launch SNP Guest

To launch the SNP guest use the launch-qemu.sh script provided in this repository

````
# ./launch-qemu.sh -hda <your_qcow2_file> -sev-snp
````

To launch SNP disabled guest, simply remove the "-sev-snp" from the above command line.

Once the guest is booted, run the following command inside the guest VM to verify that SNP is enabled:

````
$ dmesg | grep -i snp
AMD Memory Encryption Features active: SEV SEV-ES SEV-SNP
````

## Upgrade SEV firmware

The SEV-SNP support requires firmware version >= 1.51:1 (or 1.33 in hexadecimal). The latest SEV-SNP firmware is available on https://developer.amd.com/sev and via the linux-firmware project.

The steps below document the firmware upgrade process for the latest SEV-SNP firmware available on https://developer.amd.com/sev at the time this was written. Currently, these steps only apply for Milan systems. A similar procedure can be used for newer firmwares as well:

```
# wget https://download.amd.com/developer/eula/sev/amd_sev_fam19h_model0xh_1.54.01.zip
# unzip amd_sev_fam19h_model0xh_1.54.01.zip
# sudo mkdir -p /lib/firmware/amd
# sudo cp amd_sev_fam19h_model0xh_1.54.01.sbin /lib/firmware/amd/amd_sev_fam19h_model0xh.sbin
```

Then either reboot the host, or reload the ccp driver to complete the firmware upgrade process:

```
sudo rmmod kvm_amd
sudo rmmod ccp
sudo modprobe ccp
sudo modprobe kvm_amd
```

Current Milan SEV/SNP FW requires a PSP BootLoader version of 00.13.00.70 or greater. Milan AGESA PI 1.0.0.9 included a sufficient PSP BootLoader. Attempting to update to current SEV FW with an older BootLoader will fail. If the following error appears after updating the firmware manually, update the system to the latest available BIOS:

```
$ sudo dmesg | grep -i sev
[    4.364896] ccp 0000:47:00.1: SEV: failed to INIT error 0x1, rc -5
```
For Genoa firmware updates, the system BIOS has to be updated to get the latest sev firmware.


<a name="resources"></a>
# Additional Resources

[AMD SEV developer portal](https://developer.amd.com/sev/)

[SME/SEV white paper](http://amd-dev.wpengine.netdna-cdn.com/wordpress/media/2013/12/AMD_Memory_Encryption_Whitepaper_v7-Public.pdf)

[SEV API Spec](https://www.amd.com/system/files/TechDocs/55766_SEV-KM_API_Specification.pdf)

[APM Section 15.34](http://support.amd.com/TechDocs/24593.pdf)

[KVM forum slides](http://www.linux-kvm.org/images/7/74/02x08A-Thomas_Lendacky-AMDs_Virtualizatoin_Memory_Encryption_Technology.pdf)

[KVM forum videos](https://www.youtube.com/watch?v=RcvQ1xN55Ew)

[Linux kernel](https://elixir.bootlin.com/linux/latest/source/Documentation/virtual/kvm/amd-memory-encryption.rst)

[Linux kernel](https://elixir.bootlin.com/linux/latest/source/Documentation/x86/amd-memory-encryption.txt)

[Libvirt LaunchSecurity tag](https://libvirt.org/formatdomain.html#sev)

[Libvirt SEV](https://libvirt.org/kbase/launch_security_sev.html)

[Libvirt SEV domainCap](https://libvirt.org/formatdomaincaps.html#elementsSEV)

[Qemu doc](https://git.qemu.org/?p=qemu.git;a=blob;f=docs/amd-memory-encryption.txt;h=f483795eaafed8409b1e96806ca743354338c9dc;hb=HEAD)

[guest_memfd (a.k.a. "gmem", or "Unmapped Private Memory")](https://lore.kernel.org/kvm/20230914015531.1419405-1-seanjc@google.com/)

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
