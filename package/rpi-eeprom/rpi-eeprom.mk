################################################################################
#
# rpi-eeprom
#
################################################################################

RPI_EEPROM_VERSION = fe7bfc720165464d9dfe2f85fe090ca22a625bd7
RPI_EEPROM_SITE = $(call github,raspberrypi,rpi-eeprom,$(RPI_EEPROM_VERSION))
RPI_EEPROM_LICENSE = BSD-3-Clause
RPI_EEPROM_LICENSE_FILES = LICENSE

HOST_RPI_EEPROM_INSTALL = YES
RPI_EEPROM_INSTALL = YES

HOST_RPI_EEPROM_DEPENDENCIES = host-python3 host-python-pycryptodomex

define HOST_RPI_EEPROM_INSTALL_CMDS
	$(INSTALL) -D -m 0755 $(@D)/rpi-eeprom-digest $(HOST_DIR)/bin/rpi-eeprom-digest
	$(INSTALL) -D -m 0755 $(@D)/rpi-eeprom-config $(HOST_DIR)/bin/rpi-eeprom-config
endef

define RPI_EEPROM_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/rpi-eeprom-digest $(TARGET_DIR)/bin/rpi-eeprom-digest
	$(INSTALL) -D -m 0755 $(@D)/tools/rpi-bootloader-key-convert $(TARGET_DIR)/bin/rpi-bootloader-key-convert
	$(INSTALL) -D -m 0755 $(@D)/tools/rpi-otp-private-key $(TARGET_DIR)/bin/rpi-otp-private-key
endef

$(eval $(generic-package))
$(eval $(host-generic-package))
