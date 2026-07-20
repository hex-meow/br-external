################################################################################
#
# hex-wifi
#
################################################################################

# Public standalone repository. Keep the full commit SHA for reproducible
# images. During local development, point HEX_WIFI_OVERRIDE_SRCDIR at the
# sibling checkout from Buildroot local.mk.
HEX_WIFI_VERSION = 3f57033fa7847c56b5b04716d388e793a20062f8
HEX_WIFI_SITE = $(call github,hex-meow,hex-wifi,$(HEX_WIFI_VERSION))
HEX_WIFI_LICENSE = MIT
HEX_WIFI_LICENSE_FILES = LICENSE
HEX_WIFI_OVERRIDE_SRCDIR_RSYNC_EXCLUSIONS = --exclude target

$(eval $(cargo-package))
