# hex-wifi M4 验收

## 自动检查

公共和私有镜像都安装只读检查器：

```sh
/usr/libexec/hex-wifi-acceptance
```

在用专用测试口令完成一次成功或失败配网后，可额外确认 journal 不含它：

```sh
HEX_WIFI_SECRET_CANARY='仅用于该次测试的口令' /usr/libexec/hex-wifi-acceptance
```

检查器不会修改 Wi-Fi，覆盖服务启用/运行状态、状态文件权限、daemon argv/environment、
core dump 限制、本地只读 API、journal canary 和原子 revision 临时文件。

## 每个候选镜像

1. 分别构建公共镜像和私有镜像。公共镜像必须有 `hex-wifi` 且没有
   `launcher/hex-controller`；私有镜像必须是其超集。
2. 记录 rootfs SHA-256，通过 `upgrade_tool DI -rootfs` 更新。
3. 更新前后记录 `hex-wifi status` 和 `hex-wifi list`；升级不得清空 userdata。
4. 在 Robot Console 点开默认隐藏的 Wi-Fi 配置，控制器选择框必须显示实际 machine-id，
   不能显示 `*`；完成 status、scan、set 和 job 终态检查。
5. 从有线 `end0` 执行 validate/set 应成功；从 `wlan0` 执行 status/scan 应成功，
   validate/set 应被 ACL 拒绝。
6. 使用错误测试口令，确认 job 失败、旧网络恢复且 revision 不倒退。
7. 运行板内自动检查器，并检查 `journalctl -b -u hex-wifi -u wpa_supplicant-wlan0`。

## 客户端平台矩阵

| 平台 | Robot Console 构建 | 有线发现/扫描 | 配置并等待 job | 当前状态 |
| --- | --- | --- | --- | --- |
| Linux | 已通过 | Zenoh 已返回实际 ID；GUI 目视复测待完成 | Zenoh 协议已通过 | 部分通过 |
| Windows | 待测 | 待测 | 待测 | 未验证 |
| macOS | 待测 | 待测 | 待测 | 未验证 |

Windows/macOS 未完成前不宣称为正式支持，只作为预期兼容平台。IPv6 link-local 和
IPv4LL 的三平台直连发现仍按 M0 的矩阵单独记录。
