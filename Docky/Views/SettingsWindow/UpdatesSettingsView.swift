import SwiftUI
import Perception

struct UpdatesSettingsView: View {
    var body: some View {
        WithPerceptionTracking {
            Form {
                Section("Monterey Compatibility Build") {
                    Text("Automatic updates are disabled in this build.")
                        .font(.headline)
                    Text("Get compatible builds from this fork. The original Docky releases require a newer version of macOS.")
                        .foregroundStyle(.secondary)
                    Link("Open compatibility project", destination: URL(string: "https://github.com/shenjunjie1101-lab/docky")!)
                }
            }
            .dockySettingsForm()
        }
    }
}
