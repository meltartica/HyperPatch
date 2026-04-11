XML_PATH="/odm/etc/audio/audio_lowpower_app_list.xml"
MAGISK_BIND_PATH="$MODPATH/$(basename "$XML_PATH")"
KSU_OVERLAY_PATH="$MODPATH/system${XML_PATH}"
MODULE_ID="$(sed -n 's/^id=//p' "$MODPATH/module.prop" 2>/dev/null | head -n 1)"
[ -n "$MODULE_ID" ] || MODULE_ID="hyperpatch"
PREV_RULES_PATH="/data/adb/modules/${MODULE_ID}/rules.conf"
TARGET_RULES_PATH="$MODPATH/rules.conf"

if [ "$(getprop ro.product.device)" != "myron" ]; then
	abort "Your phone is not REDMI K90 Pro Max, cancelling install（你的手机不是 REDMI K90 Pro Max，正在取消安装）"
fi

ui_print "- Applying Rescue Party Plus Patch（正在应用 Rescue Party Plus 补丁）"
ui_print "- Applying Context-Aware ADB implementation（正在应用基于连接状态自动切换 ADB）"
ui_print "- Adding Hide HTTP Services implementation（正在应用本地 HTTP 服务隐藏）"
ui_print "- Applying Clear Volume Blacklist patch（正在清空音量黑名单列表）"

if [ -f "$PREV_RULES_PATH" ]; then
	ui_print "- Preserving existing rules.conf from previous install（保留上次安装的规则配置）"
	cp -af "$PREV_RULES_PATH" "$TARGET_RULES_PATH"
else
	ui_print "- No previous rules.conf found, keeping packaged template（未找到旧规则，保留内置模板）"
fi

if [ "$KSU" ] || [ "$APATCH" ]; then
	ui_print "- Environment: KernelSU / APatch（环境：KernelSU / APatch）"
	ui_print "- Mount mode: System directory overlay（挂载模式：系统目录映射）"
	mkdir -p "$(dirname "$KSU_OVERLAY_PATH")"
	rm -f "$MAGISK_BIND_PATH" 2>/dev/null
	ui_print "- Clear Volume patch will be generated at boot（音量黑名单清理将在开机时生成）"
else
	ui_print "- Environment: Magisk（环境：Magisk）"
	ui_print "- Mount mode: Native bind mount（挂载模式：原生绑定挂载）"
	rm -f "$KSU_OVERLAY_PATH" 2>/dev/null
	ui_print "- Clear Volume patch will be generated at boot（音量黑名单清理将在开机时生成）"
fi

ui_print "- Setting script permissions（正在设置脚本权限）"
set_perm_recursive "$MODPATH/bin" 0 0 0755 0755
set_perm_recursive "$MODPATH/system" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
ui_print ""
ui_print "Note: Optional patches can be enabled by uncommenting them before flashing.（提示：可选补丁可在刷入前取消注释启用）"
ui_print ""
ui_print "Please reboot your device after installation.（请在安装后重启设备）"