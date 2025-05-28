#!/bin/bash

PROJECT_FILE="/Users/wang/Documents/InputSwitcher/InputSwitcher.xcodeproj/project.pbxproj"
VERSION="2.0.0"
BUILD="20250528"

# 备份项目文件
cp "$PROJECT_FILE" "$PROJECT_FILE.bak"

# 更新版本号
sed -i '' "s/MARKETING_VERSION = 1.6;/MARKETING_VERSION = $VERSION;/g" "$PROJECT_FILE"
sed -i '' "s/CURRENT_PROJECT_VERSION = 1;/CURRENT_PROJECT_VERSION = $BUILD;/g" "$PROJECT_FILE"

echo "✅ 项目文件版本已更新为 $VERSION (构建号: $BUILD)"
