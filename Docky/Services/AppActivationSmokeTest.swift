import AppKit

/// Native application-switching regression, invoked only by the CI flag.
@MainActor
func runAppActivationSmokeTest() throws {
    func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() {
            throw NSError(domain: "Docky.ActivationQA", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
    func waitUntil(timeout: TimeInterval = 8, _ condition: () -> Bool) -> Bool {
        let limit = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        } while Date() < limit
        return condition()
    }
    func launch(_ bundleID: String) throws -> NSRunningApplication {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            throw NSError(domain: "Docky.ActivationQA", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Missing standard application: \(bundleID)"])
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration, completionHandler: nil)
        try require(waitUntil(timeout: 20) {
            NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .contains { $0.isFinishedLaunching }
        }, "Application did not launch: \(bundleID)")
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first!
    }

    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    app.finishLaunching()

    // macOS 15 no longer honors this legacy flag; verify its construction
    // explicitly here while retaining native switching tests on the CI OS.
    let legacy = NSRunningApplication.legacyDockActivationOptions([.activateAllWindows])
    try require(legacy.contains(.activateIgnoringOtherApps) && legacy.contains(.activateAllWindows),
                "Monterey foreground activation options are incomplete")
    try require(NSRunningApplication.legacyDockActivationOptions([]).contains(.activateIgnoringOtherApps),
                "Empty activation options lost Monterey foreground behavior")

    let targets = try ["com.apple.TextEdit", "com.apple.calculator"].map(launch)
    let browser = try launch("com.apple.Safari")
    guard let browserURL = browser.bundleURL else { throw NSError(domain: "Docky.ActivationQA", code: 3) }
    let fixture = FileManager.default.temporaryDirectory.appendingPathComponent("Docky-activation-page.html")
    try "<html><title>Docky activation check</title><body>Local browser activation fixture</body></html>"
        .write(to: fixture, atomically: true, encoding: .utf8)
    let browserConfiguration = NSWorkspace.OpenConfiguration()
    browserConfiguration.activates = true
    NSWorkspace.shared.open([fixture], withApplicationAt: browserURL,
                            configuration: browserConfiguration, completionHandler: nil)
    try require(waitUntil { NSWorkspace.shared.frontmostApplication?.processIdentifier == browser.processIdentifier },
                "Safari page did not become active")

    let workspace = WorkspaceService.shared
    var switches = 0
    for policy in [NSApplication.ActivationPolicy.accessory, .regular] {
        app.setActivationPolicy(policy)
        for target in targets {
            guard let bundleID = target.bundleIdentifier else { throw NSError(domain: "Docky.ActivationQA", code: 4) }
            let originalPID = target.processIdentifier
            for hidden in [false, true] {
                if hidden { _ = target.hide() } else { _ = target.unhide() }
                try require(browser.activateTransferringFrontmost(options: [.activateAllWindows]),
                            "Safari foreground request was rejected")
                try require(waitUntil { NSWorkspace.shared.frontmostApplication?.processIdentifier == browser.processIdentifier },
                            "Safari was not active before switching to \(bundleID)")

                // Same method used by TileView.handleTap. The target is
                // already running; launching a new app cannot mask failure.
                workspace.activateOrOpen(bundleIdentifier: bundleID)
                try require(waitUntil { NSWorkspace.shared.frontmostApplication?.processIdentifier == originalPID },
                            "Running app did not become frontmost: \(bundleID), policy \(policy.rawValue), hidden \(hidden)")
                try require(!target.isHidden && !target.isTerminated,
                            "Target stayed hidden or terminated: \(bundleID)")
                try require(NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                    .contains { $0.processIdentifier == originalPID }, "Target process was replaced: \(bundleID)")
                switches += 1
                print("Browser to running app passed: \(bundleID); policy \(policy.rawValue); initially hidden \(hidden)")
            }
        }
    }
    app.setActivationPolicy(.accessory)
    print("Legacy activation options and \(switches) browser-to-running-app switches passed")
}
