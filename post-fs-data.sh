#!/system/bin/sh
SELF_PATH="$(readlink -f "$0" 2>/dev/null)"
[ -n "$SELF_PATH" ] || SELF_PATH="$0"
case "$SELF_PATH" in
    /*) ;;
    *) SELF_PATH="$(pwd)/$SELF_PATH" ;;
esac
SCRIPT_DIR=${SELF_PATH%/*}
MODDIR=${SCRIPT_DIR}

XML_PATH="/odm/etc/audio/audio_lowpower_app_list.xml"
MAGISK_BIND_PATH="${MODDIR}/$(basename "$XML_PATH")"
KSU_OVERLAY_PATH="${MODDIR}/system${XML_PATH}"
LOG_FILE="${MODDIR}/service_hider.log"

log_msg() {
    printf '%s\n' "[HyperPatch][ClearVolume] $1" >> "$LOG_FILE" 2>/dev/null
}

wait_for_xml_path() {
    count=0
    while [ "$count" -lt 60 ] && [ ! -f "$XML_PATH" ]; do
        sleep 1
        count=$((count + 1))
    done
}

prepare_clean_volume_xml() {
    wait_for_xml_path
    [ -f "$XML_PATH" ] || return 0
    if [ "$KSU" ] || [ "$APATCH" ]; then
        mkdir -p "$(dirname "$KSU_OVERLAY_PATH")" 2>/dev/null
        if [ ! -f "$KSU_OVERLAY_PATH" ] || [ "$XML_PATH" -nt "$KSU_OVERLAY_PATH" ]; then
            log_msg "Generating cleaned XML at ${KSU_OVERLAY_PATH}"
            sed '/<package name=/d' "$XML_PATH" > "$KSU_OVERLAY_PATH" 2>/dev/null
            chcon --reference="$XML_PATH" "$KSU_OVERLAY_PATH" 2>/dev/null
            chmod 0644 "$KSU_OVERLAY_PATH" 2>/dev/null
        fi
        if [ -f "$KSU_OVERLAY_PATH" ]; then
            log_msg "Binding cleaned XML to ${XML_PATH}"
            mount --bind "$KSU_OVERLAY_PATH" "$XML_PATH" 2>/dev/null
        fi
        return 0
    fi

    mkdir -p "$(dirname "$MAGISK_BIND_PATH")" 2>/dev/null
    if [ ! -f "$MAGISK_BIND_PATH" ] || [ "$XML_PATH" -nt "$MAGISK_BIND_PATH" ]; then
        log_msg "Generating cleaned XML at ${MAGISK_BIND_PATH}"
        sed '/<package name=/d' "$XML_PATH" > "$MAGISK_BIND_PATH" 2>/dev/null
        chcon --reference="$XML_PATH" "$MAGISK_BIND_PATH" 2>/dev/null
        chmod 0644 "$MAGISK_BIND_PATH" 2>/dev/null
    fi

    if [ -f "$MAGISK_BIND_PATH" ]; then
        log_msg "Binding cleaned XML to ${XML_PATH}"
        mount --bind "$MAGISK_BIND_PATH" "$XML_PATH" 2>/dev/null
    fi
}

log_msg "Boot hook started"
prepare_clean_volume_xml
log_msg "Boot hook finished"
"${MODDIR}/bin/service_hider_lifecycle" post-fs-data
