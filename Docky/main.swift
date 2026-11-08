import Cocoa

// This is the Simplified Chinese edition. Set only this application's
// language, before AppKit loads the menu nib or any localized resources.
UserDefaults.standard.set(["zh-Hans"], forKey: "AppleLanguages")

if CommandLine.arguments.contains("--window-layer-smoke-test") {
    do {
        try MainActor.assumeIsolated { try runWindowLayerSmokeTest() }
    } catch {
        fputs("Window layer smoke test failed: \(error)\n", stderr)
        exit(1)
    }
} else if CommandLine.arguments.contains("--localization-smoke-test") {
    do {
        try MainActor.assumeIsolated { try runChineseLocalizationSmokeTest() }
    } catch {
        fputs("Localization smoke test failed: \(error)\n", stderr)
        exit(1)
    }
} else {
    exit(NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv))
}
