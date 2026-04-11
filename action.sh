MODDIR="${0%/*}"
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

    if command -v stat >/dev/null 2>&1; then
        out="$(stat -c "%Y:%s" "$target" 2>/dev/null)"
        if [ -n "$out" ]; then
            echo "$out"
            return
        fi
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
echo "Tip: Plug into PC with data cable to verify adbd logic."
echo "adb_enabled=$(settings get global adb_enabled 2>/dev/null || echo "unknown")"
echo "adbd_service=$(getprop init.svc.adbd 2>/dev/null)"
echo "sys.usb.config=$(getprop sys.usb.config 2>/dev/null)"
echo "pers.usb.config=$(getprop persist.sys.usb.config 2>/dev/null)"
echo "device=$(getprop ro.product.device 2>/dev/null)"
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
    wpid="$(cat "$WATCHER_PID_FILE" 2>/dev/null)"
    kill -0 "$wpid" 2>/dev/null && echo "watcher_process=running (pid=$wpid)" || echo "watcher_process=stale"
else
    echo "watcher_process=not-tracked"
fi

echo
echo "[Clear Volume Level Blacklist]"
module_xml=""
[ -f "$KSU_OVERLAY_PATH" ] && module_xml="$KSU_OVERLAY_PATH" || module_xml="$MAGISK_BIND_PATH"

echo "system_xml=$XML_PATH"
if [ -f "$module_xml" ] && [ -f "$XML_PATH" ]; then
    cmp -s "$module_xml" "$XML_PATH" && match=1 || match=0
    echo "xml_match=$match"
    echo "module_sig=$(file_sig "$module_xml")"
    echo "system_sig=$(file_sig "$XML_PATH")"
else
    echo "xml_match=not-found"
fi

echo
echo "Done. Keeping output visible for 10 seconds..."
sleep 10
