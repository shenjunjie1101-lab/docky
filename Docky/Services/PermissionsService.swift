//
//  PermissionsService.swift
//  Docky
//
//  Tracks the remaining macOS permissions Docky needs:
//    - .userFolders       → Full Disk Access for pinned folder previews
//    - .finderAutomation       → Finder Apple Events for Finder-backed actions
//    - .accessibility          → inspect and restore minimized windows
//    - .systemEventsAutomation → System Events Apple Events for menu-click actions
//    - .screenCapture     → minimized window previews
//
//  Required file-system access is granted through Full Disk Access (FDA),
//  probed via an attempted read of a TCC-protected directory
//  (inket/FullDiskAccess approach).
//

import AppKit
import ApplicationServices
import Combine
import CoreLocation

enum PermissionStatus {
    case granted
    case denied
    case notDetermined
}

enum GrantMethod {
    case fullDiskAccess
    case automation
    case accessibility
    case screenCapture
    case location
}

enum Permission: String, CaseIterable, Identifiable {
    case userFolders
    case finderAutomation
    case accessibility
    case systemEventsAutomation
    case screenCapture
    case location
    case calendar
    case reminders

    var id: String { rawValue }

    var title: String {
        switch self {
        case .userFolders: return "完全磁盘访问权限"
        case .finderAutomation: return "自动化（访达）"
        case .accessibility: return "辅助功能"
        case .systemEventsAutomation: return "自动化（System Events）"
        case .screenCapture: return "屏幕录制"
        case .location: return String(localized: "Location")
        case .calendar: return String(localized: "Calendar")
        case .reminders: return String(localized: "Reminders")
        }
    }

    var explanation: String {
        switch self {
        case .userFolders:
            return "授予完全磁盘访问权限，以便 Docky 预览固定文件夹中的最近项目，包括“下载”“文稿”和“桌面”等受保护位置。相关文件不会上传。"
        case .finderAutomation:
            return "Docky 通过访达自动化执行“在访达中显示”、打开文件夹和废纸篓操作。此权限与完全磁盘访问权限分开授予，可以直接在这里请求，无需等首次操作失败后再授权。"
        case .accessibility:
            return "辅助功能权限用于执行预设菜单点击操作、读取应用窗口、显示窗口菜单，以及恢复最小化窗口。这些操作比内置命令更慢，也更容易受系统或应用变化影响，因此仅在需要时请求权限。"
        case .systemEventsAutomation:
            return "Docky 通过 System Events 自动化执行预设菜单点击操作。可以在这里提前授权，无需等首次操作触发系统提示。菜单点击操作还需要辅助功能权限。"
        case .screenCapture:
            return "授予屏幕录制权限，以便 Docky 显示最小化窗口的缩略图。预览在本机生成，不会上传。授权后，macOS 可能要求退出并重新打开 Docky。"
        case .location:
            return "授予定位权限，以便天气小组件显示本地天气。位置信息仅用于查询天气，Docky 不会保存你的位置。"
        case .calendar:
            return "授予日历权限，以便日历小组件显示即将开始的日程。日程仅在本机读取，不会上传。"
        case .reminders:
            return "授予提醒事项权限，以便小组件显示未完成任务。提醒事项仅在本机读取，不会上传。"
        }
    }

    var systemSettingsURL: URL? {
        switch self {
        case .userFolders:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
        case .finderAutomation:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
        case .systemEventsAutomation:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
        case .accessibility:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .screenCapture:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        case .location:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")
        case .calendar:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
        case .reminders:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders")
        }
    }

    var isRequiredAtLaunch: Bool {
        switch self {
        case .userFolders:
            return true
        case .finderAutomation:
            return false
        case .systemEventsAutomation:
            return false
        case .accessibility:
            return true
        case .screenCapture:
            return false
        case .location:
            return false
        case .calendar:
            return false
        case .reminders:
            return false
        }
    }

    /// Whether this permission is surfaced during the initial onboarding
    /// flow. Widget-tied permissions (calendar, reminders, location) are
    /// requested lazily from the widget itself the first time it renders,
    /// so they never appear in onboarding; only app-feature permissions do.
    var appearsInOnboarding: Bool {
        switch self {
        case .userFolders, .finderAutomation, .accessibility, .systemEventsAutomation, .screenCapture:
            return true
        case .location, .calendar, .reminders:
            return false
        }
    }
}

final class PermissionsService: ObservableObject {
    static let shared = PermissionsService()

    @Published private(set) var userFolders: PermissionStatus = .notDetermined
    @Published private(set) var userFoldersGrantMethod: GrantMethod?

    @Published private(set) var finderAutomation: PermissionStatus = .notDetermined
    @Published private(set) var finderAutomationGrantMethod: GrantMethod?

    @Published private(set) var accessibility: PermissionStatus = .notDetermined
    @Published private(set) var accessibilityGrantMethod: GrantMethod?

    @Published private(set) var systemEventsAutomation: PermissionStatus = .notDetermined
    @Published private(set) var systemEventsAutomationGrantMethod: GrantMethod?

