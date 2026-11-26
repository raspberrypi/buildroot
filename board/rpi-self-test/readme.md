# Raspberry Pi self-test

A small image which checks the hardware of a Raspberry Pi and shows the
result on HDMI and on the UART. It supports BCM2711 (Pi 4, Pi 400, CM4, CM4S)
and BCM2712 (Pi 5, Pi 500, CM5).

It is meant for devices with secure-boot enabled, where the normal diagnostic
images cannot be used because they give access to the device. You sign this
image with your own secure-boot key and it then runs on your devices without
giving anyone a login, a shell or access to the storage.

## What it does

When it boots it first collects an inventory, without exercising anything:

* Board model, serial numbers, revision, memory size and SoC stepping.
* SDRAM size from OTP, checked against the board revision.
* Secure-boot state: the hash of the customer public key programmed in OTP
  (in the same form as `sha256sum`) and the bootloader anti-rollback version.
* Bootloader and firmware versions, the boot order and how it was booted.
* CPU type, clocks and temperature; voltages and throttling. On the Pi 5
  family the supply voltage and rails are measured by the PMIC
  (`vcgencmd pmic_read_adc`) and the supply current limit and USB-PD
  profiles are shown.
* eMMC / SD: manufacturer, product, capacity, date, wear estimate, bus mode,
  and the size and type of each partition.
* PCIe and USB devices.
* Wi-Fi and Bluetooth: whether the chip was found and its firmware loaded.
* HDMI: whether a monitor is connected, and its name from the EDID.
* The number of errors in the kernel log.

It then runs three tests, shortest first:

1. Storage: reads 64MB from each eMMC / SD and reports the speed. The data
   is discarded.
2. Ethernet: link speed, DHCP, then a ping of the gateway and of
   www.google.com.
3. Memory: one pass of `memtester` over up to half of the memory. This
   takes several minutes.

## Reading the result

**HDMI** shows one screen at 1080p which is redrawn in place, so it can be
photographed. The second line is the status: what is running and a list of
any issues. Lines which report a problem are red and the status turns green
when everything has finished without one. Status text for a problem is always
in upper case, e.g. `NO LINK`, `READ ERROR`, `FAILED`.

**UART** (115200 baud) gets the same information as plain text for capture
with a terminal emulator:

* The inventory is logged before any test starts, followed by the EEPROM
  config, the kernel errors and the firmware log. If a board hangs during a
  test this has already been logged.
* Each test result is logged when it completes.
* The whole report is logged again when the memory test finishes.

The UART shows a few extra lines which are left off HDMI when the screen is
full (64-bit serial / device ID, raw OTP attributes, USB-PD profiles,
partitions, additional USB devices).

## Should I sign it?

Signing an image is permanent for that key: every device which trusts your
key will boot it, for anyone who has a copy of the signed image and physical
access to a device. Read this section before you decide.

### What the image cannot be used for

* **No login or shell.** There is no getty on HDMI or UART, no SSH and no
  other network service. The login programs are not in the image, all
  accounts are locked and the emergency, rescue and debug shells are
  disabled.
* **No input.** Nothing reads the keyboard or the UART. The kernel has no
  keyboard / HID support, the UART receivers are turned off, and there is no
  SysRq or KGDB.
* **No access to storage.** Nothing is mounted or written and the kernel has
  no disk file-systems, no USB storage support and no USB gadget (so the
  device cannot present its eMMC to a host). The read test discards what it
  reads. An encrypted (e.g. LUKS) partition is never unlocked.
* **No secrets from OTP.** The device private key and the customer OTP rows
  are not read. The key hash which is shown is the hash of your *public* key.
* **Nothing new can be loaded.** The kernel command line, config.txt and
  initramfs are inside the signed `boot.img`, HAT EEPROMs are not read, and
  kernel module loading is turned off before the memory test starts.

### What it tells whoever runs it

Anyone who can run the image on a device sees, on HDMI and the UART:

* Serial numbers, MAC addresses and the device ID.
* The bootloader (EEPROM) config. This can include the addresses of your
  network boot or HTTP boot servers.
* The partition layout: sizes and file-system types, not contents.
* The firmware log of this boot.

On the network it sends a DHCP request (with the hostname `rpi-self-test`),
a DNS lookup and pings. It sends nothing else.

### What to weigh up

* It is still a Linux kernel running on your device with the USB, PCIe, SD,
  HDMI and Ethernet ports active. The kernel has been cut down to reduce
  what an attacker with physical access can reach, but a kernel bug could
  still let them run their own code. Code running as root can ask the
  firmware for the device private key, as it can in any image you sign. This
  is the main risk.
* The image has been reviewed but has not had an independent security audit
  or penetration test.
* A signed image cannot be withdrawn. Keep the signed `boot.img` /
  `boot.sig` under the same control as your other signed images rather than
  publishing them.

As a guide: signing it is reasonable if a hardware report for someone with
the device in their hands is worth the information listed above, and your
other signed images already accept the same kernel-level risk. Do not sign
it if the EEPROM config or device identifiers must stay confidential from
whoever holds the device, or if your devices must never run anything except
your production image.

Also note that any `boot.img` signed with the same key will boot on the
device. Never sign an image which does expose storage (e.g.
`mass-storage-gadget64`) with a production key.

## Building

```
git clone --branch rpi-self-test git@github.com:raspberrypi/buildroot.git
cd buildroot
make rpi-self-test_defconfig
make
```

Output in `output/images`:

* `boot.img` - firmware, kernel, device-trees and initramfs (unsigned).
* `config.txt` - `boot_ramdisk=1`, selects `boot.img`.
* `sdcard.img` - `config.txt` + unsigned `boot.img`. This can be written to
  an SD card / eMMC to run the self-test on a device without secure-boot.

Building it yourself, from source you have reviewed, is the best way to know
what you are signing.

## Signing

Sign `boot.img` with the customer private key using `rpi-eeprom-digest`
from the [rpi-eeprom](https://github.com/raspberrypi/rpi-eeprom) repo:

```
rpi-eeprom-digest -i boot.img -o boot.sig -k private.pem
```

Copy `config.txt`, `boot.img` and `boot.sig` to the FAT boot partition of
the SD card / eMMC.

To run the self-test via RPIBOOT instead, copy the
[usbboot](https://github.com/raspberrypi/usbboot) `mass-storage-gadget64`
directory and replace its `boot.img` with this one. Check this has been done,
otherwise the mass-storage gadget would be signed. Sign it with `sign.sh`,
which also handles the Pi 5 firmware counter-signature and the
public key needed in RPIBOOT mode. Then run `rpiboot -d <directory>`.
