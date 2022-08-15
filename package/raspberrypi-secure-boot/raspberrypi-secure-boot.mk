################################################################################
#
# raspberrypi-secure-boot
#
################################################################################

# Host and device tools for secure-boot.

RASPBERRYPI_SECURE_BOOT_VERSION = master
RASPBERRYPI_SECURE_BOOT_SITE = $(call github,raspberrypi,usbboot,$(RASPBERRYPI_SECURE_BOOT_VERSION))
RASPBERRYPI_SECURE_BOOT_LICENSE = Apache-2.0
RASPBERRYPI_SECURE_BOOT_LICENSE_FILES = LICENSE

HOST_RASPBERRYPI_SECURE_BOOT_DEPENDENCIES = openssl
HOST_RASPBERRYPI_SECURE_BOOT_INSTALL = YES

RASPBERRYPI_SECURE_BOOT_DEPENDENCIES = openssl
RASPBERRYPI_SECURE_BOOT_INSTALL = YES

ifneq ($(BR2_PACKAGE_RASPBERRYPI_SECURE_BOOT_ADMIN_SSH_LOGIN),)
define RASPBERRYPI_SECURE_BOOT_ADMIN_SSH_LOGIN_CMDS
	$(INSTALL) -d -m 0700 $(TARGET_DIR)/home/admin/.ssh
	$(INSTALL) -D -m 0600 $(BR2_PACKAGE_RASPBERRYPI_SECURE_BOOT_ADMIN_SSH_LOGIN) $(TARGET_DIR)/home/admin/.ssh/authorized_keys
endef
endif

define HOST_RASPBERRYPI_SECURE_BOOT_INSTALL_CMDS
	$(INSTALL) -D -m 0755 $(@D)/tools/rpi-eeprom-digest $(HOST_DIR)/bin/rpi-eeprom-digest
	$(INSTALL) -D -m 0755 $(@D)/tools/make-boot-image $(HOST_DIR)/bin/make-boot-image
endef

define RASPBERRYPI_SECURE_BOOT_INSTALL_TARGET_CMDS
	$(RASPBERRYPI_SECURE_BOOT_ADMIN_SSH_LOGIN_CMDS)
	$(INSTALL) -D -m 0755 $(@D)/tools/rpi-eeprom-digest $(TARGET_DIR)/bin/rpi-eeprom-digest
	$(INSTALL) -D -m 0755 $(@D)/tools/rpi-bootloader-key-convert $(TARGET_DIR)/bin/rpi-bootloader-key-convert
endef

$(eval $(generic-package))
$(eval $(host-generic-package))