    @Published private(set) var screenCapture: PermissionStatus = .notDetermined
    @Published private(set) var screenCaptureGrantMethod: GrantMethod?

    @Published private(set) var location: PermissionStatus = .notDetermined
    @Published private(set) var locationGrantMethod: GrantMethod?

    @Published private(set) var calendar: PermissionStatus = .notDetermined
    @Published private(set) var reminders: PermissionStatus = .notDetermined

    private let dockBookmarkKey = "docky.dockPlistBookmark"
    private let userFoldersBookmarkKey = "docky.userFoldersBookmark"
    private let finderAutomationStatusKey = "docky.finderAutomationStatus"
    private let systemEventsAutomationStatusKey = "docky.systemEventsAutomationStatus"
    private let initialOnboardingCompletedKey = "docky.initialOnboardingCompleted"
    private let skippedPermissionsKey = "docky.skippedPermissions"

    private init() {
        clearLegacyBookmarks()
        refresh()
    }

    // MARK: - Status

    func status(for permission: Permission) -> PermissionStatus {
        switch permission {
        case .userFolders: return userFolders
        case .finderAutomation: return finderAutomation
        case .accessibility: return accessibility
        case .systemEventsAutomation: return systemEventsAutomation
        case .screenCapture: return screenCapture
        case .location: return location
        case .calendar: return calendar
        case .reminders: return reminders
        }
    }

    var missingPermissions: [Permission] {
        Permission.allCases.filter { status(for: $0) != .granted }
    }

    var missingRequiredPermissions: [Permission] {
        Permission.allCases.filter { $0.isRequiredAtLaunch && status(for: $0) != .granted }
    }

    var setupPermissions: [Permission] {
        Permission.allCases.filter {
            guard $0.appearsInOnboarding else {
                return false
            }

            if hasSkippedPermission($0) {
                return false
            }

            if $0.isRequiredAtLaunch {
                return status(for: $0) != .granted
            }

            if hasCompletedInitialOnboarding {
                return false
            }

            return status(for: $0) == .notDetermined
        }
    }

    var allGranted: Bool { missingPermissions.isEmpty }

    var allRequiredGranted: Bool { missingRequiredPermissions.isEmpty }

    var setupComplete: Bool { setupPermissions.isEmpty }

    var hasCompletedInitialOnboarding: Bool {
        UserDefaults.standard.bool(forKey: initialOnboardingCompletedKey)
    }

    func refresh() {
        let fdaGranted = checkFullDiskAccess()
        refreshUserFolders(fdaGranted: fdaGranted)
        refreshFinderAutomation()
        refreshAccessibility()
        refreshSystemEventsAutomation()
        refreshScreenCapture()
        refreshLocation()
        refreshCalendar()
        refreshReminders()
    }

    func markInitialOnboardingCompleted() {
        UserDefaults.standard.set(true, forKey: initialOnboardingCompletedKey)
    }

    func markPermissionSkipped(_ permission: Permission) {
        var skippedPermissions = skippedPermissionIDs
        skippedPermissions.insert(permission.rawValue)
        UserDefaults.standard.set(Array(skippedPermissions), forKey: skippedPermissionsKey)
    }

    func hasSkippedPermission(_ permission: Permission) -> Bool {
        skippedPermissionIDs.contains(permission.rawValue)
    }

    // MARK: - Grant actions

