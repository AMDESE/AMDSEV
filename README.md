Follow the below steps to build and run the SEV-SNP guest. The step below are tested on Ubuntu 20.04 host and guest.

## Upgrading from 5.19-based SNP hypervisor/host kernels

This repo will build host/guest kernel, QEMU, and OVMF packages that are known to work against the latest development for tree SNP host/hypervisor support. If you are building packages to use in conjunction with an older 5.19-based SNP host/hypervisor kernel, then please use the [sev-snp-devel](https://github.com/amdese/amdsev/tree/sev-snp-devel) branch of this repo instead, which will ensure that compatible QEMU/OVMF trees are used instead. Please consider switching to the latest development trees used by this branch however, as [sev-snp-devel](https://github.com/amdese/amdsev/tree/sev-snp-devel) is no longer being actively developed.

Newer SNP host/kernel support now relies on new kernel infrastructure for managing private guest memory called restrictedmem[1] (a.k.a. Unmapped Private Memory). This reliance on restrictedmem brings about some new requirements/limitations in the current tree that users should be aware:
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

Verify that the following BIOS settings are enabled. The setting may vary based on the vendor BIOS. The menu option below are from AMD BIOS.
  
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

[1] restrictedmem (a.k.a. Unmapped Private Memory): https://lore.kernel.org/lkml/20221202061347.1070246-1-chao.p.peng@linux.intel.com/
