import Foundation

final class AppState {
    private let launchAtLoginKey = "launchAtLogin"

    var launchAtLogin: Bool {
        get { UserDefaults.standard.bool(forKey: launchAtLoginKey) }
        set { UserDefaults.standard.set(newValue, forKey: launchAtLoginKey) }
    }
}
