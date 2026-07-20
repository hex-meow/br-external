# hex-wifi 设计

状态：v2 已确认方向。

## 1. 已确认的产品边界

- 公共镜像和私有镜像使用同一套 Wi-Fi 后端、持久化格式与远程 API。
- `hex-wifi` 使用 Rust，实现为公共组件；私有 `hex-controller` 只是它的调用方。
- 设备插入 Windows、Linux 或 macOS 电脑的空闲网口后，在没有 DHCP Server 的情况下也应可发现和配置。
- 本地 SSH/串口必须始终保留一条不依赖 Zenoh 的恢复路径。
- 第一版不引入 NetworkManager、ConnMan、网页、蓝牙或 SoftAP 配网。
- 第一版以 WPA2-Personal 为基线；WPA3/SAE 在 RTL8821CS 真机验证后再启用。
- 当前不要求 Secure Boot、rootfs 防篡改或 Wi-Fi 凭据的硬件加密存储。

## 2. 有线直连 bootstrap

### 2.1 为什么同时使用 IPv6 link-local 和 IPv4LL

IPv6 link-local (`fe80::/10`) 是 IPv6 的标准组成部分。没有路由器、RA 或 DHCPv6
时，同一链路上的两个节点仍可使用它通信。IPv4 的对应机制是 RFC 3927 IPv4
Link-Local (`169.254.0.0/16`)。

产品不在两者之间二选一，而是显式启用双栈 link-local：

```ini
[Network]
DHCP=ipv4
LinkLocalAddressing=yes
```

在 systemd-networkd 中，`yes` 同时启用 IPv6 link-local 和 IPv4LL：

- IPv6 link-local 在接口启用后生成，不需要 DHCP。
- IPv4 先尝试 DHCP；一段时间没有服务器时，自动选择并冲突检测一个
  `169.254.x.y` 地址，同时继续尝试 DHCP。
- 获得正常 DHCP 地址时，正常地址优先；link-local 不提供默认路由，也不会影响
  PC 原有 Wi-Fi 上网路径。
- 不能写成 `LinkLocalAddressing=ipv4`，因为那会关闭 networkd 对 IPv6 link-local
  的配置。

参考：

- <https://www.rfc-editor.org/rfc/rfc4862.html>
- <https://www.rfc-editor.org/rfc/rfc3927.html>
- <https://github.com/systemd/systemd/blob/main/man/systemd.network.xml>

### 2.2 Zenoh 的现实约束

Zenoh 1.9 默认 multicast scouting 地址仍是 IPv4
`224.0.0.224:7446`，所以“PC 有 IPv6”本身并不能保证默认 Zenoh 客户端通过 IPv6
自动发现 router。IPv4LL 让默认 scouting 在无 DHCP 的直连链路上继续工作。

`zenohd` 使用单个双栈监听端点：

```json5
listen: { endpoints: ["tcp/[::]:7447"] }
```

在目标 Linux 保持默认 `net.ipv6.bindv6only=0` 的前提下，该 socket 同时接受 IPv4
和 IPv6。IPv6 link-local 因为具有 zone/scope，使用裸 `fe80::` 地址手工连接时还必须
带接口标识；正常产品流程优先让 Zenoh scouting 处理定位。

### 2.3 跨平台承诺

- Windows 默认 DHCP 失败后支持 APIPA (`169.254/16`)；IPv6 link-local 也默认存在。
- macOS 长期支持 IPv4LL，并默认启用 IPv6 link-local。
- Linux 协议栈支持两者，但发行版网络管理器和管理员策略可能禁用 IPv4LL、IPv6
  或组播，不能仅凭“Linux”保证 99%。新版 NetworkManager 可以显式配置 IPv4LL
  fallback。
- 产品验收必须覆盖当前受支持的 Windows、macOS 和至少两个主流 Linux 桌面环境；
  USB 串口继续作为极端网络策略下的恢复通道。

