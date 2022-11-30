################################################################################
#
# rpi-eeprom
#
################################################################################

RPI_EEPROM_VERSION = 0ebda77d49ba90927fa1214bb7068cd744e7d811
RPI_EEPROM_SITE = $(call github,raspberrypi,rpi-eeprom,$(RPI_EEPROM_VERSION))
RPI_EEPROM_LICENSE = BSD-3-Clause
RPI_EEPROM_LICENSE_FILES = LICENSE

HOST_RPI_EEPROM_INSTALL = YES
RPI_EEPROM_INSTALL = YES

ifneq ($(BR2_PACKAGE_RPI_EEPROM_ADMIN_SSH_LOGIN),)
define RPI_EEPROM_ADMIN_SSH_LOGIN_CMDS
	$(INSTALL) -d -m 0700 $(TARGET_DIR)/home/admin/.ssh
	$(INSTALL) -D -m 0600 $(BR2_PACKAGE_RPI_EEPROM_ADMIN_SSH_LOGIN) $(TARGET_DIR)/home/admin/.ssh/authorized_keys
endef
endif

define HOST_RPI_EEPROM_INSTALL_CMDS
	$(INSTALL) -D -m 0755 $(@D)/rpi-eeprom-digest $(HOST_DIR)/bin/rpi-eeprom-digest
	$(INSTALL) -D -m 0755 $(@D)/rpi-eeprom-config $(HOST_DIR)/bin/rpi-eeprom-config
endef

define RPI_EEPROM_INSTALL_TARGET_CMDS
	$(RPI_EEPROM_ADMIN_SSH_LOGIN_CMDS)
	$(INSTALL) -D -m 0755 $(@D)/rpi-eeprom-digest $(TARGET_DIR)/bin/rpi-eeprom-digest
	$(INSTALL) -D -m 0755 $(@D)/tools/rpi-bootloader-key-convert $(TARGET_DIR)/bin/rpi-bootloader-key-convert
	$(INSTALL) -D -m 0755 $(@D)/tools/rpi-otp-private-key $(TARGET_DIR)/bin/rpi-otp-private-key
endef

$(eval $(generic-package))
$(eval $(host-generic-package))
