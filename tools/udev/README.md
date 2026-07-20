# Rockchip RK3576 udev access

`70-rockchip-rk3576.rules` lets the locally logged-in developer use Rockchip's
`upgrade_tool` without `sudo` while the RK3576 is in Loader or Maskrom mode.

The rule is intentionally narrower than Rockchip's generic development rule:

- it matches the RK3576 rockusb ID observed on this board (`2207:350e`);
- it grants read/write access only to the active desktop user (`uaccess`) and
  members of `plugdev`;
- it uses mode `0660`, rather than making the device writable by every user.

The `70-` prefix is significant. It places the tag before systemd's
`73-seat-late.rules`, where the `uaccess` ACL is applied.

## Install

```sh
sudo install -D -m 0644 \
  tools/udev/70-rockchip-rk3576.rules \
  /etc/udev/rules.d/70-rockchip-rk3576.rules
sudo udevadm control --reload-rules
```

Re-enter Loader mode or reconnect the USB cable after installing the rule. To
reapply it to an already connected board, trigger the board's USB device sysfs
path, for example:

```sh
sudo udevadm trigger --action=add /sys/bus/usb/devices/2-1
```

The path is host-port dependent; obtain it from `udevadm info` or reconnect the
board instead of copying the example blindly.

## Verify

The commands below must work as the normal user:

```sh
cd /path/to/upgrade_tool_v2.55_for_linux
./upgrade_tool LD
./upgrade_tool PL
./upgrade_tool DI -rootfs /path/to/rootfs.ext2
./upgrade_tool RD
```

On this tool version, `DI -rootfs` is the correct named-partition form. `DI -r`
means the `recovery` partition and must not be used for the root filesystem.

The upstream Rockchip `rkdeveloptool` repository carries a generic reference
rule for Rockchip vendor ID `2207`:
<https://github.com/rockchip-linux/rkdeveloptool/blob/master/99-rk-rockusb.rules>.
