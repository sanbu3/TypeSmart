#!/bin/zsh
# TypeSmart macOS 分发包彻底清理+构建+无历史数据打包一键脚本
# 用法：chmod +x build_and_clean_all.sh && ./build_and_clean_all.sh

set -e

cd "$(dirname "$0")"

# 1. 清理历史产物和隐藏文件
echo "🧹 清理历史产物和隐藏文件..."
rm -rf build/Release/TypeSmart.app
rm -rf build/DerivedData
rm -rf *.dmg *.zip
find . -name '.DS_Store' -delete
find . -name '._*' -delete
find . -type f -exec xattr -c {} \;

# 2. 检查 PNG 是否为标准 PNG（人工确认输出）
echo "🔍 检查 PNG 资源格式..."
file InputSwitcher/Assets.xcassets/AppIcon.appiconset/*.png || true
file InputSwitcher/Assets.xcassets/Image.imageset/*.png || true

# 3. 构建
echo "⚙️ 进行 Release 构建..."
xcodebuild -project InputSwitcher.xcodeproj -scheme InputSwitcher -configuration Release -derivedDataPath build/DerivedData clean build

# 4. 拷贝产物到桌面并递归清理扩展属性
echo "📦 拷贝产物到桌面并清理扩展属性..."
cp -R build/DerivedData/Build/Products/Release/TypeSmart.app ~/Desktop/
xattr -cr ~/Desktop/TypeSmart.app

# 5. 彻底去除 TypeSmart.app 目录本身的 FinderInfo 等扩展属性
echo "🧽 彻底去除 TypeSmart.app 目录扩展属性..."
mkdir -p ~/Desktop/TypeSmart_clean
cp -R ~/Desktop/TypeSmart.app/* ~/Desktop/TypeSmart_clean/
rm -rf ~/Desktop/TypeSmart.app
mv ~/Desktop/TypeSmart_clean ~/Desktop/TypeSmart.app
xattr -cr ~/Desktop/TypeSmart.app

# 6. 检查分发包是否干净（无输出即为干净）
echo "🔬 检查分发包扩展属性..."
xattr -lr ~/Desktop/TypeSmart.app || true
find ~/Desktop/TypeSmart.app -name '._*'

echo "✅ TypeSmart.app 分发包已彻底清理并产出在桌面！"
