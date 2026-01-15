#!/bin/bash

set -e

BOARD_DIR="$(dirname $0)"
BOARD_NAME="$(basename ${BOARD_DIR})"
GENIMAGE_CFG="${BOARD_DIR}/genimage.cfg"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"

# Pass an empty rootpath. genimage makes a full copy of the given rootpath to
# ${GENIMAGE_TMP}/root so passing TARGET_DIR would be a waste of time and disk
# space. We don't rely on genimage to build the rootfs image, just to insert a
# pre-built one in the disk image.

trap 'rm -rf "${ROOTPATH_TMP}"' EXIT
ROOTPATH_TMP="$(mktemp -d)"

rm -rf "${GENIMAGE_TMP}"

KERNEL_VERSION=linux-rpi-6.12.y
# Hack: Prefer the kernel overlays to the rpi-firmware versions
rm -f ${BINARIES_DIR}/*.dtb
cp -fv "${BINARIES_DIR}/../build/${KERNEL_VERSION}/arch/arm/boot/dts/broadcom/"*.dtb "${BINARIES_DIR}"

rm -rf "${BINARIES_DIR}/rpi-firmware/overlays"
mkdir -p "${BINARIES_DIR}/rpi-firmware/overlays"
cp -f "${BOARD_DIR}/dwc2.dtbo" "${BINARIES_DIR}/rpi-firmware/overlays"
cp -f  "${BINARIES_DIR}/../build/${KERNEL_VERSION}/arch/arm/boot/dts/overlays/"*.dtb "${BINARIES_DIR}/rpi-firmware/overlays"
touch "${BINARIES_DIR}/../build/${KERNEL_VERSION}/arch/arm/boot/dts/overlays" "${BINARIES_DIR}/rpi-firmware/overlays/README"

genimage \
	--rootpath "${ROOTPATH_TMP}"   \
	--tmppath "${GENIMAGE_TMP}"    \
	--inputpath "${BINARIES_DIR}"  \
	--outputpath "${BINARIES_DIR}" \
	--config "${GENIMAGE_CFG}"

exit $?
