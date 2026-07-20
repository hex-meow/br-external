#!/bin/sh
# zenohd 的 LAN 面(组播加组 + scout hello 的 locator 列表)在【启动时】固定 —— 板上实测:
# 运行期新增地址不会进 hello(缓存),开机早于网络则加组失败。本监视器把它统一收口:
# 快照 zenohd 每次启动时 end0/wlan0 的 carrier 状态与 IPv4/IPv6 地址集,之后清单一旦变化
# (插线/换网/换租约/IPv4LL fallback)且稳定两个周期,就 try-restart zenohd 一次 ——
# 本地 client 全部无限重连(实证),只有短暂断流。监听 socket 虽绑定 any address,
# 但 scout hello 的 locator 列表仍需刷新。
# 设计:robot-overall-design/09 §3。
snapshot() {
    for IFACE in end0 wlan0; do
        STATE=$(cat "/sys/class/net/$IFACE/operstate" 2>/dev/null || echo missing)
        V4=$(ip -4 addr show "$IFACE" 2>/dev/null | grep -o 'inet [0-9.]*' | sort | tr '\n' ',')
        V6=$(ip -6 addr show "$IFACE" 2>/dev/null | grep -o 'inet6 [0-9a-fA-F:]*' | sort | tr '\n' ',')
        printf '%s:state:%s|v4:%s|v6:%s;' "$IFACE" "$STATE" "$V4" "$V6"
    done
    echo
}

PREV_INV=""
BASE=""
while true; do
    INV=$(systemctl show -p InvocationID --value zenohd 2>/dev/null)
    CUR=$(snapshot)
    if [ "$INV" != "$PREV_INV" ]; then
        # zenohd(重)启动 → 以当下地址集为基准
        PREV_INV="$INV"
        BASE="$CUR"
    fi
    if [ "$CUR" != "$BASE" ]; then
        sleep 3
        CUR2=$(snapshot)
        if [ "$CUR2" = "$CUR" ]; then
            echo "LAN 网络清单变化: [$BASE] -> [$CUR],重启 zenohd 以刷新组播/locator"
            systemctl try-restart zenohd
        fi
    fi
    sleep 3
done
