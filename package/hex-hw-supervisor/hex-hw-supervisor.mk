################################################################################
#
# hex-hw-supervisor
#
################################################################################

# 独立公开仓(x64 产品线也从那里消费,不经 buildroot);按全 SHA 钉死,同 hex-robot-proto。
# 本机开发:buildroot local.mk 里 HEX_HW_SUPERVISOR_OVERRIDE_SRCDIR 指向本地仓。
HEX_HW_SUPERVISOR_VERSION = 238d626a2fc4ae78544fbc2331de16665d335690
HEX_HW_SUPERVISOR_SITE = $(call github,hex-meow,hex-hw-supervisor,$(HEX_HW_SUPERVISOR_VERSION))
HEX_HW_SUPERVISOR_DEPENDENCIES = hex-robot-proto host-rustc
# override-srcdir 的 rsync 排除 target/(开发机构建产物,可能数 GB)。
HEX_HW_SUPERVISOR_OVERRIDE_SRCDIR_RSYNC_EXCLUSIONS = --exclude target

# proto 从 staging 里按 SHA 钉住的副本取(见 package/hex-robot-proto)。
HEX_HW_SUPERVISOR_CARGO_ENV = \
	HEX_ROBOT_PROTO_DIR=$(STAGING_DIR)/usr/share/hex-robot-proto

# 自定义 BUILD/INSTALL:去掉默认命令的 --offline —— tarball 路径(CI)下载期已 vendor,
# 有无 --offline 都走 vendor 目录;OVERRIDE_SRCDIR 路径(本机开发)未 vendor,需允许
# cargo 用 $(DL_DIR)/br-cargo-home 缓存/联网。--locked 保留:Cargo.lock 已提交。
define HEX_HW_SUPERVISOR_BUILD_CMDS
	cd $(HEX_HW_SUPERVISOR_SRCDIR) && \
	$(TARGET_MAKE_ENV) $(TARGET_CONFIGURE_OPTS) $(PKG_CARGO_ENV) \
		$(HEX_HW_SUPERVISOR_CARGO_ENV) \
		cargo build --release --manifest-path Cargo.toml --locked
endef

define HEX_HW_SUPERVISOR_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 \
		$(HEX_HW_SUPERVISOR_SRCDIR)/target/$(RUSTC_TARGET_NAME)/release/hex-hw-supervisor \
		$(TARGET_DIR)/usr/bin/hex-hw-supervisor
endef

$(eval $(cargo-package))
