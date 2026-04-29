import AppKit
import Combine

@MainActor
public final class ClipboardManager: ObservableObject {
    @Published public private(set) var items: [ClipboardItem] = []

    private var lastChangeCount: Int = 0
    private var timer: Timer?
    private let maxItems = 50
    private var isPaused = false

    private let dynamicTypePrefix = "dyn."
    private let microsoftSourcePrefix = "com.microsoft.ole.source."

    private let supportedTypes: Set<NSPasteboard.PasteboardType> = [
        .fileURL,
        .html,
        .png,
        .rtf,
        .string,
        .tiff
    ]

    public init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    public func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkClipboard()
            }
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    public func clearItems() {
        items.removeAll()
    }

    public func pauseMonitoring() {
        isPaused = true
    }

    public func resumeMonitoring() {
        isPaused = false
        lastChangeCount = NSPasteboard.general.changeCount
    }

    private func checkClipboard() {
        guard !isPaused else { return }

        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount

        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard let types = pasteboard.types, !types.isEmpty else { return }

        if shouldIgnoreTypes(Set(types)) {
            return
        }

        var allContents: [ClipboardContent] = []

        pasteboard.pasteboardItems?.forEach { item in
            var itemTypes = Set(item.types)

            if let string = item.string(forType: .string), string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                itemTypes.remove(.string)
            }

            itemTypes = itemTypes
                .filter { !$0.rawValue.hasPrefix(dynamicTypePrefix) }
                .filter { !$0.rawValue.hasPrefix(microsoftSourcePrefix) }

            itemTypes = itemTypes.intersection(supportedTypes)

            for type in itemTypes {
                if let data = item.data(forType: type) {
                    allContents.append(ClipboardContent(type: type, data: data))
                }
            }
        }

        guard !allContents.isEmpty else { return }

        if let lastItem = items.first, lastItem.contents == allContents {
            return
        }

        let item = ClipboardItem(contents: allContents)
        items.insert(item, at: 0)
        if items.count > maxItems {
            items.removeLast()
        }
    }

    private func shouldIgnoreTypes(_ types: Set<NSPasteboard.PasteboardType>) -> Bool {
        return types.isDisjoint(with: supportedTypes)
    }
}
