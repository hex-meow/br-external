################################################################################
#
# hex-hw-supervisor
#
################################################################################

# 源码就在本 BR2_EXTERNAL 树内(fork 一个仓库拿到完整可跑的开源 HAL)。
HEX_HW_SUPERVISOR_VERSION = 0.1.0
HEX_HW_SUPERVISOR_SITE = $(BR2_EXTERNAL_HEX_EMBEDDED_PATH)/hex-hw-supervisor
HEX_HW_SUPERVISOR_SITE_METHOD = local
HEX_HW_SUPERVISOR_DEPENDENCIES = hex-robot-proto host-rustc
# 本地源码 rsync 进构建目录时排除 target/(开发机的构建产物,可能数 GB)。
HEX_HW_SUPERVISOR_OVERRIDE_SRCDIR_RSYNC_EXCLUSIONS = --exclude target

# proto 从 staging 里按 SHA 钉住的副本取(见 package/hex-robot-proto)。
HEX_HW_SUPERVISOR_CARGO_ENV = \
	HEX_ROBOT_PROTO_DIR=$(STAGING_DIR)/usr/share/hex-robot-proto

# 自定义 BUILD/INSTALL:cargo-package 的默认命令带 --offline,只适用于「下载期已 vendor」
# 的 tarball 源;本地(SITE_METHOD=local)源码不经下载后处理,依赖需联网取一次
# (缓存在 $(DL_DIR)/br-cargo-home,后续构建命中缓存)。--locked 保留:Cargo.lock 已提交。
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
