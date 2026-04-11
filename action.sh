#!/system/bin/sh
SELF_PATH="$(readlink -f "$0" 2>/dev/null)"
[ -n "$SELF_PATH" ] || SELF_PATH="$0"
case "$SELF_PATH" in
    /*) ;;
    *) SELF_PATH="$(pwd)/$SELF_PATH" ;;
esac
SCRIPT_DIR=${SELF_PATH%/*}
MODDIR=${SCRIPT_DIR}
CTL="${MODDIR}/bin/service_hider_ctl"
WATCHER_PID_FILE="${MODDIR}/.shw.pid"
XML_PATH="/odm/etc/audio/audio_lowpower_app_list.xml"
MAGISK_BIND_PATH="${MODDIR}/$(basename "$XML_PATH")"
KSU_OVERLAY_PATH="${MODDIR}/system${XML_PATH}"

file_sig() {
    target="$1"
    if [ ! -f "$target" ]; then
        echo "missing"
        return
    fi

    if command -v cksum >/dev/null 2>&1; then
        cksum "$target" 2>/dev/null | awk '{print $1":"$2}'
        return
    fi

    wc -c < "$target" 2>/dev/null | awk '{print "size:"$1}'
}

echo "=== HyperPatch Status ==="
echo

echo "[ADB]"
echo "Tip: Plug into PC with a data cable, then check whether adbd_service changes.（提示：请用数据线连接电脑，然后查看 adbd_service 是否变化）"
adb_enabled="$(settings get global adb_enabled 2>/dev/null)"
[ -z "$adb_enabled" ] && adb_enabled="unknown"

echo "adb_enabled=$adb_enabled"
echo "adbd_service=$(getprop init.svc.adbd 2>/dev/null)"
echo "sys.usb.config=$(getprop sys.usb.config 2>/dev/null)"
echo "persist.sys.usb.config=$(getprop persist.sys.usb.config 2>/dev/null)"
echo "ro.product.device=$(getprop ro.product.device 2>/dev/null)"
echo

echo "[Hide HTTP Services]"
if [ -x "$CTL" ]; then
    sh "$CTL" status
    echo
    sh "$CTL" check
    echo
    sh "$CTL" selftest
else
    echo "service_hider_ctl missing or not executable"
fi

if [ -f "$WATCHER_PID_FILE" ]; then
    watcher_pid="$(cat "$WATCHER_PID_FILE" 2>/dev/null)"
    if [ -n "$watcher_pid" ] && kill -0 "$watcher_pid" 2>/dev/null; then
        echo "watcher_process=running (pid=$watcher_pid)"
    else
        echo "watcher_process=stale-pid-file"
    fi
else
    echo "watcher_process=not-tracked"
fi

echo
echo "[Clear Volume Level Blacklist]"
module_xml=""
if [ -f "$KSU_OVERLAY_PATH" ]; then
    module_xml="$KSU_OVERLAY_PATH"
elif [ -f "$MAGISK_BIND_PATH" ]; then
    module_xml="$MAGISK_BIND_PATH"
fi

echo "system_xml=$XML_PATH"
echo "system_xml_exists=$([ -f "$XML_PATH" ] && echo 1 || echo 0)"
if [ -n "$module_xml" ]; then
    echo "module_xml=$module_xml"
    echo "module_xml_exists=1"
else
    echo "module_xml=not-found"
    echo "module_xml_exists=0"
fi

if [ -n "$module_xml" ] && [ -f "$XML_PATH" ]; then
    if cmp -s "$module_xml" "$XML_PATH" 2>/dev/null; then
        echo "xml_match=1"
    else
        echo "xml_match=0"
    fi
    echo "module_xml_sig=$(file_sig "$module_xml")"
    echo "system_xml_sig=$(file_sig "$XML_PATH")"
else
    echo "xml_match=unknown"
fi

echo
echo "Done. Keeping output visible for 10 seconds..."
sleep 10
