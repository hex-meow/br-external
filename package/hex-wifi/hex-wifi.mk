################################################################################
#
# hex-wifi
#
################################################################################

# Public standalone repository. Keep the full commit SHA for reproducible
# images. During local development, point HEX_WIFI_OVERRIDE_SRCDIR at the
# sibling checkout from Buildroot local.mk.
HEX_WIFI_VERSION = 997a8767c4deebb8119dd858e44c38f50e6b6ee8
HEX_WIFI_SITE = $(call github,hex-meow,hex-wifi,$(HEX_WIFI_VERSION))
HEX_WIFI_LICENSE = MIT
HEX_WIFI_LICENSE_FILES = LICENSE
HEX_WIFI_DEPENDENCIES = wpa_supplicant zenohd
HEX_WIFI_OVERRIDE_SRCDIR_RSYNC_EXCLUSIONS = --exclude target

# Release tarballs are vendored by cargo-package. A local OVERRIDE_SRCDIR is
# intentionally not vendored, so omit the infrastructure's --offline flag and
# let Cargo populate Buildroot's shared download cache during development.
define HEX_WIFI_BUILD_CMDS
	cd $(HEX_WIFI_SRCDIR) && \
	$(TARGET_MAKE_ENV) $(TARGET_CONFIGURE_OPTS) $(PKG_CARGO_ENV) \
		cargo build --release --manifest-path Cargo.toml --locked
endef

define HEX_WIFI_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 \
		$(HEX_WIFI_SRCDIR)/target/$(RUSTC_TARGET_NAME)/release/hex-wifi \
		$(TARGET_DIR)/usr/bin/hex-wifi
endef

$(eval $(cargo-package))
