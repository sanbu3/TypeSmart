# TypeSmart - 智能输入法切换工具

![TypeSmart logo](https://img.shields.io/badge/TypeSmart-输入法切换工具-brightgreen)
![Platform](https://img.shields.io/badge/platform-macOS-blue)
![License](https://img.shields.io/badge/license-MIT-green)

TypeSmart 是一款 macOS 应用程序，可以自动为不同应用程序切换输入法，提高您的多语言输入体验和工作效率。无需手动切换，TypeSmart 会记住您的偏好，在您切换应用时自动选择相应的输入法。

![TypeSmart 应用原型_规则](https://wangww.online/app/TypeSmart%20应用原型_规则.png)

## ✨ 功能特点

- **应用程序识别**：自动识别当前使用的应用程序
- **自定义规则**：为不同应用设置默认输入法
- **即时切换**：在应用程序之间切换时自动切换输入法
- **使用统计**：提供输入法切换统计和分析
- **日志记录**：完整的操作日志，方便排查问题
- **低资源占用**：优化的性能，极低的系统资源占用

## 📋 系统要求

- macOS 11.0 (Big Sur) 或更高版本
- 至少 50MB 可用磁盘空间
- 至少 4GB 内存

## 🚀 安装指南

### 方法 1：直接下载

1. 从 [Releases](https://github.com/sanbu3/TypeSmart/releases) 页面下载最新版本的 `TypeSmart.dmg`
2. 打开下载的 DMG 文件
3. 将 TypeSmart 拖到 Applications 文件夹
4. 从 Applications 文件夹中打开 TypeSmart

### 方法 2：从源代码构建

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

## 🔑 首次设置

1. **授权辅助功能权限**：
   - 首次启动时，TypeSmart 会请求辅助功能权限
   - 如未自动弹出授权窗口，请前往系统设置 → 隐私与安全性 → 辅助功能，添加 TypeSmart

2. **设置应用输入法规则**：
   - 点击"+"按钮添加新规则
   - 选择应用程序和对应的默认输入法
   - 保存后规则将立即生效

3. **通用设置（可选）**：
   - 在"通用设置"选项卡中，可以配置以下选项：
     - 在菜单栏显示图标
     - 开机自动启动
     - 自动检测权限

![TypeSmart 应用原型_通用](https://wangww.online/app/TypeSmart%20应用原型_通用.png)

## 💡 使用技巧

1. **手动输入 Bundle ID**：
   - 对于无法通过浏览器选择的应用，可以手动输入其 Bundle ID
   - 点击应用选择区域下方的"手动输入 Bundle ID"选项

2. **检查权限状态**：
   - 在通用设置中可以随时查看当前权限状态
   - 绿色表示已授权，红色表示未授权

3. **统计分析**：
   - 在"使用统计"选项卡查看输入法切换统计
   - 支持按不同时间段筛选数据

4. **查看日志**：
   - 在"日志记录"选项卡查看详细操作日志
   - 可以按类别筛选和搜索日志内容

## 🛠️ 常见问题解决

### 输入法没有自动切换？

1. 检查辅助功能权限是否已授予
2. 确认已为当前应用设置了规则
3. 查看日志记录，了解具体原因

![TypeSmart 应用原型_日志](https://wangww.online/app/TypeSmart%20应用原型_日志.png)

### 如何卸载 TypeSmart？

1. 退出 TypeSmart 应用
2. 从 Applications 文件夹删除 TypeSmart.app
3. 清除偏好设置（可选）：
   ```bash
   defaults delete com.yourcompany.TypeSmart
   ```

### 设置后不生效？

1. 尝试重启 TypeSmart 应用
2. 检查日志记录中是否有错误报告
3. 确保输入法在系统输入法列表中可用

## 📊 统计功能说明

TypeSmart 提供了详细的输入法切换统计功能，包括：

- **基础统计**：总切换次数、成功率等
- **时间分析**：按时段查看切换频率
- **应用分析**：最常用的应用切换路径

![TypeSmart 应用原型_统计](https://wangww.online/app/TypeSmart%20应用原型_统计.png)

## 🔄 更新日志

查看 [CHANGELOG.md](CHANGELOG.md) 了解各版本的更新内容。

## 🤝 贡献

欢迎贡献代码、报告问题或提出建议！请查看 [CONTRIBUTING.md](CONTRIBUTING.md) 了解如何参与项目。

## 📄 许可证

TypeSmart 使用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 📞 联系方式

- 开发者邮箱：sanbuwang@foxmail.com
- 项目网站：https://wangww.online

![TypeSmart 应用原型_关于](https://wangww.online/app/TypeSmart%20应用原型_关于.png)

---

*TypeSmart - 让输入更智能，让工作更高效*
