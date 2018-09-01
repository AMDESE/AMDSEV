# Table of contents
* [ Introduction ](#intro)
* [ Kata Containers with SEV ](#kata-sev)
* [ Ubuntu-18.04 ](#ubuntu18)
  * [ Prepare Host OS ](#ubuntu18-kata-host)
  * [ Install Kata ](#ubuntu18-kata-install)
  * [ Launch SEV Container ](#ubuntu18-kata-launch)
* [ Additional resources ](#resources)
* [ FAQ ](#faq)
  * [ How do I know if my Hypervisor supports SEV ](#faq-1)
  * [ How do I know if SEV is enabled in the guest](#faq-2)
  * [ Can I use virt-manager to launch SEV guests](#faq-3)
  * [ How to increase SWIOTLB limit](#faq-4)
  * [ virtio-blk fails with out-of-dma-buffer error](#faq-5)  
  
<a name="intro"></a>
# Secure Encrypted Virtualization (SEV)

SEV is an extension to the AMD-V architecture which supports running encrypted
virtual machine (VMs) under the control of KVM. Encrypted VMs have their pages
(code and data) secured such that only the guest itself has access to the
unencrypted version. Each encrypted VM is associated with a unique encryption
key; if the guest data is accessed from a different entity using a different key,
then the encrypted guest's data will be incorrectly decrypted into unintelligible
data.

SEV support has been accepted in upstream projects. This repository provides
scripts to build various components to enable SEV support until the distros
include the newer versions.

<a name="kata-sev"></a>
# Kata Containers with SEV

To enable SEV support with Kata Containers, the following component versions are required:

| Project       | Version                              |
|---------------|--------------------------------------|
| kernel        | >= 4.17                              |
| qemu          | >= 3.0                               |
| ovmf          | >= commit (75b7aa9528bd 2018-07-06 ) |

> NOTE: SEV support is not available in SeaBIOS. Guests must use OVMF.

<a name="ubuntu18"></a>
## Ubuntu 18.04

The packaged versions of the Linux kernel, qemu, and OVMF in Ubuntu 18.04 do not yet support SEV, so it is necessary to build them from source.

<a name="ubuntu18-kata-host"></a>
### Prepare Host OS

The **build.sh** script in the distros/ubuntu-18.04 directory will build and install SEV-capable versions of the host kernel, qemu, and OVMF:

> NOTE: build.sh will use 'sudo' as necessary to gain privileges to install files, so build.sh should be run as a normal user.

```
$ cd distros/ubuntu-18.04
$ ./build.sh
```

Once the kernel has been installed, reboot and choose the SEV kernel:

```
$ sudo reboot
```

At this point, the host is ready to act as a SEV-capable hypervisor. For more information about running SEV guests, see [README.md](https://github.com/AMDESE/AMDSEV/blob/master/README.md) in the master branch.

<a name="ubuntu18-kata-install"></a>
### Install Kata

Once the host is running an SEV-capable kernel, execute **build-kata.sh** in distros/ubuntu-18.04 to build, install, and configure the Kata Containers system along with the latest version of Docker CE:

> NOTE: build-kata.sh will use 'sudo' as necessary to gain privileges to install files, so build-kata.sh should be run as a normal user.

```
$ cd distros/ubuntu-18.04
$ ./build-kata.sh
```

At this point, docker is installed and configured to use the SEV-capable kata-runtime as the default runtime for containers. In addition, kata-runtime is configured to use SEV for all containers by default.

<a name="ubuntu18-kata-launch"></a>
### Launching SEV Containers

Use the following command to launch a busybox container protected by SEV:

```
$ sudo docker run -it busybox sh
```

To verify that SEV is active in the guest, look for messages in the kernel logs containing "SEV":

```
\ # dmesg | grep SEV
   [    0.001000] AMD Secure Encrypted Virtualization (SEV) active
   [    0.219196] SEV is active and system is using DMA bounce buffers
```

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

[Libvirt SEV domainCap](https://libvirt.org/formatdomaincaps.html#elementsSEV)

[Qemu doc](https://git.qemu.org/?p=qemu.git;a=blob;f=docs/amd-memory-encryption.txt;h=f483795eaafed8409b1e96806ca743354338c9dc;hb=HEAD)

[Kata Architecture](https://github.com/kata-containers/documentation/blob/master/architecture.md)

[Kata Developer Guide](https://github.com/kata-containers/documentation/blob/master/Developer-Guide.md)

<a name="faq"></a>
# FAQ

<a name="faq-1"></a>
 * **How do I know if my hypervisor supports the SEV feature?**

   a) When using libvirt >= 4.15 run the following command as root:

   ```
   # virsh domcapabilities
   ```
   If the hypervisor supports the SEV feature, then the **sev** tag will be present.

>  See [Libvirt DomainCapabilities feature](https://libvirt.org/formatdomaincaps.html#elementsSEV) for additional information.

   b) Use the QMP 'query-sev-capabilities' command to check for SEV support. If SEV is supported, then the command will return the full SEV capabilities (which includes the host PDH, cert-chain, cbitpos and reduced-phys-bits).

>  See [QMP doc](https://github.com/qemu/qemu/blob/master/docs/devel/writing-qmp-commands.txt) for details on how to interact with QMP shell.

<a name="faq-2"></a>
 * **How do I know if SEV is enabled in the guest?**
 
   a) Check the kernel log buffer for the following message:

   ```
   # dmesg | grep -i sev
   AMD Secure Encrypted Virtualization (SEV) active
   ```

   b) MSR 0xc0010131 (MSR_AMD64_SEV) can be used to determine if SEV is active:

   ```
   # rdmsr -a 0xc0010131
   ```
   <pre>
   Bit[0]:   0 = SEV is not active
             1 = SEV is active
   </pre>

<a name="faq-3"></a>
 * **Can I use virt-manager to launch SEV guests?**

    virt-manager uses libvirt to manage VMs. SEV support has been added in libvirt, but virt-manager does not use the newly introduced [LaunchSecurity](https://libvirt.org/formatdomain.html#sev) tags yet. Hence, we will not able to launch SEV guests through virt-manager.
>   If your system is using libvirt >= 4.15, then you can manually edit the xml file to use [LaunchSecurity](https://libvirt.org/formatdomain.html#sev) to enable SEV support in the guest.

<a name="faq-4"></a>
 * **How do I increase the SWIOTLB limit?**

 When SEV is enabled, all the DMA operations inside the guest are performed on the shared memory. Linux kernel uses SWIOTLB  bounce buffer for DMA operations inside SEV guest. A guest panic will occur if kernel runs out of the SWIOTLB pool. Linux kernel default to 64MB SWIOTLB pool. It is recommended to increase the swiotlb pool size to 512MB. The swiotlb pool size can be increased in guest by appending the following in the grub.cfg file

 Append the following in /etc/defaults/grub:

 ```
GRUB_CMDLINE_LINUX_DEFAULT=".... swiotlb=262144"
 ```

 And regenerate the grub.cfg.

<a name="faq-5"></a>
 * **virtio-blk device encounters an out-of-dma-buffer error**

 To support the multiqueue mode, virtio-blk drivers inside the guest allocates large number of DMA buffer. SEV guest uses SWIOTLB for the DMA buffer allocation or mapping hence kernel runs of the SWIOTLB pool quickly and triggers the out-of-memory error. In those cases consider increasing the SWIOTLB pool size or use virtio-scsi device.

