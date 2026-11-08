import AppKit
import SwiftUI

/// Invoked only by the explicit CI command-line flag, before normal startup.
@MainActor
func runChineseLocalizationSmokeTest() throws {
    func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw NSError(domain: "Docky.LocalizationQA", code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    try require(Bundle.main.preferredLocalizations.first == "zh-Hans", "Chinese was not selected")
    try require(String(localized: "Settings") == "设置", "Settings translation missing")
    try require(String(localized: "Window Switcher") == "窗口切换器", "Window switcher translation missing")
    let step = String(format: NSLocalizedString("Step %lld of %lld", comment: ""), Int64(2), Int64(3))
    try require(step == "第 2 步，共 3 步", "Dynamic placeholder translation failed: \(step)")
    let calendarUsage = Bundle.main.localizedInfoDictionary?["NSCalendarsUsageDescription"] as? String ?? ""
    try require(calendarUsage.contains("日历"), "Localized permission explanation missing")

    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    app.finishLaunching()
    let destination = URL(fileURLWithPath: "dist/localization-preview", isDirectory: true)
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    for pane in ["profiles", "appearanceGeneral", "appearanceWindowBackground", "behaviorGeneral", "externalWidgets", "permissions", "updates"] {
        SettingsNavigator.shared.pendingPaneID = pane
        let controller = SettingsWindowController()
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(1.5))
        guard let view = controller.window?.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw NSError(domain: "Docky.LocalizationQA", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Could not render \(pane)"])
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "Docky.LocalizationQA", code: 3)
        }
        try png.write(to: destination.appendingPathComponent("\(pane).png"))
        controller.close()
    }
    print("Chinese localization, formatted placeholders, permission strings and seven UI previews passed")
}
