################################################################################
#
# rpi-bootloader-version
#
################################################################################

RPI_BOOTLOADER_VERSION_VERSION = 2fee426f27b6c54d3f5b6f36efd9a2fe1286a45d
RPI_BOOTLOADER_VERSION_SITE = $(call github,raspberrypi,rpi-eeprom,$(RPI_BOOTLOADER_VERSION_VERSION))
RPI_BOOTLOADER_VERSION_LICENSE = BSD-3-Clause
RPI_BOOTLOADER_VERSION_LICENSE_FILES = LICENSE

define RPI_BOOTLOADER_VERSION_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/rpi-bootloader-version \
		$(TARGET_DIR)/usr/bin/rpi-bootloader-version
endef

$(eval $(generic-package))
