#!/bin/bash

# TypeSmart 无代码签名构建脚本
# 此脚本用于创建一个不带代码签名的应用程序构建

echo "🔨 TypeSmart 无代码签名构建脚本"
echo "=================================================="

# 定义路径
PROJECT_DIR="/Users/wang/Documents/InputSwitcher"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="TypeSmart"

# 清理旧构建
echo "🧹 清理旧构建..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 运行xcodebuild构建项目，不进行代码签名
echo "🏗️ 构建项目 (无代码签名)..."
xcodebuild -project "$PROJECT_DIR/InputSwitcher.xcodeproj" \
    -scheme InputSwitcher \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    ENABLE_BITCODE=NO

# 检查构建是否成功
if [ ! -d "$BUILD_DIR/Build/Products/Release/$APP_NAME.app" ]; then
    echo "❌ 构建失败！请检查错误消息。"
    exit 1
fi

echo "✅ 无代码签名构建完成！"
echo "应用程序位置: $BUILD_DIR/Build/Products/Release/$APP_NAME.app"
echo ""
echo "注意: 由于此应用未经签名，用户可能需要在系统设置中放行此应用。"
echo "您可以运行 create_release_package.sh 脚本创建最终发布包。"
