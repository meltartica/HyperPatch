MODDIR="${0%/*}"
CTL="${MODDIR}/bin/service_hider_ctl"
XML_PATH="/odm/etc/audio/audio_lowpower_app_list.xml"
# 模块内直接采用 odm 路径作为单一数据源
MODULE_XML="${MODDIR}${XML_PATH}"

# 获取文件的签名 依次尝试 stat 和 cksum 以及 wc 作为回退
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
# 打印所有修补项的内部状态 以供应用界面以及终端查看
echo

echo "[ADB]"
# 绕过无法使用的 settings 命令 直接读取 XML 且速度极快
echo "adb_enabled=$(settings get global adb_enabled 2>/dev/null || echo "unknown")"
echo "adbd_service=$(getprop init.svc.adbd 2>/dev/null)"
echo "sys.usb.config=$(getprop sys.usb.config 2>/dev/null)"
echo "pers.usb.config=$(getprop persist.sys.usb.config 2>/dev/null)"
echo "device=$(getprop ro.product.device 2>/dev/null)"
echo

echo "[Hide HTTP Services]"
# 检查本地服务隐藏器的安装情况及运行状态
if [ -x "$CTL" ]; then
    echo "applying_rules=running"
    if "$CTL" restore >/dev/null 2>&1; then
        echo "applying_rules=ok"
    else
        echo "applying_rules=failed"
    fi
    echo

    "$CTL" status
    echo
    "$CTL" check
    echo
    "$CTL" selftest
else
    echo "service_hider_ctl missing or not executable"
fi

echo
echo "[Clear Volume Level Blacklist]"
# 校验位于系统 ODM 分区的低功耗音频配置是否已经被成功替换
echo "system_xml=$XML_PATH"
if [ -f "$MODULE_XML" ] && [ -f "$XML_PATH" ]; then
    cmp -s "$MODULE_XML" "$XML_PATH" && match=1 || match=0
    echo "xml_match=$match"
    echo "module_sig=$(file_sig "$MODULE_XML")"
    echo "system_sig=$(file_sig "$XML_PATH")"
else
    echo "xml_match=not-found"
fi

echo
echo "Done. Keeping output visible for 10 seconds..."
sleep 10
