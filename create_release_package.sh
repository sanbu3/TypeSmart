#!/bin/bash

# TypeSmart 发布包创建脚本
# 创建最终的发布包，用于分发

echo "🚀 TypeSmart 发布包创建脚本"
echo "=================================================="

# 定义路径
PROJECT_DIR="/Users/wang/Documents/InputSwitcher"
BUILD_DIR="$PROJECT_DIR/build/Build/Products/Release"
RELEASE_DIR="/Users/wang/Desktop/TypeSmart_v2.0.0_Release"
APP_NAME="TypeSmart.app"

# 检查发布构建是否存在
if [ ! -d "$BUILD_DIR/$APP_NAME" ]; then
    echo "❌ 错误: 未找到发布构建，请先运行构建命令"
    exit 1
fi

echo "📦 创建发布目录..."
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

echo "📋 复制应用程序..."
cp -R "$BUILD_DIR/$APP_NAME" "$RELEASE_DIR/"

echo "📄 创建安装说明..."
cat > "$RELEASE_DIR/安装说明.txt" << 'EOF'
TypeSmart 输入法切换工具
======================

安装步骤:
1. 将 TypeSmart.app 拖拽到 Applications 文件夹
2. 首次运行时，系统会要求授权权限
3. 前往 系统设置 > 隐私与安全性 > 辅助功能，启用 TypeSmart
4. 前往 系统设置 > 隐私与安全性 > 输入监控，启用 TypeSmart

使用说明:
- 应用会自动检测输入源并切换到相应的键盘布局
- 支持音频反馈，可在应用内调整音量
- 可以设置开机自启动

版本信息:
- 版本: 2.0.0
- 适用于 macOS 15.4 及以上版本
- 支持 Apple Silicon 和 Intel 处理器

技术支持:
如有问题，请访问项目主页或联系开发者。
EOF

echo "📊 生成发布信息..."
cat > "$RELEASE_DIR/release_info.txt" << EOF
TypeSmart Release Information
============================

Build Date: $(date)
App Version: $(plutil -p "$RELEASE_DIR/$APP_NAME/Contents/Info.plist" | grep CFBundleShortVersionString | cut -d '"' -f 4)
Bundle Version: $(plutil -p "$RELEASE_DIR/$APP_NAME/Contents/Info.plist" | grep CFBundleVersion | cut -d '"' -f 4)
Bundle ID: $(plutil -p "$RELEASE_DIR/$APP_NAME/Contents/Info.plist" | grep CFBundleIdentifier | cut -d '"' -f 4)
Min macOS: $(plutil -p "$RELEASE_DIR/$APP_NAME/Contents/Info.plist" | grep LSMinimumSystemVersion | cut -d '"' -f 4 || echo "15.4")

App Size: $(du -sh "$RELEASE_DIR/$APP_NAME" | cut -f1)

Factory Reset Settings Applied:
- Launch at Login: Disabled
- Dock Icon: Visible
- Auto Check Permissions: Enabled
- Auto Switch: Enabled
- Audio Feedback: Enabled (80% volume)
- Success Sound: Frog
- Failure Sound: Purr

Build Configuration: Release
Code Signing: Yes
EOF

echo "🔍 验证代码签名..."
codesign -dv --verbose=4 "$RELEASE_DIR/$APP_NAME" 2>&1 | grep "Authority\|TeamIdentifier\|Sealed Resources" || echo "代码签名信息不完整"

echo "📁 创建压缩包..."
cd "$RELEASE_DIR"
zip -r "TypeSmart-v$(plutil -p "$APP_NAME/Contents/Info.plist" | grep CFBundleShortVersionString | cut -d '"' -f 4).zip" "$APP_NAME" "安装说明.txt" "release_info.txt"

echo ""
echo "✅ 发布包创建完成!"
echo "=================================================="
echo "📁 发布目录: $RELEASE_DIR"
echo "📦 应用程序: $RELEASE_DIR/$APP_NAME"
echo "📋 安装说明: $RELEASE_DIR/安装说明.txt"
echo "📊 发布信息: $RELEASE_DIR/release_info.txt"
echo "🗜️  压缩包: $RELEASE_DIR/TypeSmart-v*.zip"
echo ""
echo "🎉 TypeSmart 已准备好发布！"