## 3. 仓库归属

`hex-wifi` 源码建议放在独立的公共仓库 `hex-meow/hex-wifi`，本仓库只保留
Buildroot 集成、systemd/networkd 文件和精确版本 pin。

理由：

- 它已经是一个带 Zenoh API、持久化契约和独立测试的用户态服务，不再是几十行的
  board overlay helper。
- 可以在普通 x86 Linux 上用 mock backend 跑 Cargo CI，不需要每次构建整个 rootfs。
- API/配置格式可以独立发版，Buildroot 镜像仍通过完整 commit SHA 获得可复现构建。
- 与现有 `hex-hw-supervisor` 的独立公共仓库模式一致。

本仓库最终增加：

```text
package/hex-wifi/Config.in
package/hex-wifi/hex-wifi.mk
overlay/usr/lib/systemd/system/wpa_supplicant-wlan0.service
overlay/usr/lib/systemd/system/hex-wifi.service
overlay/usr/lib/systemd/network/20-wlan0.network
```

## 4. 运行时架构

```text
Windows/Linux/macOS GUI
          │ Zenoh query/reply
          ▼
      zenohd (唯一 LAN listener / ACL 强制点)
          │ localhost client session
          ▼
      hex-wifi daemon ───────────────┐
          ▲                          │ Unix control socket
          │ /run/hex-wifi.sock       ▼
  hex-wifi CLI                 wpa_supplicant
   (SSH/串口)                       │
                              systemd-networkd
```

职责边界：

- `wpa_supplicant` 管理关联、认证和网络条目。
- `systemd-networkd` 在 `wlan0` carrier 建立后管理 IP、路由和 DNS。
- `hex-wifi daemon` 串行化修改、提供本地 Unix socket 和 Zenoh queryable、执行验证与
  日志脱敏。
- `hex-wifi CLI` 只通过 Unix socket 调 daemon；daemon/Zenoh 故障时仍可从串口诊断，
  并提供受限的离线恢复命令。
- 私有 `hex-controller` 不生成 `wpa_supplicant.conf`，也不直接调用 `wpa_cli`。

`hex-wifi` 以 Zenoh client 模式显式连接 `tcp/127.0.0.1:7447`，关闭自身 listener 和
scouting，确保所有 LAN 流量都经过 `zenohd` ACL。

## 5. Rust 实现边界

第一版使用一个 crate、一个 binary，binary 提供 `daemon` 和 CLI 子命令。内部至少拆成：

```text
backend/       wpa_supplicant control socket；trait 可被 mock
config/        输入校验、持久化事务、脱敏类型
local_api/     Unix socket request/reply
zenoh_api/     queryable 与 wire schema
main.rs        daemon / CLI 命令分发
```

优先直接实现 wpa_supplicant Unix datagram control protocol，或采用经过审计、维护状态
明确的 Rust crate；不通过 shell 或 `wpa_cli` 传递密码。当前镜像虽启用了 D-Bus，但
第一版不依赖它，以减少 service 启动参数和额外 API 面。

密码类型不实现 `Debug`/`Display`；日志、错误链、JSON response 和 tracing fields 均不得
包含控制命令原文。

## 6. 持久化与 systemd

```text
/userdata/hexmeow/wifi/                         0700 root:root
/userdata/hexmeow/wifi/wpa_supplicant.conf     0600 root:root
/run/wpa_supplicant/wlan0                      supplicant control socket
/run/hex-wifi.sock                             local management API
```

拆分两个 unit：

- `wpa_supplicant-wlan0.service`：等待 `userdata.mount` 和 `wlan0`，启动 supplicant。
- `hex-wifi.service`：等待 supplicant control socket 和 `zenohd.service`，运行 Rust daemon。

初始 supplicant 配置不包含默认开放网络：

```ini
ctrl_interface=/run/wpa_supplicant
update_config=1
```

