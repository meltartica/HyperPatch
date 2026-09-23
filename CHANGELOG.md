# Changelog

## v2026.9.24

- 相机：开启新版徕卡UI（`ro.theme_customize`、`ro.boot.product.theme_customize`、`ro.leica.camera`、`ro.product.essential.support`）
- 修复：OEM 解锁允许属性由「删除」改为「置空」。删除会断开属性 trie 节点，被断开的内存不会被回收，属性区留下永久空洞，原生属性区扫描正是靠这种空洞判断属性被动过手脚
- 构建：`version` 改为日期格式，`versionCode` 同步为 `yyyyMMdd`，管理器据此识别更新（此前 `versionCode` 恒为 1，不会提示更新）

## v2026.9.14

- 相机：开启新版徕卡UI

## v2026.9.11

- OEM：开机后清除 OEM 解锁允许属性
- 显示：停用刷新率切换的亮度（`persist.vendor.disable_idle_fps.threshold=1`）

## v2026.5.28

- 移除：本地 HTTP 服务隐藏子系统（`bin/service_hider_ctl`、`bin/service_hider_lifecycle`、`rules.conf`）。**破坏性变更**：旧 `rules.conf` 不会在重装时迁移，需要自行备份
- 新增：开机 60 秒后强制停止小米互联通信服务（`com.xiaomi.mi_connect_service`），修复 NFC 贴贴分享不可用
- 修复：自动切换 ADB 不再用 `setprop` 直接写 `sys.usb.config` —— 该值会被 MIUI / HyperOS 的 USB HAL 覆盖，表现为「ADB 显示已开启但实际不通」。改为 `settings put` + 重启 adbd，交由系统管理 USB 配置
- 修复：USB 状态切换后加入 8 秒冷却，避免设备重新枚举触发 UDC 状态跳变，造成「开→关→开」来回抖动

## v2026.4.13

- 精简：移除常驻的 inotifyd watcher 进程，改为仅开机恢复一次，消除常驻 CPU 占用
- 精简：USB 检测改用单一规范 UDC 文件，不再多文件扫描
- 修复：菜单脚本更新 XML 路径判断逻辑，并加入恢复校验
- 移除：`system/` 目录

## v2026.4.12

- 构建：清空音量黑名单改为直接内置已清理的 XML（`odm/etc/audio/audio_lowpower_app_list.xml`），移除开机时生成补丁、以及按 Magisk / KernelSU / APatch 分环境的专门挂载逻辑。KernelSU、APatch 交由原生覆盖处理，Magisk 由 `post-fs-data.sh` 统一绑定挂载 —— 兼容性提升来源于此
- 文档：全部代码注释、用户说明与界面文案改为中文
- 性能：菜单脚本绕过 Java settings 包装，直接快速解析 XML，响应几乎无延迟
- 性能：`service_hider_ctl` 用纯 shell 逻辑替换 awk / sed / pm 子进程调用；`service_hider_lifecycle` 改用元数据（`stat`）文件签名，消除 CPU 尖峰
- 修复：`service_hider` 恢复规则时漏掉端点变量赋值，导致白名单端口的兜底 REJECT 规则没有被追加，未授权应用可绕过防火墙
- 修复：自动切换 ADB 回退到稳定的轮询机制，解决漏判 USB 插入
- 修复：卸载时正确执行服务生命周期的收尾钩子
- 说明：明确 Rescue Party Plus 针对的是「应用持续崩溃」的场景

## v2026.4.11

- 首个版本
- 新增：本地 HTTP 服务隐藏（`rules.conf` 白名单 / 黑名单，绑定在白名单端口上）
- 新增：清空音量黑名单列表（开机生成净化后的 XML 并绑定挂载）
- 新增：基于连接状态自动切换 ADB
- 新增：禁用 Rescue Party Plus（`persist.sys.rescuepartyplus.disable=1`）
- 新增：强制启用 AOD 的 1Hz 刷新率（`ro.vendor.mi_sf.aod_mode_ddic_refresh_rate=1`）

---

> v2026.4.11 至 v2026.5.28 的条目依据 git 提交历史整理。仓库中没有对应的 tag，GitHub 上也没有发布过 Release，各次提交写入 `module.prop` 的 `version=` 是唯一的版本记录。v2026.9.14 是一次未进入仓库的独立打包。
