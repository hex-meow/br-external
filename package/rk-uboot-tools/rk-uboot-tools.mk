RK_UBOOT_TOOLS_SITE = https://github.com/rockchip-linux/u-boot.git
RK_UBOOT_TOOLS_SITE_METHOD = git
RK_UBOOT_TOOLS_VERSION = 2687dce2617032930f2c43fef349bdea694c6f68

HOST_RK_UBOOT_TOOLS_DEPENDENCIES = $(BR2_MAKE_HOST_DEPENDENCY) host-dtc

HOST_RK_UBOOT_TOOLS_MAKE_OPTS = HOSTCC="$(HOSTCC)" \
	HOSTCFLAGS="$(HOST_CFLAGS)" \
	HOSTLDFLAGS="$(HOST_LDFLAGS)" \
	CONFIG_FIT=y CONFIG_MKIMAGE_DTC_PATH=dtc \
	ARCH=arm

define HOST_RK_UBOOT_TOOLS_CONFIGURE_CMDS
	$(BR2_MAKE1) -C $(@D) $(HOST_UBOOT_TOOLS_MAKE_OPTS) defconfig
	echo CONFIG_RSA_N_SIZE=0 >> $(@D)/.config
	echo CONFIG_RSA_E_SIZE=0 >> $(@D)/.config
	echo CONFIG_RSA_C_SIZE=0 >> $(@D)/.config
endef

define HOST_RK_UBOOT_TOOLS_BUILD_CMDS
	$(BR2_MAKE1) -C $(@D) $(HOST_UBOOT_TOOLS_MAKE_OPTS) tools-only
endef

define HOST_RK_UBOOT_TOOLS_INSTALL_CMDS
	$(INSTALL) -m 0755 -D $(@D)/tools/mkimage $(HOST_DIR)/bin/rk-mkimage
	$(INSTALL) -m 0755 -D $(@D)/tools/mkenvimage $(HOST_DIR)/bin/rk-mkenvimage
endef

$(eval $(host-generic-package))