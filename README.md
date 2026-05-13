# AMD Secure Encrypted Virtualization (SEV)

[Overview](#overview) | [Upstream Support](#upstream-support) | [Prepare Host](#prepare-host) | [Build & Install](#build--install) | [Launch Guest](#launch-guest) | [Additional Resources](#resources) | [FAQ](#faq)

## Overview

This repo will build host/guest kernel, QEMU, and OVMF packages that are known to work in conjunction with the latest development trees for SEV Feature host/hypervisor support. The build scripts will utilize the latest published [development tree for the SNP host kernel](https://github.com/amdese/linux/tree/snp-host-latest), which will generally correspond to the latest patchset posted upstream along with fixes/changes on top resulting from continued development/testing and upstream review. It will also utilize the latest published [development tree for QEMU](https://github.com/amdese/qemu/tree/snp-latest).

Note that SEV 3.0+ hypervisor support is still being actively developed/upstreamed. Branches of this repository provide early snapshots of new features. Please report any issues with it or any other components built by these scripts via the issue tracker for this repo [here](https://github.com/AMDESE/AMDSEV/issues).

### SEV Features

AMD Secure Encrypted Virtualization (SEV) is a set of extensions to the AMD-V architecture for running encrypted virtual machines (VMs) under KVM. Each AMD EPYC processor family has introduced SEV improvements, sometimes with a milestone feature.

| SEV Version | EPYC Platform | Description |
|---|---|---|
| **SEV 1.0** | EPYC 7001 | Encrypts guest memory pages so only the guest has access to unencrypted data. Each VM uses a unique encryption key. |
| **SEV 2.0 (ES - Encrypted State)** | EPYC 7002 | Encrypts guest register state during world switches, preventing the hypervisor from directly accessing or modifying registers. Guests are notified before certain world switches via a new exception, allowing selective information sharing. |
| **SEV 3.0 (SNP - Secure Nested Paging)** | EPYC 7003 | Protects guest memory integrity via the Reverse Map Table (RMP), a system-managed structure that tracks ownership and state of each physical page. Prevents hypervisor-based memory remapping attacks by enforcing single-guest page assignment and validating all memory state transitions. |
| **SEV 3.1** | EPYC 9004/8004 | Enhancements to SNP (SVSM, TSME, 1006 ASID keys). |

> **Note:** "Legacy SEV" refers to the first generation. This README uses feature acronyms (SEV-ES, SEV-SNP) when referring to specific software interfaces.

This repository provides scripts to build host/guest kernels, QEMU, and OVMF
from AMD's development branches for SEV 3.0+ (SNP). This README covers
host setup, upstream version requirements, and then walks through launching SEV guests.

## Upstream Support

Modern distributions ship all the components needed to run SEV 3.0+ (SNP)
guests without building anything from source.

For a list of OS distributions that have been tested and certified for SEV
feature support across EPYC platforms, see
[sev-certify](https://github.com/AMDEPYC/sev-certify).

### Upstream Version Reference

| Minimum Version | SEV 1.0 | SEV 2.0 (ES) | SEV 3.0 (SNP) |
|---|---|---|---|
| Kernel (host) | 4.16 | 5.11 | 6.11 |
| Kernel (guest) | 4.16 | 5.11 | 5.19 (6.11 recommended; full attestation and guest_memfd) |
| QEMU | 2.12 | 6.0 | 9.1 |
| OVMF | 75b7aa9528bd | edk2-stable202102 | edk2-stable202405 |
| libvirt | 4.5 | 4.5 | 10.5.0 |
| SEV FW | — | — | 1.51 (0x33) |
| PSP BootLoader | — | — | 00.13.00.70 (AGESA PI 1.0.0.9+) |
| Platform | EPYC 7001+ | EPYC 7002+ | EPYC 7003+ |

SEV 3.1 (EPYC 9004/8004) uses the same software stack as SEV 3.0
with additional hardware capabilities.

## Prepare Host

These requirements apply regardless of whether you use distribution
packages or build from source. Optionally install
[snphost](https://github.com/virtee/snphost) and run `snphost ok`
for a comprehensive host readiness check of all requirements below
(CPU/BIOS/FW).

### CPU Requirements

SEV 3.0 (SNP) requires an AMD EPYC processor with Zen 3 or newer
microarchitecture. See the [SEV Features](#sev-features) table for platform
requirements by SEV version.

### BIOS Settings

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

### SEV Firmware

Minimum firmware versions are listed in the
[Upstream Version Reference](#upstream-version-reference) table above.
The latest firmware is available at [developer.amd.com/sev](https://developer.amd.com/sev/) and via
the `linux-firmware` package.

#### Update Firmware
To manually update firmware (example for EPYC 7003 Series):

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

#### Verify

Run the following commands to verify that SNP is enabled in the host.

```
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

```

**Notes:**
- EPYC 7003 Series systems require the minimum PSP BootLoader version listed in the [Upstream Version Reference](#upstream-version-reference) table. Attempting to update firmware with an older BootLoader will fail with `SEV: failed to INIT error 0x1, rc -5`. Update the system BIOS if you see this error.
- For EPYC 9004 Series systems, SEV firmware updates are delivered through system BIOS updates.

## Build & Install

You may skip this step if you do not require development patches not yet available upstream.

The `main` branch targets SEV 3.0 (SNP) development and builds host/guest kernels, QEMU, and OVMF from AMD development trees.

### Build

The following command builds the host and guest Linux kernel, QEMU, and OVMF used for launching an SEV-SNP guest.
Target repositories and branches are determined by [`stable-commits`](stable-commits).

```
# git clone https://github.com/AMDESE/AMDSEV.git
# ./build.sh --package
# sudo cp kvm.conf /etc/modprobe.d/
```
On successful build, the binaries will be available in `snp-release-<DATE>`.

NOTE: edk2 build issues are often caused by stale submodule state.
Delete the `ovmf/` directory and rebuild to force a fresh clone.

### Install

Run the following command to install the Linux kernel on the host machine.

```
# cd snp-release-<date>
# ./install.sh
```

Reboot the machine and choose SNP Host kernel from the grub menu.

## Launch Guest

### Prepare Guest

Note: SNP requires OVMF be used as the guest BIOS in order to boot. This implies that the guest must have been initially installed using OVMF so that a UEFI partition is present.

If you do not already have an installed guest, you can use the launch-qemu.sh script to create it (be sure to append "console=ttyS0,115200n8" to the installation kernel command line in order to perform the installation via the serial console):

```
# ./launch-qemu.sh -hda <your_qcow2_file> -cdrom <your_distro_installation_iso_file>
```

Boot up a guest (tested with Ubuntu 22.04 and 24.04, but any standard \*.deb or \*.rpm-based distro should work) and install the guest kernel packages built in the previous step. The guest kernel packages are available in 'snp-release-<DATE>/linux/guest' directory.

### Launch Guest

To launch the SNP guest use the launch-qemu.sh script provided in this repository

```
# ./launch-qemu.sh -hda <your_qcow2_file> -sev-snp
```

To launch SNP disabled guest, simply remove the "-sev-snp" from the above command line.

Once the guest is booted, run the following command inside the guest VM to verify that SNP is enabled:

```
$ dmesg | grep -i snp
AMD Memory Encryption Features active: SEV SEV-ES SEV-SNP
```

<a name="resources"></a>
## Additional Resources

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

[AMD SEV Enablement Guide (PDF)](https://docs.amd.com/v/u/en-US/58207-using-sev-with-amd-epyc-processors)

<a name="faq"></a>
## FAQ

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

 When SEV is enabled, all the DMA operations inside the guest are performed on the shared memory. Linux kernel uses SWIOTLB bounce buffer for DMA operations inside SEV guest. A guest panic will occur if kernel runs out of the SWIOTLB pool. Linux kernel default to 64MB SWIOTLB pool. It is recommended to increase the swiotlb pool size to 512MB. The swiotlb pool size can be increased in guest by appending the following in the grub.cfg file

 Append the following in /etc/defaults/grub

```
GRUB_CMDLINE_LINUX_DEFAULT=".... swiotlb=262144"
```

And regenerate the grub.cfg.

<a name="faq-5"></a>
 * <b>SWIOTLB allocation failure causing kernel panic </b>

 SWIOTLB size, when not specifically specified, is automatically calculated based on the amount of guest memory, up to 1GB maximum. However, the guest may not have enough contiguous memory below 4GB to satisfy the SWIOTLB allocation requirement, in which case the kernel will panic:

 <pre>
 [    0.004318] software IO TLB: SWIOTLB bounce buffer size adjusted to 965MB
 ...
 [    1.015953] Kernel panic - not syncing: Can not allocate SWIOTLB buffer earlier and can't now provide you with the DMA bounce buffer
 </pre>

 In this situation, please specify the SWIOTLB size, as shown in [How to increase SWIOTLB limit](#faq-4), to a value that allows the guest to boot.

<a name="faq-6"></a>
 * <b>virtio-blk device runs out-of-dma-buffer error </b>

 To support the multiqueue mode, virtio-blk drivers inside the guest allocates large number of DMA buffer. SEV guest uses SWIOTLB for the DMA buffer allocation or mapping hence kernel runs of the SWIOTLB pool quickly and triggers the out-of-memory error. In those cases consider increasing the SWIOTLB pool size or use virtio-scsi device.

 <a name="faq-7"></a>
 * <b>SEV_INIT fails with error 0x13 </b>

 The error 0x13 is a defined as HWERROR_PLATFORM in the SEV specification. The error indicates that memory encryption support is not enabled in the host BIOS. Look for the SMEE setting in your BIOS menu and explicitly enable it. You can verify that SMEE is enabled on your machine by running the below command
 ```
 $ sudo modprobe msr
 $ sudo rdmsr  0xc0010010
 3f40000

 Verify that BIT23 is memory encryption (aka SMEE) is set.
 ```
