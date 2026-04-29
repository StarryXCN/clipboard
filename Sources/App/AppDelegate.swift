import AppKit
import HotKey
import Clipper
import UI
import Utils

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotKey: HotKey?
    private var clipboardWindow: ClipboardWindow?
    private let clipboardManager = ClipboardManager()
    private let appState = AppState()
    private var previousFrontmostApp: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        syncLaunchAtLoginState()
        setupStatusItem()
        setupHotKey()
        setupClipboardWindow()
        clipboardManager.startMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardManager.stopMonitoring()
        clipboardManager.clearItems()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard")
        button.action = #selector(statusItemClicked)
        button.target = self

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示剪切板", action: #selector(showClipboard), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        let launchItem = NSMenuItem(title: "开机启动", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.state = appState.launchAtLogin ? .on : .off
        menu.addItem(launchItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func setupHotKey() {
        hotKey = HotKey(key: .v, modifiers: [.control, .shift])
        hotKey?.keyDownHandler = { [weak self] in
            Task { @MainActor in
                self?.showClipboard()
            }
        }
    }

    private func setupClipboardWindow() {
        clipboardWindow = ClipboardWindow(clipboardManager: clipboardManager)
        clipboardWindow?.onPaste = { [weak self] item in
            self?.pasteItem(item)
        }
        clipboardWindow?.onClose = { [weak self] in
            self?.clipboardWindow?.close()
        }
        clipboardWindow?.onClearHistory = { [weak self] in
            self?.clipboardManager.clearItems()
            self?.clipboardWindow?.refreshItems()
        }
    }

    @objc private func statusItemClicked() {
        showClipboard()
    }

    @objc private func showClipboard() {
        previousFrontmostApp = NSWorkspace.shared.frontmostApplication
        clipboardWindow?.showWindow()
    }

    private func pasteItem(_ item: ClipboardItem) {
        let targetApp = previousFrontmostApp
        clipboardWindow?.close()

        clipboardManager.pauseMonitoring()

        item.paste(targetApp: targetApp)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.clipboardManager.resumeMonitoring()
        }
    }

    private func syncLaunchAtLoginState() {
        let actualState = LaunchAtLogin.isEnabled
        if appState.launchAtLogin != actualState {
            appState.launchAtLogin = actualState
        }
    }

    @objc private func toggleLaunchAtLogin() {
        let newValue = !appState.launchAtLogin
        appState.launchAtLogin = newValue
        LaunchAtLogin.setEnabled(newValue)
        statusItem.menu?.item(at: 2)?.state = newValue ? .on : .off
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
