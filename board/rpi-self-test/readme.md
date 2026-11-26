# Raspberry Pi self-test

A simple health check for a Raspberry Pi. It is loaded into memory over USB
with RPIBOOT, checks the hardware and shows the result on HDMI and on the
UART. It supports BCM2711 (Pi 4, Pi 400, CM4, CM4S) and BCM2712 (Pi 5,
Pi 500, CM5).

Run it as a pre-check, before the regular tools such as the bootloader
recovery images or `mass-storage-gadget64`. It changes nothing on the device
and gives no access to it, so it can also be signed for devices with
secure-boot enabled, where the normal diagnostic images cannot be used.

## Goals

1. **A simple health check which is loaded over RPIBOOT.** It does not need
   a working SPI flash (bootloader EEPROM) or eMMC: the bootloader, firmware,
   kernel and self-test are all loaded from the host into memory. It can also
   be booted from an SD card or USB drive.
2. **It does not reveal private data.** It does not read the OTP keys or the
   contents of the storage (e.g. LUKS partitions) and there is no login.
3. **It cannot be used to run other software.**
4. **It does not accept inbound connections.**
5. **It does not modify the device.** The OTP, SPI flash and eMMC / SD / NVMe
   are not written.
6. **The reference platforms for Compute Modules are the IO boards**: CM4 on
   the CM4 IO board and CM5 on the CM5 IO board. On another carrier board,
   expect the tests of ports which are not fitted to fail.

"Should I sign it?" below explains how goals 2 to 5 are met and what the
limits are.

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
2. Ethernet: link speed, DHCP, a ping of the gateway, then one HTTPS
   request to Raspberry Pi (see "What it sends to Raspberry Pi").
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
* **No inbound connections.** Nothing listens on the network: there is no
  server of any kind, IPv6 is off, and Wi-Fi and Bluetooth are detected but
  never brought up. The device only answers pings.
* **No access to storage.** Nothing is mounted and the kernel has no disk
  file-systems, no USB storage support and no USB gadget (so the device
  cannot present its eMMC to a host). The read test discards what it reads.
  An encrypted (e.g. LUKS) partition is never unlocked.
* **No secrets from OTP.** The device private key and the customer OTP rows
  are not read, and the kernel OTP and `/dev/mem` drivers are not built. The
  key hash which is shown is the hash of your *public* key.
* **Nothing new can be loaded.** The kernel command line, config.txt and
  initramfs are inside the signed `boot.img`, HAT EEPROMs are not read, and
  kernel module loading is turned off before the memory test starts. The
  reply to the one web request is discarded.
* **Nothing is written to the device.** Every eMMC, SD and NVMe device is
  write-protected as soon as it is detected (shown as `write-protected` in
  the UART log). The kernel has no SPI driver, so it cannot reach the
  bootloader EEPROM, and there are no tools in the image to program OTP or
  update the bootloader. The clock is set in memory only; a battery backed
  clock is not changed.

### What it tells whoever runs it

Anyone who can run the image on a device sees, on HDMI and the UART:

* Serial numbers, MAC addresses and the device ID.
* The bootloader (EEPROM) config. This can include the addresses of your
  network boot or HTTP boot servers.
* The partition layout: sizes and file-system types, not contents.
* The firmware log of this boot.

### What it sends to Raspberry Pi

To test the Internet connection the image fetches one URL with `curl`:

```
https://downloads.raspberrypi.com/rpi-self-test?serial64=<serial>&board-revision=<rev>&sdram-size-gbit=<size>&over_voltage_avs=<uV>
```

* `serial64` - the 64-bit serial number of the device.
* `board-revision` - the board revision code from OTP, e.g. `d04180`.
* `sdram-size-gbit` - the size of the SDRAM in gigabits.
* `over_voltage_avs` - the core voltage adjustment set at manufacture, in
  microvolts.

Raspberry Pi uses these to match the device with its manufacturing records.
Like any web request, the server also sees the public IP address it came
from. The MAC addresses, the EEPROM config, the key hash, the test results
and everything else in the report are **not** sent. The reply is discarded:
the test passes if the server answers over a verified HTTPS connection.

Most boards have no clock battery, and a certificate cannot be checked
without the date. So the image first makes one plain HTTP request to
`http://downloads.raspberrypi.com/` (no parameters) and sets the clock from
the `Date` header of the reply. The clock is only ever moved forwards.

The line marked `Sent` in the UART log shows exactly what was sent.

If you do not want this, change `REPORT_URL` and `REPORT_HOST` at the top of
`rootfs_overlay/usr/bin/rpi-self-test` to a server of your own, or remove the
call to `internetTest`, and build your own image.

Otherwise the only network traffic is a DHCP request (with the hostname
`rpi-self-test`), a DNS lookup and pings of the gateway.

### What to weigh up

* It is still a Linux kernel running on your device with the USB, PCIe, SD,
  HDMI and Ethernet ports active. The kernel has been cut down to reduce
  what an attacker with physical access can reach, but a kernel bug could
  still let them run their own code. Code running as root can ask the
  firmware for the device private key or to program OTP, as it can in any
  image you sign. This is the main risk.
* The image contains `curl` and a TLS library, which process data from the
  network. `curl` is only run for the two requests above, each restricted
  to a single protocol, and it is built without proxy or cookie support.
* The image has been reviewed but has not had an independent security audit
  or penetration test.
* A signed image cannot be withdrawn. Keep the signed `boot.img` /
  `boot.sig` under the same control as your other signed images rather than
  publishing them.

As a guide: signing it is reasonable if a hardware report for someone with
the device in their hands is worth the information listed above, and your
other signed images already accept the same kernel-level risk. Do not sign
it if the EEPROM config or device identifiers must stay confidential from
whoever holds the device, if the device must not contact Raspberry Pi (build
your own image instead), or if your devices must never run anything except
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
* `sdcard.img` - `config.txt` + unsigned `boot.img`. Write this to an SD
  card or USB drive to run the self-test without RPIBOOT on a device which
  does not have secure-boot enabled.

Building it yourself, from source you have reviewed, is the best way to know
what you are signing.

## Running and signing

The [usbboot](https://github.com/raspberrypi/usbboot) repo has an
`rpi-self-test` directory with the RPIBOOT files and instructions. In short:

```
cd usbboot/rpi-self-test
./download.sh               # or copy your own boot.img here
sudo ../rpiboot -d .
```

For a device with secure-boot enabled, sign it first with your key:

```
./sign.sh private.pem
```

`sign.sh` signs `boot.img`, and also handles the Pi 5 firmware
counter-signature and the public key needed in RPIBOOT mode.
