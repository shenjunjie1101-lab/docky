//
//  PermissionsSettingsView.swift
//  Docky
//

import SwiftUI
import Perception

struct PermissionsSettingsView: View {
    @ObservedObject private var service = PermissionsService.shared

    var body: some View {
        WithPerceptionTracking {
            Form {
                permissionSection(for: .userFolders)
                permissionSection(for: .finderAutomation)
                permissionSection(for: .accessibility)
                permissionSection(for: .screenCapture)
                permissionSection(for: .location)
                permissionSection(for: .calendar)
                permissionSection(for: .reminders)

                Section {
                    Button("Re-check Permissions") {
                        service.refresh()
                    }
                }
            }
            .dockySettingsForm()
        }
    }

    @ViewBuilder
    private func permissionSection(for permission: Permission) -> some View {
        Section(permission.title) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Status")
                        .font(.headline)

                    Spacer()

                    Text(statusText(for: permission))
                        .foregroundStyle(statusColor(for: permission))
                }

                if let grantMethod = grantMethodText(for: permission) {
                    Divider()

                    HStack {
                        Text("Access Via")
                            .font(.headline)

                        Spacer()

                        Text(grantMethod)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(permission.explanation)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button("Open System Settings") {
                        service.openSystemSettings(for: permission)
                    }

                    if permission == .finderAutomation || permission == .accessibility || permission == .screenCapture || permission == .location || permission == .calendar || permission == .reminders {
                        requestButton(for: permission)
                    }

                    if permission == .finderAutomation, service.finderAutomation != .notDetermined {
                        Button("Forget Status") {
                            service.clearAutomationStatus(for: permission)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func requestButton(for permission: Permission) -> some View {
        if permission == .finderAutomation || permission == .accessibility || permission == .screenCapture || permission == .location || permission == .calendar || permission == .reminders {
            Button(buttonTitle(for: permission)) {
                Task {
                    _ = await service.requestPermission(for: permission)
                }
            }
        }
    }

    private func statusText(for permission: Permission) -> String {
        switch service.status(for: permission) {
        case .granted: return "已授权"
        case .denied: return "未授权"
        case .notDetermined: return "尚未决定"
        }
    }

    private func statusColor(for permission: Permission) -> Color {
        switch service.status(for: permission) {
        case .granted: return .green
        case .denied: return .orange
        case .notDetermined: return .secondary
        }
    }

    private func grantMethodText(for permission: Permission) -> String? {
        switch grantMethod(for: permission) {
        case .fullDiskAccess: return "完全磁盘访问权限"
        case .automation: return "自动化"
        case .accessibility: return "辅助功能"
        case .screenCapture: return "屏幕录制"
        case .location: return "Location"
        case .none: return nil
        }
    }

    private func grantMethod(for permission: Permission) -> GrantMethod? {
        switch permission {
        case .userFolders:
            return service.userFoldersGrantMethod
        case .finderAutomation:
            return service.finderAutomationGrantMethod
        case .systemEventsAutomation:
            return service.systemEventsAutomationGrantMethod
        case .accessibility:
            return service.accessibilityGrantMethod
        case .screenCapture:
            return service.screenCaptureGrantMethod
        case .location:
            return service.locationGrantMethod
        case .calendar, .reminders:
            return nil
        }
    }

    private func buttonTitle(for permission: Permission) -> String {
        switch permission {
        case .userFolders: return String(localized: "Open System Settings")
        case .finderAutomation: return "请求访达权限"
        case .systemEventsAutomation: return "请求 System Events 权限"
        case .accessibility: return "请求辅助功能权限"
        case .screenCapture: return "请求屏幕录制权限"
        case .location: return "请求定位权限"
        case .calendar: return "请求日历权限"
        case .reminders: return "请求提醒事项权限"
        }
    }
}