    private var skippedPermissionIDs: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: skippedPermissionsKey) ?? [])
    }

    func openSystemSettings(for permission: Permission) {
        guard let url = permission.systemSettingsURL else { return }
        NSWorkspace.shared.open(url)
    }

    func requestPermission(for permission: Permission) async -> Bool {
        switch permission {
        case .finderAutomation:
            return await AppleScriptService.shared.requestFinderAutomationPermission()
        case .accessibility:
            return requestAccessibilityPermission(prompt: true)
        case .systemEventsAutomation:
            return await AppleScriptService.shared.requestSystemEventsAutomationPermission()
        case .screenCapture:
            return requestScreenCapturePermission()
        case .location:
            let granted = await WeatherService.shared.requestAccess()
            refreshLocation()
            return granted
        case .calendar:
            let granted = await CalendarService.shared.requestAccess()
            refreshCalendar()
            return granted
        case .reminders:
            let granted = await RemindersService.shared.requestAccess()
            refreshReminders()
            return granted
        case .userFolders:
            return false
        }
    }

    func clearAutomationStatus(for permission: Permission) {
        switch permission {
        case .finderAutomation:
            UserDefaults.standard.removeObject(forKey: finderAutomationStatusKey)
            refreshFinderAutomation()
        case .systemEventsAutomation:
            UserDefaults.standard.removeObject(forKey: systemEventsAutomationStatusKey)
            refreshSystemEventsAutomation()
        case .userFolders, .accessibility, .screenCapture, .location, .calendar, .reminders:
            break
        }
    }

    @discardableResult
    func requestAccessibilityPermission(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        let granted = AXIsProcessTrustedWithOptions(options)
        refreshAccessibility()
        return granted
    }

    @discardableResult
    func requestScreenCapturePermission() -> Bool {
        let granted = CGRequestScreenCaptureAccess()
        refreshScreenCapture()
        return granted
    }

    func presentPermissionAlert(for permission: Permission, actionTitle: String) {
        let alert = NSAlert()
        alert.messageText = permission.title + "尚未开启"
        alert.informativeText = "请在“系统偏好设置 → 安全性与隐私 → 隐私”中允许 Docky，以便执行“\(actionTitle.lowercased())”。"
        alert.addButton(withTitle: String(localized: "Open System Settings"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        if alert.runModal() == .alertFirstButtonReturn {
            openSystemSettings(for: permission)
        }
    }

    // MARK: - User folders permission

    private func refreshUserFolders(fdaGranted: Bool) {
        if fdaGranted {
            userFoldersGrantMethod = .fullDiskAccess
            userFolders = .granted
            return
        }
        userFoldersGrantMethod = nil
        userFolders = .denied
    }

    // MARK: - Finder automation permission

    func updateFinderAutomation(status: PermissionStatus) {
        switch status {
        case .granted:
            UserDefaults.standard.set("granted", forKey: finderAutomationStatusKey)
            finderAutomationGrantMethod = .automation
        case .denied:
            UserDefaults.standard.set("denied", forKey: finderAutomationStatusKey)
            finderAutomationGrantMethod = nil
        case .notDetermined:
            UserDefaults.standard.removeObject(forKey: finderAutomationStatusKey)
            finderAutomationGrantMethod = nil
        }
        finderAutomation = status
    }

    private func refreshFinderAutomation() {
        switch UserDefaults.standard.string(forKey: finderAutomationStatusKey) {
        case "granted":
            finderAutomation = .granted
            finderAutomationGrantMethod = .automation
        case "denied":
            finderAutomation = .denied
            finderAutomationGrantMethod = nil
        default:
            finderAutomation = .notDetermined
            finderAutomationGrantMethod = nil
        }
    }

    func updateSystemEventsAutomation(status: PermissionStatus) {
        switch status {
        case .granted:
            UserDefaults.standard.set("granted", forKey: systemEventsAutomationStatusKey)
            systemEventsAutomationGrantMethod = .automation
        case .denied:
            UserDefaults.standard.set("denied", forKey: systemEventsAutomationStatusKey)
            systemEventsAutomationGrantMethod = nil
        case .notDetermined:
            UserDefaults.standard.removeObject(forKey: systemEventsAutomationStatusKey)
            systemEventsAutomationGrantMethod = nil
        }
        systemEventsAutomation = status
    }

    private func refreshSystemEventsAutomation() {
        switch UserDefaults.standard.string(forKey: systemEventsAutomationStatusKey) {
        case "granted":
            systemEventsAutomation = .granted
            systemEventsAutomationGrantMethod = .automation
        case "denied":
            systemEventsAutomation = .denied
            systemEventsAutomationGrantMethod = nil
        default:
            systemEventsAutomation = .notDetermined
            systemEventsAutomationGrantMethod = nil
        }
    }

    private func refreshAccessibility() {
        let granted = AXIsProcessTrusted()
        accessibility = granted ? .granted : .denied
        accessibilityGrantMethod = granted ? .accessibility : nil
    }

    private func refreshScreenCapture() {
        let granted = CGPreflightScreenCaptureAccess()
        screenCapture = granted ? .granted : .denied
        screenCaptureGrantMethod = granted ? .screenCapture : nil
    }

    private func refreshLocation() {
        WeatherService.shared.refreshAuthorizationStatus()

        if WeatherService.shared.hasLocationAuthorization {
            location = .granted
            locationGrantMethod = .location
            return
        }

        switch WeatherService.shared.authorizationStatus {
        case .notDetermined:
            location = .notDetermined
            locationGrantMethod = nil
        case .denied, .restricted:
            location = .denied
            locationGrantMethod = nil
        case .authorizedAlways:
            location = .granted
            locationGrantMethod = .location
        @unknown default:
            location = .denied
            locationGrantMethod = nil
        }
    }

    private func refreshCalendar() {
        CalendarService.shared.refreshAuthorizationStatus()
        calendar = CalendarService.shared.permissionStatus
    }

    private func refreshReminders() {
        RemindersService.shared.refreshAuthorizationStatus()
        reminders = RemindersService.shared.permissionStatus
    }

    // MARK: - Full Disk Access probe

    private func checkFullDiskAccess() -> Bool {
        let probePath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.apple.stocks")
            .path
        do {
            _ = try FileManager.default.contentsOfDirectory(atPath: probePath)
            return true
        } catch {
            return false
        }
    }

    private func clearLegacyBookmarks() {
        UserDefaults.standard.removeObject(forKey: dockBookmarkKey)
        UserDefaults.standard.removeObject(forKey: userFoldersBookmarkKey)
    }
}
