import SwiftUI
import Perception

struct UpdatesSettingsView: View {
    var body: some View {
        WithPerceptionTracking {
            Form {
                Section("Monterey 兼容版") {
                    Text("此版本已关闭自动更新。")
                        .font(.headline)
                    Text("请从此兼容项目下载后续版本。Docky 官方原版需要更新的 macOS 系统。")
                        .foregroundStyle(.secondary)
                    Link("打开兼容项目", destination: URL(string: "https://github.com/shenjunjie1101-lab/docky")!)
                }
            }
            .dockySettingsForm()
        }
    }
}
