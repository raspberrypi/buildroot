#!/bin/bash
#
# Creates boot.img (firmware + kernel + initramfs) which the customer signs
# with their secure-boot private key, plus sdcard.img for devices without
# secure-boot enabled. sdcard.img contains an unsigned copy of boot.img for
# BCM2711 / BCM2712 and the same files unpacked, with bootcode.bin, for
# BCM2837 which cannot load a boot.img.

set -e

BOARD_DIR="$(dirname $0)"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"
KERNEL_BUILD_DIR="$(ls -d "${BUILD_DIR}"/linux-* | grep -v headers | head -n 1)"

trap 'rm -rf "${ROOTPATH_TMP}"' EXIT
ROOTPATH_TMP="$(mktemp -d)"

# The firmware supports compressed 64-bit kernel images.
if [ -f "${BINARIES_DIR}/Image" ]; then
	rm -f "${BINARIES_DIR}/Image.gz" "${BINARIES_DIR}/kernel8.img"
	gzip "${BINARIES_DIR}/Image"
	mv "${BINARIES_DIR}/Image.gz" "${BINARIES_DIR}/kernel8.img"
fi

# Use the device-tree files from the kernel build rather than rpi-firmware.
rm -f "${BINARIES_DIR}"/*.dtb
cp -f "${KERNEL_BUILD_DIR}/arch/arm64/boot/dts/broadcom/"bcm271[012]*.dtb "${BINARIES_DIR}"

# boot.img: the firmware, device-trees, kernel, initramfs and only the
# overlays used by config.txt. rpi-make-boot-image makes the FAT file-system
# no larger than these files need, which keeps the boot time down.
STAGING="${ROOTPATH_TMP}/boot"
mkdir -p "${STAGING}/overlays"
for dtb in bcm2710-rpi-3-b bcm2710-rpi-3-b-plus bcm2710-rpi-cm3 \
		bcm2711-rpi-4-b bcm2711-rpi-400 bcm2711-rpi-cm4 bcm2711-rpi-cm4s \
		bcm2712-rpi-5-b bcm2712d0-rpi-5-b bcm2712-d-rpi-5-b bcm2712-rpi-500 \
		bcm2712-rpi-cm5-cm5io bcm2712-rpi-cm5-cm4io \
		bcm2712-rpi-cm5l-cm5io bcm2712-rpi-cm5l-cm4io; do
	cp "${BINARIES_DIR}/${dtb}.dtb" "${STAGING}"
done
cp "${BINARIES_DIR}/kernel8.img" "${BINARIES_DIR}/rootfs.cpio.zst" "${STAGING}"
for f in cmdline.txt config.txt fixup.dat fixup4.dat start.elf start4.elf; do
	cp "${BINARIES_DIR}/rpi-firmware/${f}" "${STAGING}"
done
# bcm2712d0 is applied by the firmware on BCM2712 D0 boards.
for ovl in bcm2712d0 dwc2 vc4-kms-v3d vc4-kms-v3d-pi4 vc4-kms-v3d-pi5; do
	cp "${KERNEL_BUILD_DIR}/arch/arm64/boot/dts/overlays/${ovl}.dtbo" \
		"${STAGING}/overlays"
done

rm -f "${BINARIES_DIR}/boot.img" "${BINARIES_DIR}/boot.sig" "${BINARIES_DIR}/sdcard.img"
rpi-make-boot-image -a 64 -d "${STAGING}" -o "${BINARIES_DIR}/boot.img"

# sdcard.img: a FAT partition holding config.txt and the unsigned boot.img,
# which is all that BCM2711 and BCM2712 load. The BCM2837 firmware does not
# support boot_ramdisk, so the contents of boot.img are also copied to the
# partition, with bootcode.bin, and its config.txt is appended.
SDCARD="${ROOTPATH_TMP}/sdcard"
mkdir -p "${SDCARD}"
cp -f "${BOARD_DIR}/config-sd.txt" "${BINARIES_DIR}/config.txt"
cp -r "${STAGING}/." "${SDCARD}"
cp "${BINARIES_DIR}/rpi-firmware/bootcode.bin" "${BINARIES_DIR}/boot.img" "${SDCARD}"
cat "${BINARIES_DIR}/config.txt" "${STAGING}/config.txt" > "${SDCARD}/config.txt"
rpi-make-boot-image -d "${SDCARD}" -o "${BINARIES_DIR}/sdcard.vfat"

rm -rf "${GENIMAGE_TMP}"
genimage \
	--rootpath "${ROOTPATH_TMP}"   \
	--tmppath "${GENIMAGE_TMP}"    \
	--inputpath "${BINARIES_DIR}"  \
	--outputpath "${BINARIES_DIR}" \
	--config "${BOARD_DIR}/genimage-sdcard.cfg"
