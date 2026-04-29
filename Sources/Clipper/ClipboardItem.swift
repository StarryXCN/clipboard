import AppKit
import Carbon

/// 存储单个类型的内容数据
public struct ClipboardContent: Equatable {
    public let type: NSPasteboard.PasteboardType
    public let data: Data

    public init(type: NSPasteboard.PasteboardType, data: Data) {
        self.type = type
        self.data = data
    }
}

/// 显示类型，用于 UI 展示
public enum ClipboardDisplayType: Equatable {
    case text(String)
    case image
    case file(url: String)
    case html
    case rtf
    case unknown
}

public final class ClipboardItem: Identifiable, Equatable {
    public let id: UUID
    public let contents: [ClipboardContent]
    public let timestamp: Date

    public init(contents: [ClipboardContent]) {
        self.id = UUID()
        self.contents = contents
        self.timestamp = Date()
    }

    public var displayType: ClipboardDisplayType {
        if let textContent = contents.first(where: { $0.type == .string }),
           let text = String(data: textContent.data, encoding: .utf8), !text.isEmpty {
            return .text(text.prefix(300).replacingOccurrences(of: "\n", with: " "))
        }
        if contents.contains(where: { $0.type == .tiff || $0.type == .png }) {
            return .image
        }
        if let fileContent = contents.first(where: { $0.type == .fileURL }),
           let url = String(data: fileContent.data, encoding: .utf8) {
            return .file(url: url)
        }
        if contents.contains(where: { $0.type == .html }) {
            return .html
        }
        if contents.contains(where: { $0.type == .rtf }) {
            return .rtf
        }
        return .unknown
    }

    public var displayText: String {
        switch displayType {
        case .text(let text):
            return text
        case .image:
            return "[图片]"
        case .file(let url):
            return URL(fileURLWithPath: url).lastPathComponent
        case .html:
            return "[HTML]"
        case .rtf:
            return "[RTF]"
        case .unknown:
            return "[未知类型]"
        }
    }

    public var icon: NSImage? {
        switch displayType {
        case .text:
            return NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
        case .image:
            return NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
        case .file:
            return NSImage(systemSymbolName: "doc", accessibilityDescription: nil)
        case .html:
            return NSImage(systemSymbolName: "doc.richtext", accessibilityDescription: nil)
        case .rtf:
            return NSImage(systemSymbolName: "doc.richtext", accessibilityDescription: nil)
        case .unknown:
            return NSImage(systemSymbolName: "questionmark.square", accessibilityDescription: nil)
        }
    }

    public var thumbnail: NSImage? {
        switch displayType {
        case .image:
            if let imageData = contents.first(where: { $0.type == .tiff || $0.type == .png })?.data,
               let image = NSImage(data: imageData) {
                return generateThumbnail(from: image)
            }
            return nil
        default:
            return nil
        }
    }

    private func generateThumbnail(from image: NSImage) -> NSImage? {
        let targetSize = NSSize(width: 60, height: 36)
        let thumbnail = NSImage(size: targetSize)
        thumbnail.lockFocus()
        let aspectRatio = image.size.width / image.size.height
        var drawRect: NSRect
        if aspectRatio > targetSize.width / targetSize.height {
            drawRect = NSRect(x: 0, y: (targetSize.height - targetSize.width / aspectRatio) / 2,
                              width: targetSize.width, height: targetSize.width / aspectRatio)
        } else {
            drawRect = NSRect(x: (targetSize.width - targetSize.height * aspectRatio) / 2, y: 0,
                              width: targetSize.height * aspectRatio, height: targetSize.height)
        }
        image.draw(in: drawRect, from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1.0)
        thumbnail.unlockFocus()
        return thumbnail
    }

    public func data(for type: NSPasteboard.PasteboardType) -> Data? {
        return contents.first(where: { $0.type == type })?.data
    }

    public var textContent: String? {
        guard let data = data(for: .string) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public var imageData: Data? {
        return data(for: .tiff) ?? data(for: .png)
    }

    @MainActor
    public func paste(targetApp: NSRunningApplication?) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let types = contents.map { $0.type }
        pasteboard.declareTypes(types, owner: nil)

        for content in contents {
            pasteboard.setData(content.data, forType: content.type)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.simulatePaste(targetApp: targetApp)
        }
    }

    @MainActor
    private func simulatePaste(targetApp: NSRunningApplication?) {
        guard checkAccessibilityPermission() else {
            promptAccessibilityPermission()
            return
        }

        if let app = targetApp {
            app.activate(options: [])
        }

        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true) else {
            return
        }
        keyDown.flags = CGEventFlags.maskCommand
        keyDown.post(tap: CGEventTapLocation.cghidEventTap)

        guard let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) else {
            return
        }
        keyUp.flags = CGEventFlags.maskCommand
        keyUp.post(tap: CGEventTapLocation.cghidEventTap)
    }

    private func checkAccessibilityPermission() -> Bool {
        return _checkAccessibilityPermission(prompt: false)
    }

    private func promptAccessibilityPermission() {
        _ = _checkAccessibilityPermission(prompt: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let alert = NSAlert()
            alert.messageText = "需要辅助功能权限"
            alert.informativeText = "粘贴功能需要辅助功能权限。请在系统设置 > 隐私与安全性 > 辅助功能中允许此应用。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "取消")

            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}

private func _checkAccessibilityPermission(prompt: Bool) -> Bool {
    let promptKey = "AXTrustedCheckOptionPrompt"
    let options = [promptKey as String: prompt] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}

public extension ClipboardItem {
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }
}
