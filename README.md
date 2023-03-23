PLEASE NOTE: the development trees used to build these packages are no longer actively developed. To build using the latest SNP development trees please use the [snp-latest](https://github.com/amdese/amdsev/tree/snp-latest) branch of this repo.

Follow the below steps to build and run the SEV-SNP guest. The step below are tested on Ubuntu 20.04 host and guest.

## Build

The following command builds the host and guest Linux kernel, qemu and ovmf bios used for launching SEV-SNP guest.

````
# git clone https://github.com/AMDESE/AMDSEV.git
# git checkout sev-snp-devel
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

The SEV-SNP support requires firmware version >= 1.51:1 (or 1.33 in hexadecimal, which is what developer.amd.com uses when uploading firmware versions). The latest SEV-SNP firmware is available on https://developer.amd.com/sev and via the linux-firmware project.

The below steps document the firmware upgrade process for the latest SEV-SNP firmware available on https://developer.amd.com/sev at the time this was written. A similar procedure can be used for newer firmwares as well:

```
# wget https://developer.amd.com/wp-content/resources/amd_sev_fam19h_model0xh_1.33.03.zip
# unzip amd_sev_fam19h_model0xh_1.33.03.zip
# sudo mkdir -p /lib/firmware/amd
# sudo cp amd_sev_fam19h_model0xh_1.33.03.sbin /lib/firmware/amd/amd_sev_fam19h_model0xh.sbin
```
Then either reboot the host, or reload the ccp driver to complete the firmware upgrade process:

```
sudo rmmod kvm_amd
sudo rmmod ccp
sudo modprobe ccp
sudo modprobe kvm_amd
```


## Reference

https://developer.amd.com/sev/
