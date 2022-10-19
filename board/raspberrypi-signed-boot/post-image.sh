#!/bin/bash

set -e
env

BOARD_DIR="$(dirname $0)"
BOARD_NAME="$(basename ${BOARD_DIR})"
GENIMAGE_BOOT_CFG="${BOARD_DIR}/genimage-${BOARD_NAME}-boot.cfg"
GENIMAGE_SDCARD_CFG="${BOARD_DIR}/genimage-${BOARD_NAME}-sdcard.cfg"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"

# Pass an empty rootpath. genimage makes a full copy of the given rootpath to
# ${GENIMAGE_TMP}/root so passing TARGET_DIR would be a waste of time and disk
# space. We don't rely on genimage to build the rootfs image, just to insert a
# pre-built one in the disk image.

trap 'rm -rf "${ROOTPATH_TMP}"' EXIT
ROOTPATH_TMP="$(mktemp -d)"

rm -f "${BINARIES_DIR}/boot.vfat" "${BINARIES_DIR}/boot.sig" "${BINARIES_DIR}/sdcard.img"

# start.elf supports compressed 64-bit kernel images.
if [ -f ${BINARIES_DIR}/Image ]; then
   rm -f ${BINARIES_DIR}/Image.gz ${BINARIES_DIR}/kernel8.img
   gzip ${BINARIES_DIR}/Image
   mv ${BINARIES_DIR}/Image.gz ${BINARIES_DIR}/kernel8.img
fi

# Set the RPI_FIRMWARE_OVERRIDE_DIR environment variable to the directory containing
# custom/beta versions of start4.elf and fixup4.dat
if [ -n "${RPI_FIRMWARE_OVERRIDE_DIR}" ] && [ -f "${RPI_FIRMWARE_OVERRIDE_DIR}/start4.elf" ] && [ "${RPI_FIRMWARE_OVERRIDE_DIR}/fixup4.dat" ]; then
   echo "Overriding Raspberry Pi firmware with files from ${RPI_FIRMWARE_OVERRIDE_DIR}"
   cp -f "${RPI_FIRMWARE_OVERRIDE_DIR}/start4.elf" "${BINARIES_DIR}/rpi-firmware/start4.elf"
   cp -f "${RPI_FIRMWARE_OVERRIDE_DIR}/fixup4.dat" "${BINARIES_DIR}/rpi-firmware/fixup4.dat"
fi

# Use the VFAT image to build boot.img
rm -rf "${GENIMAGE_TMP}"
genimage \
	--rootpath "${ROOTPATH_TMP}"   \
	--tmppath "${GENIMAGE_TMP}"    \
	--inputpath "${BINARIES_DIR}"  \
	--outputpath "${BINARIES_DIR}" \
	--config "${GENIMAGE_BOOT_CFG}"

eval $(grep BR2_PACKAGE_RPI_EEPROM_PRIVATE_KEY "${BR2_CONFIG}")
KEY_ARGS=""
if [ -f "${CONFIG_DIR}/${BR2_PACKAGE_RPI_EEPROM_PRIVATE_KEY}" ]; then
   KEY_ARGS="-k ${CONFIG_DIR}/${BR2_PACKAGE_RPI_EEPROM_PRIVATE_KEY}"
fi
rpi-eeprom-digest -i "${BINARIES_DIR}/boot.img" -o "${BINARIES_DIR}/boot.sig" ${KEY_ARGS}

# Now package boot.img inside sdcard.img with a config.txt file to
# select boot.img ramdisk loading if signed-boot is not enabled.
# If secure-boot is not enabled then boot_ramdisk=1 should be set in both
# config.txt and tryboot.txt.
rm -rf "${GENIMAGE_TMP}"
cp -f "${BOARD_DIR}/config-sd.txt" "${BINARIES_DIR}/config.txt"
cp -f "${BOARD_DIR}/autoboot.txt"  "${BINARIES_DIR}/autoboot.txt"
genimage \
	--rootpath "${ROOTPATH_TMP}"   \
	--tmppath "${GENIMAGE_TMP}"    \
	--inputpath "${BINARIES_DIR}"  \
	--outputpath "${BINARIES_DIR}" \
	--config "${GENIMAGE_SDCARD_CFG}"

exit $?
