#!/bin/bash
#
# 微信多开管理器 - 编译打包脚本
# 使用 swiftc 直接编译，无需 Xcode 项目
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="微信多开管理器"
EXECUTABLE="WeChatMultiOpen"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
SOURCES_DIR="$SCRIPT_DIR/Sources"
PLIST_SRC="$SCRIPT_DIR/Resources/Info.plist"
ICON_SRC="$SCRIPT_DIR/Resources/AppIcon.icns"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
step() { echo -e "${CYAN}→${NC} $1"; }

echo ""
echo "====================================="
echo "  微信多开管理器 - 编译打包"
echo "====================================="
echo ""

# Check macOS version
if ! sw_vers -productVersion | grep -qE '^1[3-9]\.|^[2-9]'; then
    error "需要 macOS 13.0 或更高版本"
fi

# Check swiftc
if ! command -v swiftc &>/dev/null; then
    error "未找到 swiftc，请安装 Xcode Command Line Tools: xcode-select --install"
fi

# Clean previous build
step "清理旧构建..."
rm -rf "$BUILD_DIR"

# Create .app bundle structure
step "创建应用包结构..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Collect source files
SWIFT_FILES=()
while IFS= read -r -d '' f; do
    SWIFT_FILES+=("$f")
done < <(find "$SOURCES_DIR" -name '*.swift' -print0)

if [ "${#SWIFT_FILES[@]}" -eq 0 ]; then
    error "未找到 Swift 源文件"
fi

info "找到 ${#SWIFT_FILES[@]} 个源文件"

# Compile
step "编译中..."
swiftc \
    -target "$(uname -m)-apple-macosx13.0" \
    -sdk "$(xcrun --show-sdk-path)" \
    -parse-as-library \
    -o "$MACOS_DIR/$EXECUTABLE" \
    "${SWIFT_FILES[@]}" \
    -framework AppKit \
    -framework SwiftUI \
    -Osize

if [ $? -ne 0 ]; then
    error "编译失败"
fi

info "编译成功"

# Copy Info.plist
step "复制 Info.plist..."
cp "$PLIST_SRC" "$CONTENTS/Info.plist"

# Copy app icon
if [ -f "$ICON_SRC" ]; then
    step "复制应用图标..."
    cp "$ICON_SRC" "$RESOURCES_DIR/AppIcon.icns"
    info "图标已添加"
else
    echo -e "  ${CYAN}提示: 未找到 AppIcon.icns，跳过图标${NC}"
fi

# Create PkgInfo
echo -n "APPL????" > "$CONTENTS/PkgInfo"

# Codesign
step "签名应用..."
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || {
    echo -e "  ${RED}警告: 签名失败，应用仍可运行但可能需要手动授权${NC}"
}

info "签名完成"

# Done
echo ""
echo "====================================="
echo -e "  ${GREEN}构建成功！${NC}"
echo "====================================="
echo ""
echo "  应用位置: $APP_BUNDLE"
echo ""
echo "  运行方式:"
echo "    1. 双击打开: open \"$APP_BUNDLE\""
echo "    2. 或拖入 /Applications 目录"
echo ""

# Ask to open
read -p "是否立即打开？[y/N]: " open_now
if [[ "$open_now" =~ ^[Yy]$ ]]; then
    open "$APP_BUNDLE"
fi
