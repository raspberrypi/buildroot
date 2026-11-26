################################################################################
#
# rpi-make-boot-image
#
################################################################################

# Only the script is downloaded because the usbboot repository is large.
RPI_MAKE_BOOT_IMAGE_VERSION = 70000819d786d56b33fc278f6f1fcd023dc60d98
RPI_MAKE_BOOT_IMAGE_SITE = https://raw.githubusercontent.com/raspberrypi/usbboot/$(RPI_MAKE_BOOT_IMAGE_VERSION)/tools
RPI_MAKE_BOOT_IMAGE_SOURCE = rpi-make-boot-image
RPI_MAKE_BOOT_IMAGE_LICENSE = Apache-2.0
HOST_RPI_MAKE_BOOT_IMAGE_DEPENDENCIES = host-dosfstools host-mtools

define HOST_RPI_MAKE_BOOT_IMAGE_EXTRACT_CMDS
	cp $(HOST_RPI_MAKE_BOOT_IMAGE_DL_DIR)/rpi-make-boot-image $(@D)
endef

define HOST_RPI_MAKE_BOOT_IMAGE_INSTALL_CMDS
	$(INSTALL) -D -m 0755 $(@D)/rpi-make-boot-image \
		$(HOST_DIR)/bin/rpi-make-boot-image
endef

$(eval $(host-generic-package))
