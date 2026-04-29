import AppKit
import Clipper

@MainActor
final class ClipboardRowView: NSView {
    private let item: ClipboardItem
    private var isItemSelected: Bool = false

    private var iconImageView: NSImageView!
    private var textLabel: NSTextField!
    private var timeLabel: NSTextField!

    var onClick: (() -> Void)?

    init(item: ClipboardItem, isSelected: Bool) {
        self.item = item
        self.isItemSelected = isSelected
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8  // 圆角边框
        setupViews()
        updateSelection()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        iconImageView = NSImageView()
        iconImageView.image = item.icon
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        textLabel = NSTextField(labelWithString: item.displayText)
        textLabel.font = NSFont.systemFont(ofSize: 13)
        textLabel.textColor = .labelColor
        textLabel.lineBreakMode = .byWordWrapping
        textLabel.maximumNumberOfLines = 4  // 最多显示4行
        textLabel.cell?.usesSingleLineMode = false
        textLabel.setContentHuggingPriority(.defaultLow, for: .vertical)
        textLabel.translatesAutoresizingMaskIntoConstraints = false

        // 设置 preferredMaxLayoutWidth 让 maximumNumberOfLines 生效
        textLabel.preferredMaxLayoutWidth = 280

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        timeLabel = NSTextField(labelWithString: dateFormatter.string(from: item.timestamp))
        timeLabel.font = NSFont.systemFont(ofSize: 10)
        timeLabel.textColor = .secondaryLabelColor
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconImageView)
        addSubview(textLabel)
        addSubview(timeLabel)

        if case .image = item.displayType, let thumbnail = item.thumbnail {
            let thumbnailView = NSImageView()
            thumbnailView.image = thumbnail
            thumbnailView.imageScaling = .scaleProportionallyUpOrDown
            thumbnailView.translatesAutoresizingMaskIntoConstraints = false
            thumbnailView.wantsLayer = true
            thumbnailView.layer?.cornerRadius = 4
            thumbnailView.layer?.masksToBounds = true
            thumbnailView.layer?.borderWidth = 0  // 不要边框
            addSubview(thumbnailView)

            // 图片项隐藏文本标签
            textLabel.isHidden = true

            NSLayoutConstraint.activate([
                heightAnchor.constraint(equalToConstant: 100),

                iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
                iconImageView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
                iconImageView.widthAnchor.constraint(equalToConstant: 20),
                iconImageView.heightAnchor.constraint(equalToConstant: 20),

                // 图片预览左对齐，固定宽度，位于上半部分
                thumbnailView.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
                thumbnailView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
                thumbnailView.widthAnchor.constraint(equalToConstant: 120),
                thumbnailView.heightAnchor.constraint(equalToConstant: 72),

                // 时间放在左下角，与图片预览保持上下间距
                timeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
                timeLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
                timeLabel.widthAnchor.constraint(equalToConstant: 60),
            ])
        } else {
            // 文本项：与图片项高度保持一致（80）
            NSLayoutConstraint.activate([
                heightAnchor.constraint(equalToConstant: 100),

                iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
                iconImageView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
                iconImageView.widthAnchor.constraint(equalToConstant: 20),
                iconImageView.heightAnchor.constraint(equalToConstant: 20),

                textLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
                textLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
                textLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
                textLabel.heightAnchor.constraint(lessThanOrEqualToConstant: 72),

                // 时间放在左下角，与文本元素保持上下间距
                timeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
                timeLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
                timeLabel.widthAnchor.constraint(equalToConstant: 60),
            ])
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInActiveApp, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    func setSelected(_ selected: Bool) {
        isItemSelected = selected
        updateSelection()
    }

    private func updateSelection() {
        if isItemSelected {
            layer?.backgroundColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.5).cgColor
            layer?.borderColor = NSColor.selectedContentBackgroundColor.cgColor
            layer?.borderWidth = 1.5
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
            layer?.borderColor = NSColor.separatorColor.cgColor
            layer?.borderWidth = 0.5
        }
    }

    override func mouseEntered(with event: NSEvent) {
        if !isItemSelected {
            layer?.backgroundColor = NSColor.hoverColor.withAlphaComponent(0.3).cgColor
            layer?.borderColor = NSColor.secondaryLabelColor.cgColor
            layer?.borderWidth = 0.5
        }
    }

    override func mouseExited(with event: NSEvent) {
        updateSelection()
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}

extension NSColor {
    // 支持浅色/深色外观的悬停色
    static var hoverColor: NSColor {
        // 使用 controlAccentColor 的浅色版本，在浅色和深色模式下都可见
        return NSColor.controlAccentColor.withAlphaComponent(0.15)
    }
}
