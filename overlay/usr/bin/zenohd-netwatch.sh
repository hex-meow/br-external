#!/bin/sh
# zenohd 的 LAN 面(组播加组 + scout hello 的 locator 列表)在【启动时】固定 —— 板上实测:
# 运行期新增地址不会进 hello(缓存),开机早于网络则加组失败。本监视器把它统一收口:
# 快照 zenohd 每次启动时 end0 的 IPv4 集,之后地址集一旦变化(插线/换网/换租约)且稳定
# 两个周期,就 try-restart zenohd 一次 —— 本地 client 全部无限重连(实证),只有短暂断流。
# 无网线启动:快照为空,插线后第一次拿到地址即触发一次重启,LAN 发现随即可用。
# 设计:robot-overall-design/09 §3。
PREV_INV=""
BASE=""
while true; do
    INV=$(systemctl show -p InvocationID --value zenohd 2>/dev/null)
    CUR=$(ip -4 addr show end0 2>/dev/null | grep -o 'inet [0-9.]*' | sort | tr '\n' ' ')
    if [ "$INV" != "$PREV_INV" ]; then
        # zenohd(重)启动 → 以当下地址集为基准
        PREV_INV="$INV"
        BASE="$CUR"
    fi
    if [ -n "$CUR" ] && [ "$CUR" != "$BASE" ]; then
        sleep 3
        CUR2=$(ip -4 addr show end0 2>/dev/null | grep -o 'inet [0-9.]*' | sort | tr '\n' ' ')
        if [ "$CUR2" = "$CUR" ]; then
            echo "end0 地址集变化: [$BASE] -> [$CUR],重启 zenohd 以刷新组播/locator"
            systemctl try-restart zenohd
        fi
    fi
    sleep 3
done