`20-wlan0.network` 第一版使用 DHCPv4，并设置 `RequiredForOnline=no`，Wi-Fi 连接失败不能
阻塞系统启动。

## 7. API 契约

建议的 Zenoh queryables：

```text
hexmeow/<cid>/wifi/status
hexmeow/<cid>/wifi/scan
hexmeow/<cid>/wifi/networks
hexmeow/<cid>/wifi/jobs/<job_id>
hexmeow/<cid>/rpc/wifi/validate
hexmeow/<cid>/rpc/wifi/set
hexmeow/<cid>/rpc/wifi/forget
hexmeow/<cid>/rpc/wifi/forget_all
```

要求：

- 使用 query/reply，不用 pub/sub 写配置；每次修改都有明确成功或错误响应。
- `status`、`scan`、`networks` 和错误响应永不返回 PSK/passphrase。
- `set` 中的 passphrase 是 write-only 字段，不进入 journal。
- `hex-wifi` 与专用 wpa_supplicant unit 禁止 core dump，避免崩溃镜像保存凭据。
- SSID 以 1–32 字节处理；文本入口默认 UTF-8，但 wire schema 应能明确承载任意 SSID
  字节，避免字符串转义导致配置注入。
- WPA2 passphrase 限制为 8–63 字节；64 位十六进制原始 PSK 必须是独立显式类型。
- 修改带 `request_id` 和配置 revision，避免 GUI 重试或多个客户端互相覆盖。

换网可能切断发起请求的 Wi-Fi 链路，因此 `set/forget/forget_all` 采用异步 job：
先返回 `job_id/accepted`，再应用；客户端通过 `wifi/jobs/<job_id>` 查询结果。
同一 `request_id` 重试返回原 job，同时只允许一个修改 job 活跃。第一版从 `end0`
配网时链路不受影响，仍应保留失败超时和 last-known-good 回滚设计。

本地 CLI 对应提供：

```text
hex-wifi status [--json]
hex-wifi scan [--json]
hex-wifi list [--json]
hex-wifi set --ssid SSID --passphrase-stdin [--country XX] [--wait SECONDS]
hex-wifi forget --ssid SSID
hex-wifi forget-all
```

不提供 `--password VALUE`，也不从环境变量读取密码。

## 8. 第一版网络安全边界

当前 `zenohd` 是明文 TCP 且 ACL 为 default-allow。落地 Wi-Fi RPC 时：

- `status/scan/networks/jobs` 可以从 `end0`、`wlan0` 读取。
- 在没有客户端认证前，`validate/set/forget/forget_all` 默认只允许从 `end0`
  进入；本机 Unix socket 不受 LAN ACL 影响。
- 以后需要通过 Wi-Fi 远程修改时，启用 TLS；需要身份授权时启用 mTLS，并使用证书
  身份匹配 ACL。
- 启用 TLS 后必须同时禁止普通 TCP transport/scouting fallback，不能只增加一个 TLS
  listener 后仍保留明文旁路。

## 9. 修改事务

每次修改由 daemon 串行执行：

1. 校验 country、SSID、passphrase 和请求 revision。
2. 在 wpa_supplicant 中创建完整但尚未启用的新 network entry。
3. 保存“旧配置 + 禁用 candidate”；失败则撤销 candidate，旧配置不动。
4. select candidate 并等待关联；超时恢复 last-known-good entry。
5. 关联成功后，先原子写入并 fsync 新 revision，再开始删除旧 entry。
6. enable candidate、保存最终配置并更新 job 状态。

`set` 在新 entry 完整配置前不得删除当前可用配置。错误密码不能破坏有线网络或 USB
串口恢复路径。revision 落盘之后、最终配置落盘之前掉电时，重启会得到旧的
last-known-good 配置和一个跳号后的 revision；这种保守跳号优于“新配置配旧 revision”。
`forget/forget_all` 同样先持久化 revision 再做破坏性操作，失败时 RECONFIGURE 回到
磁盘上的旧配置。
