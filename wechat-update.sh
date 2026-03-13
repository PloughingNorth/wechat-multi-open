#!/usr/bin/env bash
#
# 微信多开副本更新脚本
# 当原版微信更新后，运行此脚本同步更新所有副本
# 使用方法: chmod +x wechat-update.sh && ./wechat-update.sh
#

set -euo pipefail

# ==================== 配置 ====================
SRC="/Applications/WeChat.app"
BASE_BUNDLE_ID="com.tencent.xinWeChat"
ICON_BACKUP_DIR="/tmp/wechat-multi-open-icons-backup"

# ==================== 颜色输出 ====================
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
title() { echo -e "${CYAN}${BOLD}$1${NC}"; }

# ==================== 核心功能 ====================

# 扫描现有微信副本
scan_wechat_copies() {
    local copies=()
    for i in {2..99}; do
        local app="/Applications/WeChat${i}.app"
        if [ -d "$app" ]; then
            copies+=("$i")
        fi
    done
    echo "${copies[@]:-}"
}

# 获取原版微信版本号
get_wechat_version() {
    local app="$1"
    /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app/Contents/Info.plist" 2>/dev/null || echo "未知"
}

# 备份副本的自定义图标
backup_icon() {
    local num=$1
    local app="/Applications/WeChat${num}.app"
    local src_icon="$SRC/Contents/Resources/AppIcon.icns"
    local copy_icon="$app/Contents/Resources/AppIcon.icns"

    # 比较图标文件，如果不同说明用户自定义了图标
    if [ -f "$copy_icon" ] && ! cmp -s "$src_icon" "$copy_icon" 2>/dev/null; then
        mkdir -p "$ICON_BACKUP_DIR"
        cp "$copy_icon" "$ICON_BACKUP_DIR/WeChat${num}.icns"
        return 0  # 有自定义图标
    fi
    return 1  # 没有自定义图标
}

# 恢复副本的自定义图标
restore_icon() {
    local num=$1
    local app="/Applications/WeChat${num}.app"
    local backup_icon="$ICON_BACKUP_DIR/WeChat${num}.icns"

    if [ -f "$backup_icon" ]; then
        sudo cp "$backup_icon" "$app/Contents/Resources/AppIcon.icns"
        sudo touch "$app"
        return 0
    fi
    return 1
}

# 更新单个副本
update_copy() {
    local num=$1
    local dst="/Applications/WeChat${num}.app"
    local bundle_id="${BASE_BUNDLE_ID}${num}"
    local has_custom_icon=false

    echo ""
    info "正在更新 WeChat${num}.app..."

    # 备份自定义图标
    if backup_icon "$num" 2>/dev/null; then
        has_custom_icon=true
        echo "  [备份] 已保存自定义图标"
    fi

    # 停止该副本的进程
    killall "WeChat${num}" 2>/dev/null || true

    # 删除旧副本
    echo -n "  [1/7] 删除旧版本..."
    sudo rm -rf "$dst"
    echo -e " ${GREEN}完成${NC}"

    # 从原版复制
    echo -n "  [2/7] 从原版复制..."
    sudo cp -R "$SRC" "$dst"
    echo -e " ${GREEN}完成${NC}"

    # 修改 Bundle ID
    echo -n "  [3/7] 修改 Bundle ID..."
    sudo /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bundle_id" \
        "$dst/Contents/Info.plist" 2>/dev/null
    echo -e " ${GREEN}完成${NC}"

    # 修改显示名称
    echo -n "  [4/7] 修改显示名称..."
    sudo /usr/libexec/PlistBuddy -c "Set :CFBundleName WeChat${num}" \
        "$dst/Contents/Info.plist" 2>/dev/null || true
    sudo /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName WeChat${num}" \
        "$dst/Contents/Info.plist" 2>/dev/null || true
    echo -e " ${GREEN}完成${NC}"

    # 恢复自定义图标
    if [ "$has_custom_icon" = true ]; then
        echo -n "  [5/7] 恢复自定义图标..."
        restore_icon "$num"
        echo -e " ${GREEN}完成${NC}"
    else
        echo -e "  [5/7] 无自定义图标，跳过"
    fi

    # 清除扩展属性
    echo -n "  [6/7] 清除扩展属性并重新签名..."
    sudo xattr -cr "$dst" 2>/dev/null || true
    sudo codesign --force --deep --sign - "$dst" 2>/dev/null || true
    echo -e " ${GREEN}完成${NC}"

    # 修复权限
    echo -n "  [7/7] 修复权限..."
    sudo chown -R "$(whoami)" "$dst"
    echo -e " ${GREEN}完成${NC}"

    info "WeChat${num}.app 更新成功！"
}

# ==================== 主函数 ====================
main() {
    clear
    title "=========================================="
    title "        微信多开副本 - 更新工具"
    title "=========================================="
    echo ""

    # 检查原版微信
    [ ! -d "$SRC" ] && error "未找到原版微信: $SRC"

    local src_version
    src_version=$(get_wechat_version "$SRC")
    info "原版微信版本: ${src_version}"

    # 扫描副本
    local copies=($(scan_wechat_copies))
    local count="${#copies[@]}"

    if [ "$count" -eq 0 ]; then
        warn "当前没有任何副本，无需更新"
        echo ""
        info "请先运行 wechat-multi-open.sh 创建副本"
        exit 0
    fi

    # 显示副本信息
    info "检测到 ${count} 个副本:"
    for i in "${copies[@]}"; do
        local copy_version
        copy_version=$(get_wechat_version "/Applications/WeChat${i}.app")
        if [ "$copy_version" = "$src_version" ]; then
            echo -e "   - WeChat${i}.app  (v${copy_version}) ${GREEN}已是最新${NC}"
        else
            echo -e "   - WeChat${i}.app  (v${copy_version}) ${YELLOW}→ v${src_version}${NC}"
        fi
    done

    echo ""

    # 确认更新
    read -p "$(echo -e ${YELLOW}是否更新所有副本到 v${src_version}？[y/N]: ${NC})" confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        warn "已取消更新"
        exit 0
    fi

    echo ""
    title "=========================================="
    title "  开始更新"
    title "=========================================="

    # 逐个更新
    for i in "${copies[@]}"; do
        update_copy "$i"
    done

    # 清理图标备份
    rm -rf "$ICON_BACKUP_DIR" 2>/dev/null || true

    # 刷新图标缓存和 Dock
    echo ""
    info "正在刷新系统缓存..."
    sudo rm -rf /Library/Caches/com.apple.iconservices.store 2>/dev/null || true
    sudo find /private/var/folders/ -name com.apple.iconservices -exec rm -rf {} \; 2>/dev/null || true
    killall Dock 2>/dev/null || true

    echo ""
    title "=========================================="
    title "  更新完成！"
    title "=========================================="
    echo ""
    info "所有 ${count} 个副本已更新到 v${src_version}"
    info "聊天记录和登录状态不受影响"
    echo ""
}

# ==================== 执行 ====================
main "$@"
