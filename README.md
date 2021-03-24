Follow the below steps to build and run the SEV-SNP guest. The step below are tested on Ubuntu 20.04 host and guest.

## Build and Install

````
# git clone https://github.com/AMDESE/AMDSEV.git
# git checkout sev-snp-devel
# ./build.sh
# sudo dpkg -ivh linux-*.rpm
# sudo cp kvm.conf /etc/modprobe.d/
````

Reboot the host and choose SNP kernel from the grub menu. 

Run the following command to verify that SNP is enabled in the host.

````
# dmesg | grep -i snp
SEV-SNP API:1.22 build:22
SEV supported: 410 ASIDs
SEV-ES supported: 99 ASIDs
SEV-SNP supported: 99 ASIDs

# cat /sys/module/kvm_amd/parameters/sev
1
# cat /sys/module/kvm_amd/parameters/sev_es 
1
# cat /sys/module/kvm_amd/parameters/sev_snp 
1

````

## Prepare Guest

Boot up the Ubuntu 20.04 guest and install the kernel package built in the previous step.

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

## Reference

https://developer.amd.com/sev/
