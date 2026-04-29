import AppKit

// 单实例检测：通过可执行文件路径判断
let currentPath = Bundle.main.executablePath ?? ProcessInfo.processInfo.arguments.first ?? ""
let currentPID = ProcessInfo.processInfo.processIdentifier

let otherInstance = NSWorkspace.shared.runningApplications.first { app in
    guard let appPath = app.executableURL?.path else { return false }
    return app.processIdentifier != currentPID && appPath == currentPath
}

if let other = otherInstance {
    other.activate(options: [])
    NSApp.terminate(nil)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
