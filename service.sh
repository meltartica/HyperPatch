#!/system/bin/sh
SELF_PATH="$(readlink -f "$0" 2>/dev/null)"
[ -n "$SELF_PATH" ] || SELF_PATH="$0"
case "$SELF_PATH" in
    /*) ;;
    *) SELF_PATH="$(pwd)/$SELF_PATH" ;;
esac
SCRIPT_DIR=${SELF_PATH%/*}
MODDIR=${SCRIPT_DIR}

# Wait until Android has finished booting
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 10
done

if [ -x "${MODDIR}/bin/service_hider_lifecycle" ]; then
    SERVICE_HIDER_BOOT_READY=1 "${MODDIR}/bin/service_hider_lifecycle" service
fi

# Return 1 when any UDC reports "configured" (USB host connected), else 0.
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

# Build a space-separated list of /sys/class/udc/*/state files.
collect_udc_state_files() {
    UDC_STATE_FILES=""
    for state_file in /sys/class/udc/*/state; do
        [ -f "$state_file" ] || continue
        UDC_STATE_FILES="${UDC_STATE_FILES} ${state_file}"
    done
    [ -n "$UDC_STATE_FILES" ]
}

set_adb_state() {
    # $1 = 1 (enable) or 0 (disable)
    if [ "$1" = "1" ]; then
        settings put global adb_enabled 1
        setprop persist.sys.usb.config mtp,adb
        setprop sys.usb.config mtp,adb
        setprop ctl.restart adbd
        last_adb_state="1"
        echo "Auto-ADB: PC Connected, enabling..."
    else
        settings put global adb_enabled 0
        setprop persist.sys.usb.config mtp
        setprop sys.usb.config mtp
        setprop ctl.stop adbd
        last_adb_state="0"
        echo "Auto-ADB: PC Disconnected, disabling..."
    fi
}

# Apply desired ADB state only when USB connection state changes.
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

event_loop_inotifyd() {
    reconcile_state

    while true; do
        if ! collect_udc_state_files; then
            sleep 2
            continue
        fi

        # toybox inotifyd: PROG '-' streams events to stdout.
        # Watch common file change events on each UDC state file.
        watch_specs=""
        for state_file in $UDC_STATE_FILES; do
            watch_specs="${watch_specs} ${state_file}:cew0"
        done

        # shellcheck disable=SC2086
        inotifyd - $watch_specs 2>/dev/null | while IFS= read -r _line; do
            # Let sysfs state settle before reconciling.
            sleep 2
            reconcile_state
        done

        # Watcher exited (device tree changed/unwatchable/etc); restart watch set.
        sleep 1
    done
}

# Track last observed USB state to avoid unnecessary work.
last_usb_state="-1"
last_adb_state="$(settings get global adb_enabled 2>/dev/null)"

if command -v inotifyd >/dev/null 2>&1; then
    event_loop_inotifyd
else
    echo "Auto-ADB: inotifyd not found; watcher disabled."
fi