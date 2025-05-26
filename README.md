# TypeSmart - 智能输入法切换工具

![TypeSmart logo](https://img.shields.io/badge/TypeSmart-输入法切换工具-brightgreen)
![Platform](https://img.shields.io/badge/platform-macOS-blue)
![License](https://img.shields.io/badge/license-MIT-green)

TypeSmart 是一款 macOS 应用程序，可以自动为不同应用程序切换输入法，提升您的多语言输入体验和工作效率。无需手动切换，TypeSmart 会记住您的偏好，在您切换应用时自动选择对应的输入法。

## 🆕 v1.8.0 重大功能增强

- 彻底修复规则污染问题，规则列表仅包含用户主动添加的规则
- GeneralSettingsView 多项 UI 优化，集成自动迁移到 /Applications、权限处理、状态栏配置等
- 新增“自动移动到应用程序文件夹”功能，兼容无开发者账号分发，失败时自动弹出 Finder 并友好提示
- 日志系统与统计分析功能增强，支持更细致的行为追踪与问题排查
- clean_typesmart_userdata.sh 脚本：一键彻底清理本地所有用户数据、日志、偏好设置、沙盒容器，确保分发包为“出厂状态”
- TypeSmart_factory_clean.sh 脚本：自动清理+打包分发，Release 版 TypeSmart.app 自动拷贝到桌面
- Info.plist 版本号更新为 1.8.0，CFBundleVersion 为 180
- RELEASES_TEMPLATE.md 全面更新，详细列出 1.8.0 新特性、系统要求、安装说明、已知问题、未来计划等
- 多次脚本/工具验证，确保分发包无历史数据

## ✨ 功能特性

- **应用程序识别**：自动识别当前使用的应用程序
- **自定义规则**：为不同应用设置默认输入法
- **即时切换**：应用间切换时自动切换输入法
- **使用统计**：提供输入法切换统计和分析
- **日志记录**：完整的操作日志，方便排查问题
- **低资源占用**：优化的性能，极低的系统资源占用

## 📥 下载与安装

### 方法 1：直接下载

1. 从 [Releases](https://github.com/sanbu3/TypeSmart/releases) 页面下载最新版 `TypeSmart.dmg`
2. 打开下载的 DMG 文件
3. 将 TypeSmart 拖到 Applications 文件夹
4. 从 Applications 文件夹中打开 TypeSmart

### 方法 2：从源码构建

1. 克隆仓库
   ```bash
   git clone https://github.com/sanbu3/TypeSmart.git
   cd TypeSmart
   ```
2. 使用 Xcode 打开项目
   ```bash
   open InputSwitcher.xcodeproj
   ```
3. 在 Xcode 中构建和运行项目 (⌘+R)

## 🆕 出厂清理与分发

- 使用 `clean_typesmart_userdata.sh` 可彻底清理本地所有用户数据、日志、偏好设置、沙盒容器
- 使用 `TypeSmart_factory_clean.sh` 可一键清理+打包分发，Release 版 TypeSmart.app 自动拷贝到桌面

## 🛠 常见问题

- 输入法没有自动切换？请检查辅助功能权限、规则设置和日志记录
- 如何卸载 TypeSmart？退出应用后从 Applications 文件夹删除 TypeSmart.app，并可运行清理脚本

## 📄 许可证
TypeSmart 使用 MIT 许可证
