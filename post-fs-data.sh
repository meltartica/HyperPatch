#!/system/bin/sh
MODDIR="${0%/*}"

# 将 MODDIR folder 下的每个文件绑定挂载到匹配的 folder 路径上
replace_files() {
    folder="$1"
    find "${MODDIR}/${folder}" -type f 2>/dev/null | while IFS= read -r src; do
        dst="${src#${MODDIR}}"
        [ -f "$dst" ] && mount --bind "$src" "$dst"
    done
}

# KSU 通过自身覆盖机制原生处理 odm 在此跳过手动挂载
# Magisk 只覆盖 system 分区 因此非 system 分区需要显式的绑定挂载
mount_folders="odm"
if [ "$KSU" = "true" ] \
    || command -v ksud >/dev/null 2>&1 \
    || command -v apd  >/dev/null 2>&1; then
    mount_folders=""
fi

# 遍历需要挂载的目录 若模块及系统中都存在该路径则进行绑定替换
for folder in $mount_folders; do
    if [ -d "${MODDIR}/${folder}" ] && [ -d "/${folder}" ]; then
        replace_files "$folder"
    fi
done