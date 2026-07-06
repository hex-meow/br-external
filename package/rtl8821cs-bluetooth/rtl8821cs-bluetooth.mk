RTL8821CS_BLUETOOTH_SITE = $(RTL8821CS_BLUETOOTH_PKGDIR)/src
RTL8821CS_BLUETOOTH_SITE_METHOD = local

RTL8821CS_BLUETOOTH_MODULE_MAKE_OPTS = CONFIG_BT_HCIUART_H4=y

$(eval $(kernel-module))

define RTL8821CS_BLUETOOTH_BUILD_CMDS
	$(MAKE) $(TARGET_CONFIGURE_OPTS) -C $(@D)/rtk_hciattach rtk_hciattach
endef

define RTL8821CS_BLUETOOTH_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0644 $(@D)/rtlbt/rtl8821c_fw $(TARGET_DIR)/lib/firmware/rtlbt/rtl8821c_fw
	$(INSTALL) -D -m 0644 $(@D)/rtlbt/rtl8821c_config $(TARGET_DIR)/lib/firmware/rtlbt/rtl8821c_config
	$(INSTALL) -D -m 0755 $(@D)/rtk_hciattach/rtk_hciattach $(TARGET_DIR)/usr/bin/rtk_hciattach
endef

$(eval $(generic-package))
