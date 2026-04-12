#!/system/bin/sh
MODDIR="${0%/*}"

# 等待安卓系统启动完成
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 10
done

# 如果系统隐藏服务脚本存在 则通知该模块开始初始化服务
if [ -x "${MODDIR}/bin/service_hider_lifecycle" ]; then
    SERVICE_HIDER_BOOT_READY=1 "${MODDIR}/bin/service_hider_lifecycle" service
fi

# 当 UDC 报告 USB 数据主机已连接时返回 0
get_usb_connected() {
    for state_file in /sys/class/udc/*/state; do
        [ -f "$state_file" ] || continue
        state_val="$(cat "$state_file" 2>/dev/null)"
        case "$state_val" in
            configured|addressed|connected)
                return 0
                ;;
        esac
    done
    return 1
}

# 为所有 UDC 状态文件构建以空格分隔的 file:cew0 监视规范列表
collect_udc_state_files() {
    UDC_STATE_FILES=""
    for state_file in /sys/class/udc/*/state; do
        [ -f "$state_file" ] || continue
        UDC_STATE_FILES="${UDC_STATE_FILES} ${state_file}"
    done
    [ -n "$UDC_STATE_FILES" ]
}

# 更改全局 ADB 状态并重启 adbd 服务以应用新配置
set_adb_state() {
    # 期望预填 current adbd_state sys_usb_config
    if [ "$1" = "1" ]; then
        [ "$current" = "1" ] || settings put global adb_enabled 1

        config_changed=0
        if ! printf '%s' "$sys_usb_config" | grep -q 'adb'; then
            if [ -n "$sys_usb_config" ] && [ "$sys_usb_config" != "none" ]; then
                new_config="${sys_usb_config},adb"
            else
                new_config="mtp,adb"
            fi
            setprop persist.sys.usb.config "$new_config"
            setprop sys.usb.config "$new_config"
            config_changed=1
        fi

        if [ "$adbd_state" != "running" ]; then
            setprop ctl.start adbd
        elif [ "$config_changed" = "1" ]; then
            setprop ctl.restart adbd
        fi

        last_adb_state="1"
        echo "Auto-ADB: PC Connected, enabling..."
    else
        [ "$current" = "0" ] || settings put global adb_enabled 0

        if printf '%s' "$sys_usb_config" | grep -q 'adb'; then
            # 安全地剥离 adb 以保留现有的网络共享或 MIDI 模式
            new_config="$(printf '%s' "$sys_usb_config" | sed 's/,adb//; s/adb,//; s/adb/mtp/')"
            [ -z "$new_config" ] && new_config="mtp"
            
            setprop persist.sys.usb.config "$new_config"
            setprop sys.usb.config "$new_config"
        fi

        [ "$adbd_state" = "stopped" ] || setprop ctl.stop adbd

        last_adb_state="0"
        echo "Auto-ADB: PC Disconnected, disabling..."
    fi
}

# 仅在 USB 连接状态改变时应用预期的 ADB 状态
reconcile_state() {
    if get_usb_connected; then
        usb_state=1
        desired=1
    else
        usb_state=0
        desired=0
    fi

    [ "$usb_state" = "$last_usb_state" ] && return

    current="$(settings get global adb_enabled 2>/dev/null)"
    adbd_state="$(getprop init.svc.adbd 2>/dev/null)"
    sys_usb_config="$(getprop sys.usb.config 2>/dev/null)"

    runtime_ok=0
    if [ "$desired" = "1" ]; then
        if [ "$current" = "1" ] && [ "$adbd_state" = "running" ] && printf '%s' "$sys_usb_config" | grep -q 'adb'; then
            runtime_ok=1
        fi
    else
        if [ "$current" = "0" ] && [ "$adbd_state" = "stopped" ] && ! printf '%s' "$sys_usb_config" | grep -q 'adb'; then
            runtime_ok=1
        fi
    fi

    if [ "$runtime_ok" = "1" ]; then
        last_adb_state="$current"
        last_usb_state="$usb_state"
        return
    fi

    if [ "$last_adb_state" != "$desired" ] || [ "$current" != "$desired" ]; then
        set_adb_state "$desired"
    fi

    last_usb_state="$usb_state"
}

# 启动 inotifyd 事件循环监听 USB 状态变化
event_loop_inotifyd() {
    reconcile_state

    while true; do
        if ! collect_udc_state_files; then
            sleep 2
            continue
        fi

        watch_specs=""
        for state_file in $UDC_STATE_FILES; do
            watch_specs="${watch_specs} ${state_file}:cew0"
        done

        # shellcheck disable=SC2086
        inotifyd - $watch_specs 2>/dev/null | while IFS= read -r _line; do
            if get_usb_connected; then
                current_usb=1
            else
                current_usb=0
            fi

            if [ "$current_usb" != "$last_usb_state" ]; then
                sleep 2
                reconcile_state
            fi
        done

        sleep 1
    done
}

# 追踪最后观察到的 USB 状态以避免不必要的工作
last_usb_state="-1"
last_adb_state="$(settings get global adb_enabled 2>/dev/null)"

# 检测系统对文件事件监听的支持程度 若完整支持则进入主循环分支 否则提示不可用
if command -v inotifyd >/dev/null 2>&1; then
    event_loop_inotifyd
else
    echo "Auto-ADB: inotifyd not found; watcher disabled."
fi