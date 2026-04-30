#!/bin/bash
set -e

# 配置
APP_NAME="Clipboard"
BUNDLE_ID="com.clipboard.app"
VERSION="1.0.0"
BUILD_DIR=".build/release"
OUTPUT_DIR="."
EXECUTABLE_NAME="clipboard"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 iconset 是否存在
check_iconset() {
    if [ ! -d "macOS/AppIcon.iconset" ]; then
        log_error "macOS/AppIcon.iconset 目录不存在"
        exit 1
    fi
    log_info "图标资源检查通过"
}

# Release 构建
build_release() {
    log_info "开始 Release 构建..."
    swift build --configuration release
    log_info "构建完成"
}

# 创建 app 目录结构
create_app_structure() {
    log_info "创建 App 目录结构..."
    rm -rf "${OUTPUT_DIR}/${APP_NAME}.app"
    mkdir -p "${OUTPUT_DIR}/${APP_NAME}.app/Contents/MacOS"
    mkdir -p "${OUTPUT_DIR}/${APP_NAME}.app/Contents/Resources"
    log_info "目录结构创建完成"
}

# 复制可执行文件
copy_executable() {
    log_info "复制可执行文件..."
    if [ ! -f "${BUILD_DIR}/${EXECUTABLE_NAME}" ]; then
        log_error "可执行文件不存在: ${BUILD_DIR}/${EXECUTABLE_NAME}"
        exit 1
    fi
    cp "${BUILD_DIR}/${EXECUTABLE_NAME}" "${OUTPUT_DIR}/${APP_NAME}.app/Contents/MacOS/"
    chmod +x "${OUTPUT_DIR}/${APP_NAME}.app/Contents/MacOS/${EXECUTABLE_NAME}"
    log_info "可执行文件复制完成"
}

# 生成图标
generate_icon() {
    log_info "生成 icns 图标..."
    rm -rf "${OUTPUT_DIR}/${APP_NAME}.app/Contents/Resources/AppIcon.iconset"
    cp -R "macOS/AppIcon.iconset" "${OUTPUT_DIR}/${APP_NAME}.app/Contents/Resources/"
    iconutil --convert icns --output "${OUTPUT_DIR}/${APP_NAME}.app/Contents/Resources/AppIcon.icns" \
        "${OUTPUT_DIR}/${APP_NAME}.app/Contents/Resources/AppIcon.iconset"
    rm -rf "${OUTPUT_DIR}/${APP_NAME}.app/Contents/Resources/AppIcon.iconset"
    log_info "图标生成完成"
}

# 创建 Info.plist
create_infoplist() {
    log_info "创建 Info.plist..."
    cat > "${OUTPUT_DIR}/${APP_NAME}.app/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>clipboard</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.clipboard.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Clipboard</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.13</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF
    log_info "Info.plist 创建完成"
}

# 签名应用
sign_app() {
    log_info "签名应用..."
    codesign --force --deep --sign - "${OUTPUT_DIR}/${APP_NAME}.app"
    log_info "签名完成"
}

# 验证打包结果
verify_app() {
    log_info "验证打包结果..."
    if [ ! -f "${OUTPUT_DIR}/${APP_NAME}.app/Contents/MacOS/${EXECUTABLE_NAME}" ]; then
        log_error "可执行文件不存在"
        exit 1
    fi
    if [ ! -f "${OUTPUT_DIR}/${APP_NAME}.app/Contents/Resources/AppIcon.icns" ]; then
        log_error "图标文件不存在"
        exit 1
    fi
    codesign -dvv "${OUTPUT_DIR}/${APP_NAME}.app" 2>&1 | grep -E "(Identifier|Signature)"
    log_info "验证通过"
}

# 主流程
main() {
    cd "$(dirname "$0")/.."
    log_info "=== 开始打包 ${APP_NAME}.app ==="

    check_iconset
    build_release
    create_app_structure
    copy_executable
    create_infoplist
    generate_icon
    sign_app
    verify_app

    log_info "=== 打包完成 ==="
    log_info "输出路径: ${OUTPUT_DIR}/${APP_NAME}.app"
}

main "$@"
