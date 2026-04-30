# Clipboard

macOS 菜单栏剪贴板管理器。

## 功能特性

- **多类型支持**: 支持文本、图片、RTF、HTML、文件 URL 等剪贴内容
- **全局快捷键**: `Control + Shift + V` 快速唤出剪贴板窗口
- **开机启动**: 可选自动启动，开机即用
- **深色/浅色模式**: 自动跟随系统外观
- **单实例运行**: 避免重复启动占用资源

## 使用说明

1. **唤出窗口**: 点击菜单栏图标 或 按 `Control + Shift + V`
2. **粘贴内容**: 点击历史条目直接粘贴
3. **清空历史**: 点击右上角清空按钮
4. **开机启动**: 菜单栏 → 开机启动

## 项目结构

```
Sources/
├── App/
│   ├── main.swift          # 应用入口，单实例检测
│   ├── AppDelegate.swift    # 菜单栏、快捷键、窗口管理
│   └── AppState.swift       # 用户偏好设置（UserDefaults）
├── Clipper/
│   ├── ClipboardManager.swift  # 剪贴板监听（Timer 轮询）
│   └── ClipboardItem.swift     # 剪贴板条目模型
├── UI/
│   ├── ClipboardWindow.swift   # 浮动窗口（NSPanel + 毛玻璃）
│   ├── ClipboardView.swift     # SwiftUI 集成入口
│   └── ClipboardRowView.swift  # 单行视图
└── Utils/
    └── LaunchAtLogin.swift    # 开机启动（SMAppService）
```

## 技术栈

- **UI**: AppKit + SwiftUI（NSVisualEffectView 毛玻璃效果）
- **全局快捷键**: [HotKey](https://github.com/soffes/HotKey)
- **剪贴板监听**: NSPasteboard + Timer
- **开机启动**: SMAppService (macOS 13+)

## 构建与安装

### 构建

```bash
# 开发构建
swift build

# Release 构建
swift build --configuration release

# 一键打包 App
./scripts/package.sh <VERSION>
# 示例: ./scripts/package.sh 1.0.0
```

### 安装

```bash
# 复制到应用程序目录
cp -R Clipboard.app /Applications/
```

## 系统要求

- macOS 10.13 (High Sierra) 或更高版本
- Apple Silicon 或 Intel 处理器
