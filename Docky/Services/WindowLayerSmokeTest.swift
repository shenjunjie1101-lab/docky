import AppKit

/// Explicit CI entry point; never runs during normal user startup.
@MainActor
func runWindowLayerSmokeTest() throws {
    func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() {
            throw NSError(domain: "Docky.InteractionQA", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
    func settle(_ duration: TimeInterval = 0.08) {
        RunLoop.main.run(until: Date().addingTimeInterval(duration))
    }
    func windowList() -> [[String: Any]] {
        (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                   kCGNullWindowID) as? [[String: Any]]) ?? []
    }
    func number(_ info: [String: Any], _ key: CFString) -> Int? {
        (info[key as String] as? NSNumber)?.intValue
    }

    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    app.finishLaunching()
    let preferences = DockyPreferences.shared
    preferences.autohidesWindow = false
    preferences.hidesDuringFullscreen = false
    preferences.maximizedWindowBehavior = .ignore

    var topLevelObjects: NSArray?
    try require(Bundle.main.loadNibNamed("MainWindow", owner: nil,
                                        topLevelObjects: &topLevelObjects), "Dock nib failed to load")
    guard let dock = (topLevelObjects as? [Any])?.compactMap({ $0 as? MainWindow }).first else {
        throw NSError(domain: "Docky.InteractionQA", code: 2)
    }
    let controller = MainWindowController(window: dock)
    controller.showWindow(nil)
    settle(0.6)
    let cover = NSWindow(contentRect: dock.frame, styleMask: [.titled],
                         backing: .buffered, defer: false)
    cover.isReleasedWhenClosed = false
    cover.title = "Docky normal-window overlap probe"
    cover.level = .normal
    cover.makeKeyAndOrderFront(nil)
    app.activate(ignoringOtherApps: true)
    settle()
    defer { cover.close(); controller.close() }

    func checkStacking(_ label: String) throws {
        let windows = windowList()
        guard let dockIndex = windows.firstIndex(where: {
            number($0, kCGWindowNumber) == dock.windowNumber
        }), let coverIndex = windows.firstIndex(where: {
            number($0, kCGWindowNumber) == cover.windowNumber
        }) else {
            throw NSError(domain: "Docky.InteractionQA", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Missing onscreen probe window: \(label)"])
        }
        let nativeLayer = number(windows[dockIndex], kCGWindowLayer)
        try require(nativeLayer == NSWindow.Level.mainMenu.rawValue,
                    "WindowServer layer is \(String(describing: nativeLayer)), not mainMenu: \(label)")
        try require(dockIndex < coverIndex, "Dock is behind the overlapping normal window: \(label)")
        try require(dock.isVisible && !dock.hidesOnDeactivate && !dock.ignoresMouseEvents,
                    "Dock hides or rejects mouse events: \(label)")
        print("Native layer \(nativeLayer ?? -1); dock ahead of overlapping normal window: \(label)")
    }
    try checkStacking("own app active")

    let finder: NSRunningApplication
    if let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first {
        finder = running
    } else {
        finder = try NSWorkspace.shared.launchApplication(
            at: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"),
            options: [.withoutActivation], configuration: [:])
    }
    try require(finder.activate(options: [.activateIgnoringOtherApps]), "Could not activate Finder")
    settle(0.5)
    try require(NSWorkspace.shared.frontmostApplication?.processIdentifier == finder.processIdentifier,
                "Finder did not become active")
    try checkStacking("Finder active")
    dock.orderFrontRegardless()
    settle()
    try require(NSWorkspace.shared.frontmostApplication?.processIdentifier == finder.processIdentifier,
                "Ordering the dock forward stole keyboard focus")
    try checkStacking("background dock ordered forward without activation")

    let store = TileStore.shared
    let bundleIDs = ["com.apple.TextEdit", "com.apple.calculator", "com.apple.Preview"]
    try require(bundleIDs.allSatisfy { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil },
                "Standard Mac apps missing from regression fixture")
    let modes: [FolderTileContentViewMode] = [.grid, .list, .inline]
    for cycle in 0..<30 {
        preferences.pinnedItems = bundleIDs.map(PinnedTileItem.app(bundleIdentifier:))
        store.refresh()
        settle()
        let targetID = "pinned:app:\(bundleIDs[0])"
        try require(store.groupApps(bundleIdentifiers: Array(bundleIDs.dropFirst()), intoTileID: targetID),
                    "Grouping failed in cycle \(cycle)")
        guard let folder = preferences.pinnedItems.first(where: { $0.kind == .appFolder }) else {
            throw NSError(domain: "Docky.InteractionQA", code: 4)
        }
        let folderID = "pinned:\(folder.id)"
        let mode = modes[cycle % modes.count]
        store.setAppFolderContentViewMode(tileID: folderID, mode: mode)
        if mode == .inline { store.toggleInlineAppFolderExpansion(folderID: folder.id) }
        settle()

        // Select an actual native menu item while NSMenu is tracking. The
        // operation must not tear down its anchor until tracking returns.
        var menuReturned = false
        var ran = false
        var ranDuringTracking = false
        let action = ContextAction.action("Ungroup regression fixture") {
            ranDuringTracking = !menuReturned
            ran = true
            store.ungroupAppFolder(tileID: folderID)
        }
        let coordinator = ContextActionMenuPresenter.Coordinator(
            actionProvider: { _ in [action] }, preferredEdge: .maxY,
            onPresentationChanged: { _ in })
        let menu = NSMenu()
        let item = NSMenuItem(title: action.title, action: NSSelectorFromString("runAction:"), keyEquivalent: "")
        item.target = coordinator
        item.representedObject = action
        menu.addItem(item)
        let selection = Timer(timeInterval: 0.15, repeats: false) { _ in
            menu.performActionForItem(at: 0)
            menu.cancelTracking()
        }
        RunLoop.main.add(selection, forMode: .common)
        RunLoop.main.add(selection, forMode: .eventTracking)
        guard let anchor = dock.contentView else { throw NSError(domain: "Docky.InteractionQA", code: 5) }
        coordinator.popUpCartouche(menu: menu, in: anchor)
        menuReturned = true
        selection.invalidate()
        settle(0.12)
        try require(ran && !ranDuringTracking, "Menu action ran before menu tracking unwound in cycle \(cycle)")
        try require(preferences.pinnedItems.compactMap(\.bundleIdentifier) == bundleIDs,
                    "Ungroup lost or reordered members in cycle \(cycle)")
        let visibleIDs = store.tiles.map(\.id)
        try require(Set(visibleIDs).count == visibleIDs.count, "Duplicate visible tile IDs in cycle \(cycle)")
        try require(!store.isInlineAppFolderExpanded(folderID: folder.id), "Stale inline expansion after ungroup")
    }

    // A duplicate member from an imported layout must not create duplicate
    // top-level SwiftUI identities when the folder is dissolved.
    let duplicateFolder = PinnedTileItem.appFolder(
        displayName: "Duplicate membership fixture",
        bundleIdentifiers: [bundleIDs[0], bundleIDs[0], bundleIDs[1], bundleIDs[2]])
    preferences.pinnedItems = [duplicateFolder, .app(bundleIdentifier: bundleIDs[1])]
    store.refresh()
    store.ungroupAppFolder(tileID: "pinned:\(duplicateFolder.id)")
    settle()
    let finalIDs = preferences.pinnedItems.map(\.id)
    try require(Set(finalIDs).count == finalIDs.count && finalIDs.count == 3,
                "Duplicate imported membership was not deduplicated")
    try require(Set(preferences.pinnedItems.compactMap(\.bundleIdentifier)) == Set(bundleIDs),
                "Deduplicating imported membership lost an app")
    print("30 native-menu group/ungroup cycles across grid, list and inline modes passed; duplicate import passed")
}
