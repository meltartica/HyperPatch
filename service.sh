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
    # Expects $current, $adbd_state, $sys_usb_config to be pre-populated
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
            # Safely strip adb to preserve existing tethering/MIDI modes
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

# Apply desired ADB state only when USB connection state changes.
reconcile_state() {
    get_usb_connected && usb_state=1 || usb_state=0

    [ "$usb_state" = "$last_usb_state" ] && return

    current="$(settings get global adb_enabled 2>/dev/null)"
    adbd_state="$(getprop init.svc.adbd 2>/dev/null)"
    sys_usb_config="$(getprop sys.usb.config 2>/dev/null)"

    runtime_ok=0
    if [ "$usb_state" = "1" ]; then
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

    if [ "$last_adb_state" != "$usb_state" ] || [ "$current" != "$usb_state" ]; then
        set_adb_state "$usb_state"
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
            # Peek current state to avoid lag accumulation from multiple quick events
            if get_usb_connected; then
                current_usb=1
            else
                current_usb=0
            fi

            # Only delay and reconcile if the raw state differs from what we last handled
            if [ "$current_usb" != "$last_usb_state" ]; then
                # Let sysfs state settle before reconciling.
                sleep 2
                reconcile_state
            fi
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