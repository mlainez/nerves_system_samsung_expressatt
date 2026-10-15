EXPRESSATT_FIRMWARE_VERSION = 1
EXPRESSATT_FIRMWARE_SITE = $(NERVES_DEFCONFIG_DIR)/firmware
EXPRESSATT_FIRMWARE_SITE_METHOD = local
EXPRESSATT_FIRMWARE_LICENSE = Proprietary
EXPRESSATT_FIRMWARE_REDISTRIBUTE = NO

define EXPRESSATT_FIRMWARE_INSTALL_TARGET_CMDS
	cd $(@D) && sha256sum -c SHA256SUMS
	$(INSTALL) -d $(TARGET_DIR)/lib/firmware/wlan/prima
	$(INSTALL) -m 0644 $(@D)/wcnss.mdt $(@D)/wcnss.b00 $(@D)/wcnss.b01 $(@D)/wcnss.b02 $(@D)/wcnss.b04 $(TARGET_DIR)/lib/firmware/
	$(INSTALL) -m 0644 $(@D)/wlan/prima/WCNSS_qcom_wlan_nv.bin $(TARGET_DIR)/lib/firmware/wlan/prima/
endef

$(eval $(generic-package))
