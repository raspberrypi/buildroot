#!/bin/bash
#
# Creates boot.img (firmware + kernel + initramfs) which the customer signs
# with their secure-boot private key, plus sdcard.img containing an unsigned
# copy of boot.img for testing on devices without secure-boot enabled.

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
cp -f "${KERNEL_BUILD_DIR}/arch/arm64/boot/dts/broadcom/"bcm271[12]*.dtb "${BINARIES_DIR}"

# Only the overlays used by config.txt.
rm -rf "${BINARIES_DIR}/self-test-overlays"
mkdir -p "${BINARIES_DIR}/self-test-overlays/overlays"
# bcm2712d0 is applied by the firmware on BCM2712 D0 boards.
for ovl in bcm2712d0 dwc2 vc4-kms-v3d-pi4 vc4-kms-v3d-pi5; do
	cp -f "${KERNEL_BUILD_DIR}/arch/arm64/boot/dts/overlays/${ovl}.dtbo" \
		"${BINARIES_DIR}/self-test-overlays/overlays/"
done

run_genimage() {
	rm -rf "${GENIMAGE_TMP}"
	genimage \
		--rootpath "${ROOTPATH_TMP}"   \
		--tmppath "${GENIMAGE_TMP}"    \
		--inputpath "${BINARIES_DIR}"  \
		--outputpath "${BINARIES_DIR}" \
		--config "$1"
}

rm -f "${BINARIES_DIR}/boot.img" "${BINARIES_DIR}/boot.sig" "${BINARIES_DIR}/sdcard.img"
run_genimage "${BOARD_DIR}/genimage.cfg"

cp -f "${BOARD_DIR}/config-sd.txt" "${BINARIES_DIR}/config.txt"
run_genimage "${BOARD_DIR}/genimage-sdcard.cfg"
