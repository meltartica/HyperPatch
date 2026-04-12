#!/system/bin/sh
MODDIR="${0%/*}"

# 向相关模块发送卸载信号以清空网络规则与锁文件
if [ -x "${MODDIR}/bin/service_hider_lifecycle" ]; then
    "${MODDIR}/bin/service_hider_lifecycle" uninstall
fi