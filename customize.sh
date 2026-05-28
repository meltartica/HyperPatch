MODULE_ID="hyperpatch"

if [ "$(getprop ro.product.device)" != "myron" ]; then
	abort "你的手机不是 REDMI K90 Pro Max，正在取消安装..."
fi

ui_print "- 正在应用 Rescue Party Plus 补丁..."
ui_print "- 正在应用基于连接状态自动切换 ADB..."
ui_print "- 正在应用开机自动杀死小米互联服务..."

ui_print "- 正在设置脚本权限..."

# 安全的权限设置
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