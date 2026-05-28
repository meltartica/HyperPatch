#!/system/bin/sh
MODDIR="${0%/*}"

# 等待安卓系统启动完成
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 10
done

# 开机 60 秒后强制停止小米互联通信服务，以避免 NFC 超时导致贴贴分享不可用
kill_mi_connect_service() {
    sleep 60
    am force-stop "com.xiaomi.mi_connect_service" >/dev/null 2>&1
}
kill_mi_connect_service &

# 当 UDC 报告 USB 数据主机已连接时返回 0
get_usb_connected() {
    [ -f "$CANON_UDC_STATE" ] || return 1

    if IFS= read -r state_val < "$CANON_UDC_STATE"; then
        case "$state_val" in
            configured|addressed|connected)
                return 0
                ;;
        esac
    fi

    return 1
}

# 解析单个规范 UDC 状态文件用于事件监听与状态读取
resolve_canonical_udc_state() {
    CANON_UDC_STATE=""
    for state_file in /sys/class/udc/*/state; do
        if [ -f "$state_file" ]; then
            CANON_UDC_STATE="$state_file"
            break
        fi
    done

    [ -n "$CANON_UDC_STATE" ]
}

# 更改全局 ADB 状态并重启 adbd 服务以应用新配置
set_adb_state() {
    if [ "$1" = "1" ]; then
        [ "$current" = "1" ] || settings put global adb_enabled 1

        if [ "$adbd_state" != "running" ]; then
            setprop ctl.start adbd
        else
            setprop ctl.restart adbd
        fi

        last_adb_state="1"
        echo "Auto-ADB: PC Connected, enabling..."
    else
        [ "$current" = "0" ] || settings put global adb_enabled 0

        [ "$adbd_state" = "stopped" ] || setprop ctl.stop adbd

        last_adb_state="0"
        echo "Auto-ADB: PC Disconnected, disabling..."
    fi
}

# 仅在 USB 连接状态改变时应用预期的 ADB 状态
reconcile_state() {
    # 切换 ADB 状态会触发 USB 重新枚举，枚举期间 UDC 状态会抖动
    # 在冷却期内跳过处理，避免启用→禁用→启用的乒乓循环
    now_epoch=$(date +%s 2>/dev/null || cat /proc/uptime | cut -d' ' -f1 | cut -d'.' -f1)
    elapsed=$(( now_epoch - last_switch_epoch ))
    [ "$elapsed" -lt 8 ] 2>/dev/null && return

    if get_usb_connected; then
        usb_state=1
        desired=1
    else
        usb_state=0
        desired=0
    fi

    [ "$usb_state" = "$last_usb_state" ] && return

    # USB 状态在插拔瞬间可能抖动，二次确认后再执行切换
    sleep 1
    if get_usb_connected; then
        confirmed_usb_state=1
    else
        confirmed_usb_state=0
    fi
    [ "$confirmed_usb_state" = "$usb_state" ] || return

    current="$(settings get global adb_enabled 2>/dev/null)"
    adbd_state="$(getprop init.svc.adbd 2>/dev/null)"

    runtime_ok=0
    if [ "$desired" = "1" ]; then
        if [ "$current" = "1" ] && [ "$adbd_state" = "running" ]; then
            runtime_ok=1
        fi
    else
        if [ "$current" = "0" ] && [ "$adbd_state" = "stopped" ]; then
            runtime_ok=1
        fi
    fi

    if [ "$runtime_ok" = "1" ]; then
        last_adb_state="$current"
        last_usb_state="$usb_state"
        return
    fi

    if [ "$last_adb_state" != "$desired" ] || [ "$current" != "$desired" ]; then
        last_switch_epoch=$(date +%s 2>/dev/null || cat /proc/uptime | cut -d' ' -f1 | cut -d'.' -f1)
        set_adb_state "$desired"
    fi

    last_usb_state="$usb_state"
}

# 启动 inotifyd 事件循环监听 USB 状态变化
event_loop_inotifyd() {
    if ! resolve_canonical_udc_state; then
        echo "Auto-ADB: no UDC state file found; watcher disabled."
        return
    fi

    reconcile_state

    while true; do
        inotifyd - "${CANON_UDC_STATE}:cew0" 2>/dev/null | while IFS= read -r _line; do
            sleep 2
            reconcile_state
        done

        # 仅当 inotifyd 退出时才重启，避免健康状态下的周期性唤醒
        sleep 2

        # UDC 节点可能在极少数场景重建，退出后重新解析一次
        if ! resolve_canonical_udc_state; then
            echo "Auto-ADB: UDC state file disappeared; watcher disabled."
            return
        fi
    done
}

# 追踪最后观察到的 USB 状态以避免不必要的工作
CANON_UDC_STATE=""
last_usb_state="-1"
last_adb_state="$(settings get global adb_enabled 2>/dev/null)"
# 上次切换 ADB 状态的时间戳，用于在 USB 重新枚举期间忽略抖动
last_switch_epoch=0

# 检测系统对文件事件监听的支持程度 若完整支持则进入主循环分支 否则提示不可用
if command -v inotifyd >/dev/null 2>&1; then
    event_loop_inotifyd
else
    echo "Auto-ADB: inotifyd not found; watcher disabled."
fi