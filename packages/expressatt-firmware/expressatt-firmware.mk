################################################################################
#
# expressatt-firmware
#
################################################################################

EXPRESSATT_FIRMWARE_VERSION = 2
EXPRESSATT_FIRMWARE_SITE = $(NERVES_DEFCONFIG_DIR)/packages/expressatt-firmware
EXPRESSATT_FIRMWARE_SITE_METHOD = local
EXPRESSATT_FIRMWARE_LICENSE = GPL-2.0-or-later

# Firmware configuration defaults stock vos_nv_open inserts into the NV
# payload: 26 x 0xff followed by 6 x 0x00.
define EXPRESSATT_FIRMWARE_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/expressatt-bringup \
		$(TARGET_DIR)/usr/sbin/expressatt-bringup
	$(INSTALL) -d $(TARGET_DIR)/usr/lib/expressatt
	printf '\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\000\000\000\000\000\000' \
		> $(TARGET_DIR)/usr/lib/expressatt/nv-fwconfig.bin
	chmod 0644 $(TARGET_DIR)/usr/lib/expressatt/nv-fwconfig.bin
endef

$(eval $(generic-package))
