################################################################################
#
# hex-robot-proto
#
################################################################################

# 公共消息契约(.proto,语言无关)。按 SHA 钉死 —— 镜像列车与 controller bundle 列车
# 的互操作契约地基(robot-overall-design/09 §4;修复 08 缺陷 #11 的镜像侧)。
# 本机开发可在 buildroot 的 local.mk 里用 HEX_ROBOT_PROTO_OVERRIDE_SRCDIR 指向本地仓。
HEX_ROBOT_PROTO_VERSION = ba7b3280b7c6e483a0d4f918a89378574ced6e9d
HEX_ROBOT_PROTO_SITE = $(call github,hex-meow,hex-robot-proto,$(HEX_ROBOT_PROTO_VERSION))
HEX_ROBOT_PROTO_LICENSE = MIT
HEX_ROBOT_PROTO_INSTALL_STAGING = YES
HEX_ROBOT_PROTO_INSTALL_TARGET = NO

# 只进 staging(给 hex-hw-supervisor 等构建期用),不进 rootfs。
define HEX_ROBOT_PROTO_INSTALL_STAGING_CMDS
	mkdir -p $(STAGING_DIR)/usr/share/hex-robot-proto
	cp -a $(@D)/proto/. $(STAGING_DIR)/usr/share/hex-robot-proto/
endef

$(eval $(generic-package))
