################################################################################
#
# rpi-utils
#
################################################################################

RPI_UTILS_VERSION = e9f9ad4e8107fb01b87fd37c55bd96bf681b5384
RPI_UTILS_SITE = $(call github,raspberrypi,utils,$(RPI_UTILS_VERSION))
RPI_UTILS_LICENSE = BSD-3-Clause
RPI_UTILS_LICENSE_FILES = LICENCE

RPI_UTILS_TOOLS-$(BR2_PACKAGE_RPI_UTILS_VCGENCMD) += vcgencmd
RPI_UTILS_TOOLS-$(BR2_PACKAGE_RPI_UTILS_VCLOG) += vclog

define RPI_UTILS_BUILD_CMDS
	$(foreach t,$(RPI_UTILS_TOOLS-y),
		$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) \
			-o $(@D)/$(t)/$(t) $(@D)/$(t)/$(t).c
	)
endef

define RPI_UTILS_INSTALL_TARGET_CMDS
	$(foreach t,$(RPI_UTILS_TOOLS-y),
		$(INSTALL) -D -m 0755 $(@D)/$(t)/$(t) $(TARGET_DIR)/usr/bin/$(t)
	)
endef

$(eval $(generic-package))
