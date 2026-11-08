import Foundation
import ServiceManagement

final class LaunchAtLoginService {
    static let shared = LaunchAtLoginService()

    private var legacyAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("gt.quintero.Docky.monterey-login.plist")
    }

    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            switch SMAppService.mainApp.status {
            case .enabled, .requiresApproval: return true
            default: return false
            }
        }
        return FileManager.default.fileExists(atPath: legacyAgentURL.path)
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if #available(macOS 13.0, *) {
                if enabled {
                    if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
                } else if SMAppService.mainApp.status != .notRegistered {
                    try SMAppService.mainApp.unregister()
                }
            } else if enabled {
                // User-level LaunchAgents are loaded by launchd on the next login.
                // Use an argument array so application paths are never shell commands.
                let agent: [String: Any] = [
                    "Label": "gt.quintero.Docky.monterey-login",
                    "ProgramArguments": ["/usr/bin/open", "-g", Bundle.main.bundleURL.path],
                    "RunAtLoad": true,
                    "LimitLoadToSessionType": "Aqua"
                ]
                let data = try PropertyListSerialization.data(fromPropertyList: agent, format: .xml, options: 0)
                try FileManager.default.createDirectory(at: legacyAgentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: legacyAgentURL, options: .atomic)
            } else if FileManager.default.fileExists(atPath: legacyAgentURL.path) {
                try FileManager.default.removeItem(at: legacyAgentURL)
            }
            return true
        } catch {
            NSLog("[Docky] Could not update login item: %@", error.localizedDescription)
            return false
        }
    }

    private init() {}
}
