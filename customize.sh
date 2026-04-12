MODULE_ID="hyperpatch"
PREV_RULES_PATH="/data/adb/modules/${MODULE_ID}/rules.conf"
TARGET_RULES_PATH="$MODPATH/rules.conf"

if [ "$(getprop ro.product.device)" != "myron" ]; then
	abort "你的手机不是 REDMI K90 Pro Max，正在取消安装..."
fi

ui_print "- 正在应用 Rescue Party Plus 补丁..."
ui_print "- 正在应用基于连接状态自动切换 ADB..."
ui_print "- 正在应用本地 HTTP 服务隐藏..."

if [ -f "$PREV_RULES_PATH" ]; then
    ui_print "- 保留上次安装的规则配置..."
    cp -af "$PREV_RULES_PATH" "$TARGET_RULES_PATH"
else
    ui_print "- 未找到旧规则，保留内置模板..."
fi

ui_print "- 正在设置脚本权限..."

# 安全的权限设置
[ -d "$MODPATH/bin" ] && set_perm_recursive "$MODPATH/bin" 0 0 0755 0755
[ -d "$MODPATH/odm" ] && set_perm_recursive "$MODPATH/odm" 0 0 0755 0644
[ -f "$MODPATH/service.sh" ] && set_perm "$MODPATH/service.sh" 0 0 0755
[ -f "$MODPATH/post-fs-data.sh" ] && set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
[ -f "$MODPATH/uninstall.sh" ] && set_perm "$MODPATH/uninstall.sh" 0 0 0755
[ -f "$MODPATH/action.sh" ] && set_perm "$MODPATH/action.sh" 0 0 0755

ui_print ""
ui_print "提示：可选补丁可在刷入前取消注释启用..."
ui_print ""
ui_print "请在安装后重启设备..."
ui_print ""