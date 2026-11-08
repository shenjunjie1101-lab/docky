import Combine
import Foundation

/// Upstream updates require a newer OS and would replace this compatibility build.
final class AppUpdateService: ObservableObject {
    static let shared = AppUpdateService()
    @Published private(set) var canCheckForUpdates = false
    private init() {}
    func checkForUpdates() {}
    func checkForUpdatesInBackground() {}
}
