import AppKit
import Clipper
import Combine

@MainActor
public final class ClipboardWindow: NSPanel {
    private let clipboardManager: ClipboardManager
    private var scrollView: NSScrollView!
    private var stackView: NSStackView!
    private var selectedIndex: Int = 0
    private var headerView: NSView!
    private var closeButton: NSButton!
    private var clearButton: NSButton!
    private var cancellables = Set<AnyCancellable>()

    public var onPaste: ((ClipboardItem) -> Void)?
    public var onClose: (() -> Void)?
    public var onClearHistory: (() -> Void)?

    public init(clipboardManager: ClipboardManager) {
        self.clipboardManager = clipboardManager

        let windowRect = Self.calculateWindowRect()
        super.init(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isFloatingPanel = true
        self.becomesKeyOnlyIfNeeded = false
        self.hidesOnDeactivate = false
        self.backgroundColor = .clear  // 使用 NSVisualEffectView 背景
        self.isOpaque = false
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        // 隐藏标题栏按钮
        if let closeButton = self.standardWindowButton(.closeButton) {
            closeButton.isHidden = true
        }
        if let miniButton = self.standardWindowButton(.miniaturizeButton) {
            miniButton.isHidden = true
        }
        if let zoomButton = self.standardWindowButton(.zoomButton) {
            zoomButton.isHidden = true
        }

        setupContentView()
    }

    private static func calculateWindowRect() -> NSRect {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let windowWidth: CGFloat = 400
        let windowHeight: CGFloat = min(400, screenFrame.height * 0.5)
        // 右下角，距离屏幕底部 20px
        let windowX = screenFrame.maxX - windowWidth - 20
        let windowY = screenFrame.minY + 20
        return NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight)
    }

    private func setupContentView() {
        // 使用 NSVisualEffectView 实现自动适配浅色/深色背景
        let visualEffectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: frame.width, height: frame.height))
        visualEffectView.material = .popover
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 10
        visualEffectView.layer?.masksToBounds = true

        // 顶部标题栏区域
        headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false

        // 关闭按钮
        closeButton = NSButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .circular
        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "关闭")
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.target = self
        closeButton.action = #selector(closeButtonClicked)
        headerView.addSubview(closeButton)

        // 清空历史按钮
        clearButton = NSButton()
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.bezelStyle = .circular
        clearButton.isBordered = false
        clearButton.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "清空历史")
        clearButton.contentTintColor = .secondaryLabelColor
        clearButton.target = self
        clearButton.action = #selector(clearButtonClicked)
        headerView.addSubview(clearButton)

        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 12
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.documentView = stackView
        visualEffectView.addSubview(headerView)
        visualEffectView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            // headerView 高度固定
            headerView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 36),

            // 关闭按钮（左上角）
            closeButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 3),
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),

            // 清空按钮（右上角，与关闭按钮对称）
            clearButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -3),
            clearButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 30),
            clearButton.heightAnchor.constraint(equalToConstant: 30),

            // scrollView 布局
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor, constant: -12),

            // stackView 宽度
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -15),
        ])

        contentView = visualEffectView
    }

    @objc private func closeButtonClicked() {
        onClose?()
        close()
    }

    @objc private func clearButtonClicked() {
        onClearHistory?()
    }

    public func showWindow() {
        refreshItems()
        selectItem(at: 0)
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        setupBindings()
        scrollToTop()
    }

    private func scrollToTop() {
        guard let documentView = scrollView.documentView else { return }
        documentView.layoutSubtreeIfNeeded()
        let minY = documentView.bounds.height - scrollView.bounds.height
        let topPoint = NSPoint(x: 0, y: max(0, minY))
        scrollView.contentView.scroll(to: topPoint)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func setupBindings() {
        clipboardManager.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshItems()
            }
            .store(in: &cancellables)
    }

    public func refreshItems() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for (index, item) in clipboardManager.items.enumerated() {
            let rowView = ClipboardRowView(item: item, isSelected: index == selectedIndex)
            rowView.onClick = { [weak self] in
                self?.handleSelect(at: index)
            }
            rowView.translatesAutoresizingMaskIntoConstraints = false
            stackView.addArrangedSubview(rowView)

            NSLayoutConstraint.activate([
                rowView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
                rowView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            ])

            // 设置 hugging priority 让行视图可以根据内容调整高度
            rowView.setContentHuggingPriority(.defaultLow, for: .vertical)
            rowView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        }
    }

    private func selectItem(at index: Int) {
        guard index >= 0, index < clipboardManager.items.count else { return }
        selectedIndex = index

        for (i, view) in stackView.arrangedSubviews.enumerated() {
            if let rowView = view as? ClipboardRowView {
                rowView.setSelected(i == selectedIndex)
            }
        }

        if let rowView = stackView.arrangedSubviews[selectedIndex] as? ClipboardRowView {
            rowView.scrollToVisible(rowView.frame)
        }
    }

    private func handleSelect(at index: Int) {
        guard index >= 0, index < clipboardManager.items.count else { return }
        let item = clipboardManager.items[index]
        onPaste?(item)
        close()
    }

    override public func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 125: // Down arrow
            selectItem(at: min(selectedIndex + 1, clipboardManager.items.count - 1))
        case 126: // Up arrow
            selectItem(at: max(selectedIndex - 1, 0))
        case 36: // Enter
            handleSelect(at: selectedIndex)
        case 53: // Escape
            close()
        default:
            super.keyDown(with: event)
        }
    }

    override public var canBecomeKey: Bool { true }
}
