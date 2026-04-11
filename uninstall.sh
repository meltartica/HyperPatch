#!/system/bin/sh
SELF_PATH="$(readlink -f "$0" 2>/dev/null)"
[ -n "$SELF_PATH" ] || SELF_PATH="$0"
case "$SELF_PATH" in
    /*) ;;
    *) SELF_PATH="$(pwd)/$SELF_PATH" ;;
esac
SCRIPT_DIR=${SELF_PATH%/*}
MODDIR=${SCRIPT_DIR}

if [ -x "${MODDIR}/bin/service_hider_lifecycle" ]; then
    "${MODDIR}/bin/service_hider_lifecycle" uninstall
fi