# Raspberry Pi signed-boot

## Overview

This package provides an example defconfig, board config and helper packages
that demonstrates how to build a signed boot image for Raspberry Pi.

The intention is to provide a working example and instructions for the Raspberry Pi
specific aspects of a secure-boot system i.e. the creation of the signed `boot.img`
file.  This should make it easier to add secure-boot to existing buildroot based
systems for Raspberry Pi.

**Security note**
For development/debug a UART console is enabled with a password less root &
admin users. In a production system:

* Login as root should be disabled
* Password based login for other users should be disabled.

### Building

```
git clone --branch raspberrypi-signed-boot https://github.com/raspberrypi/buildroot
cd buildroot
make raspberrypi-signed-boot_defconfig
make menuconfig
```

To configure the `raspberrypi-secure-boot` options run `make menuconfig` and go to
`Target packages -->  System Tools --> raspberrypi-secure-boot`.

* Specify the path of the private key in PEM format e.g. ../private.pem
* Specify the path of an SSH authorized key files to use to login as an 'admin' user - for DEBUG

```
make savedefconfig
make
```

The output files are `boot.img` and `boot.sig` under `output/target/images`

Either copy these to an SD-CARD or replace the files in `secure-boot-example`
in the [usbboot](https://github.com/raspberrypi/usbboot) repo.

### Performance considerations

For simplicity, this example uses the unmodified generic Raspberry Pi
firmware and kernel configurations. In a real system the image can be
made considerably smaller by only including the modules that will be
used and removing any unecessary kernel debug.
