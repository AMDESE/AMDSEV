Follow the below steps to build and run the SEV-SNP guest. The step below are tested on Fedora 31 host and guest.

## Build and Install

````
# git clone https://github.com/AMDESE/AMDSEV.git
# git checkout sev-snp-devel
# ./build.sh
# sudo rpm -ivh kernel-*.rpm
# sudo cp kvm.conf /etc/modprobe.d/
````
Reboot the host and choose SNP kernel from the grub menu. 

Run the following command to verify that SNP is enabled in the host.

````
# dmesg | grep -i rmp
SVM: SNP: RMP physical range 0x0000000098500000 - 0x00000000a89fffff
SVM: SNP: RMP table 0xffffa07000000000+0x104fffff
SVM: SNP: SYSCFG MEM_ENCRYPT: enabled SNP_EN: enabled VMPL_EN: enabled RMP_BASE: 0x98500000 RMP_END: 0xa89fffff
SVM: SNP: rmp setup completed!

# cat /sys/module/kvm_amd/parameters/sev
1
# cat /sys/module/kvm_amd/parameters/sev_es 
1
# cat /sys/module/kvm_amd/parameters/sev_snp 
1
````

## Prepare Guest

Boot up the FC31 guest and install the kernel package built in the previous step.

## Launch SNP Guest

To launch the SNP guest use the launch-qemu.sh script provided in this repository

````
# ./launch-qemu.sh -hda <your_qcow2_file> -sev-snp
````

To launch SNP disabled guest, simply remove the "-sev-snp" from the above command line.

Once the guest is booted, run the following command inside the guest VM to verify that SNP is enabled:

````
$ dmesg | grep -i snp
AMD Secure Nested Paging (SEV-SNP) active
````

## Reference

https://developer.amd.com/sev/
