# 参与贡献

感谢您考虑为 TypeSmart 项目做出贡献！以下是一些参与项目的指南。

## 报告问题

如果您发现了 bug 或有新功能建议，请在 GitHub Issues 中创建一个新的 issue。请提供尽可能详细的信息：

- 问题的清晰描述
- 重现步骤
- 预期行为与实际行为
- 截图（如果适用）
- 系统信息：
  - macOS 版本
  - TypeSmart 版本
  - 使用的输入法

## 开发环境设置

1. 克隆仓库
   ```bash
   git clone https://github.com/YourUsername/TypeSmart.git
   cd TypeSmart
   ```

2. 使用 Xcode 打开项目
   ```bash
   open InputSwitcher.xcodeproj
   ```

3. 确保满足以下要求：
   - Xcode 14.0+
   - Swift 5.7+
   - macOS 11.0+

## 代码贡献流程

1. Fork 这个仓库
2. 创建您的特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交您的更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建一个 Pull Request

## 代码风格指南

- 遵循 [Swift 官方 API 设计指南](https://swift.org/documentation/api-design-guidelines/)
- 使用有意义的变量和函数名称
- 为公共 API 提供文档注释
- 确保代码可读性和可维护性
- 添加足够的单元测试

## Pull Request 流程

1. 确保 PR 描述中明确说明了更改内容和原因
2. 确保所有自动化测试通过
3. 确保代码遵循项目的代码风格
4. 如果添加了新功能，请更新文档

## 版本控制

我们使用 [语义化版本控制](https://semver.org/)。格式为：MAJOR.MINOR.PATCH

- MAJOR 版本：不兼容的 API 更改
- MINOR 版本：向后兼容的功能性新增
- PATCH 版本：向后兼容的问题修正

## 许可证

通过贡献代码，您同意您的贡献将在 MIT 许可证下发布。
