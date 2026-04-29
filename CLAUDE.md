# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
swift build        # Build the package
swift run          # Run the executable (菜单栏应用)
swift build --configuration release  # Release build
```

## Project Structure

这是一个 macOS 菜单栏剪切板管理器应用。

### 目录结构

```
Sources/
├── App/
│   ├── main.swift          # 应用入口
│   ├── AppDelegate.swift    # 应用代理（菜单栏 + 快捷键）
│   └── AppState.swift       # 应用状态（UserDefaults）
├── Clipper/
│   ├── ClipboardManager.swift  # 剪贴板监听（Timer 轮询 NSPasteboard）
│   └── ClipboardItem.swift      # 剪切板条目模型（文本/图片）
├── UI/
│   ├── ClipboardWindow.swift   # 浮动窗口（NSPanel，毛玻璃效果）
│   ├── ClipboardView.swift     # 预留 SwiftUI 集成
│   └── ClipboardRowView.swift  # 单行视图（图标 + 文字 + 时间）
└── Utils/
    └── LaunchAtLogin.swift     # 开机启动（SMAppService）
```

### 核心模块

- **ClipboardManager**: 使用 Timer 每 0.5s 检查 `NSPasteboard.general.changeCount` 变化
- **ClipboardWindow**: `NSPanel` 浮动面板，`level = .floating`，背景使用 `NSVisualEffectView` 毛玻璃
- **HotKey**: 使用 [HotKey](https://github.com/soffes/HotKey) 库注册全局快捷键 `Control + Shift + V`
- **LaunchAtLogin**: 使用 `SMAppService.mainApp.register()` (macOS 13+)

### 依赖

- [HotKey](https://github.com/soffes/HotKey) - 全局快捷键框架（SPM）

## 运行说明

应用启动后在菜单栏显示图标，点击或按 `Control + Shift + V` 弹出剪切板窗口。
