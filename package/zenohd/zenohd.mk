################################################################################
#
# zenohd
#
################################################################################

ZENOHD_VERSION = 1.9.0
ZENOHD_SITE = $(call github,eclipse-zenoh,zenoh,$(ZENOHD_VERSION))
# zenohd is a member of the zenoh cargo workspace; build/install just it.
ZENOHD_SUBDIR = zenohd
ZENOHD_LICENSE = EPL-2.0 or Apache-2.0
ZENOHD_LICENSE_FILES = LICENSE

# Keep the version pinned in ONE place: the launcher/controller bundle links the
# zenoh client lib at the same minor (wire-compat); bump both together
# (see robot-overall-design/09 §10 "zenoh 版本单一事实源").

$(eval $(cargo-package))
