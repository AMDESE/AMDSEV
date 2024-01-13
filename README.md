## Overview

This repo will build host/guest kernel, QEMU, and OVMF packages that are known to work in conjunction with the latest development trees for SNP host/hypervisor support. The build scripts will utilize the latest published [development tree for the SNP host kernel](https://github.com/amdese/linux/tree/snp-host-latest), which will generally correspond to the latest patchset posted upstream along with fixes/changes on top resulting from continued development/testing and upstream review. It will also utilize the latest published [development tree for QEMU](https://github.com/amdese/qemu/tree/snp-latest).

Note that SNP hypervisor support is still being actively developed/upstreamed and should be used only for preview/testing/development purposes. Please report any issues with it or any other components built by these scripts via the issue tracker for this repo [here](https://github.com/AMDESE/AMDSEV/issues).

Follow the below steps to build the required components and launch an SEV-SNP guest. These steps are tested primarily in conjunction with Ubuntu 22.04 hosts/guests, but other distros are supported to some degree by contributors to this repo.

## Upgrading from 6.6-based SNP hypervisor/host kernels

QEMU command-line options have changed for basic booting of SNP guests. Please see the launch-qemu.sh script in this repository for updated options.

There is also now a new -certs option for launch-qemu.sh, which corresponds to a new QEMU 'certs-path' parameter (see launch-qemu.sh for specifics) that needs to be set when specifying a certificate blob to be passed to guests when they request an attestation report via extended guest requests. This was previously handled via the SNP_SET_EXT_CONFIG SEV device IOCTL, which handled both updating the ReportedTCB for the system in conjunction with updating the certificate blob corresponding to the attestation report signatures associated with that particular ReportedTCB. These 2 tasks are now handled separately:

 * certificate updates are handled by simply updated the certificate blob file specified by the above-mentioned -certs-path parameter
 * ReportedTCB updates are handled by a new IOCTL, SNP_SET_CONFIG, which is similar to SNP_SET_EXTENDED_CONFIG, but no longer provides any handling for certificate updates.

There are also 2 new IOCTLs, SNP_SET_CONFIG_START/SNP_SET_CONFIG_END, which can be used in cases where there are running SNP guests on a system and the ReportedTCB and certs file updates need to done atomically relative to any attestation requests that might be issued while updating those 2 things.

The SNP_GET_EXT_CONFIG has also been removed, since without any handling for certificates it is now redundant with the information already available via the SNP_PLATFORM_STATUS IOCTL.

For more details on any of the above IOCTLs, see the latest [SEV IOCTL documentation](https://github.com/AMDESE/linux/blob/snp-host-latest/Documentation/virt/coco/sev-guest.rst) in the kernel.

Various host-side tools need to be updated to handle these changes, so if you are relying on any such tools to handle the above tasks, please verify whether or not the necessary changes are in place yet and plan accordingly.

## Upgrading from 6.5-based SNP hypervisor/host kernels

If you were previously using a build based on kernel 6.5-rc2 host kernel, you may notice a drop in boot-time performance switch over to the latest kernel. This is due to [SRSO mitigations](https://www.amd.com/content/dam/amd/en/documents/corporate/cr/speculative-return-stack-overflow-whitepaper.pdf) that were added in later versions of kernel 6.5 and enabled by default. While it is not recommended, you can use the 'spec_rstack_overflow=off' kernel command-line options in both host and guest to disable these mitigations for the purposes of evaluating performance differences vs. previous builds.

## Upgrading from 5.19-based SNP hypervisor/host kernels

If you are building packages to use in conjunction with an older 5.19-based SNP host/hypervisor kernel, then please use the [sev-snp-devel](https://github.com/amdese/amdsev/tree/sev-snp-devel) branch of this repo instead, which will ensure that compatible QEMU/OVMF trees are used instead. Please consider switching to the latest development trees used by this branch however, as [sev-snp-devel](https://github.com/amdese/amdsev/tree/sev-snp-devel) is no longer being actively developed.

Newer SNP host/kernel support now relies on new kernel infrastructure for managing private guest memory called guest_memfd[1] (a.k.a. "gmem", or "Unmapped Private Memory"). This reliance on guest_memfd brings about some new requirements/limitations in the current tree that users should be aware:
* Assigning NUMA affinities for private guest memory is not supported.
* Guest private memory is now accounted as shared memory rather than used memory, so please take this into account when monitoring memory usage.
* The QEMU command-line options to launch an SEV-SNP guest have changed. Setting these options will be handled automatically when using the launch-qemu.sh script mentioned in the instructions below. If launching QEMU directly, please still reference the script to determine the correct QEMU options to use.

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
  CBS -> CPU Common ->
                SEV-ES ASID space Limit Control -> Manual
                SEV-ES ASID space limit -> 100
                SNP Memory Coverage -> Enabled 
                SMEE -> Enabled
      -> NBIO common ->
                SEV-SNP -> Enabled
```
  
Run the following command to install the Linux kernel on the host machine.

```
# cd snp-release-<date>
# ./install.sh
```

Reboot the machine and choose SNP Host kernel from the grub menu.

Run the following commands to verify that SNP is enabled in the host.

````
# uname -r
5.19.0-rc6-sev-es-snp+

# dmesg | grep -i -e rmp -e sev
SEV-SNP: RMP table physical address 0x0000000035600000 - 0x0000000075bfffff
ccp 0000:23:00.1: sev enabled
ccp 0000:23:00.1: SEV-SNP API:1.51 build:1
SEV supported: 410 ASIDs
SEV-ES and SEV-SNP supported: 99 ASIDs
# cat /sys/module/kvm_amd/parameters/sev
Y
# cat /sys/module/kvm_amd/parameters/sev_es 
Y
# cat /sys/module/kvm_amd/parameters/sev_snp 
Y

````
  
*NOTE: If your SEV-SNP firmware is older than 1.51, see the "Upgrade SEV firmware" section to upgrade the firmware. *
  
## Prepare Guest

Note: SNP requires OVMF be used as the guest BIOS in order to boot. This implies that the guest must have been initially installed using OVMF so that a UEFI partition is present.

If you do not already have an installed guest, you can use the launch-qemu.sh script to create it:

````
# ./launch-qemu.sh -hda <your_qcow2_file> -cdrom <your_distro_installation_iso_file>
````

Boot up a guest (tested with Ubuntu 18.04 and 20.04, but any standard *.deb or *.rpm-based distro should work) and install the guest kernel packages built in the previous step. The guest kernel packages are available in 'snp-release-<DATE>/linux/guest' directory.

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

## Reference

https://developer.amd.com/sev/

[1] guest_memfd (a.k.a. "gmem", or "Unmapped Private Memory"): https://lore.kernel.org/kvm/20230914015531.1419405-1-seanjc@google.com/
