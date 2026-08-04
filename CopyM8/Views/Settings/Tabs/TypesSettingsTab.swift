import SwiftUI
import AppKit
import KeyboardShortcuts

extension SettingsView {
    var typesTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select which types of content to save.")
                .font(.system(size: 11))
                .foregroundColor(.primary.opacity(0.6))
            
            Toggle("Save Text", isOn: $saveText)
            Toggle("Save Links", isOn: $saveLinks)
            Toggle("Save Images", isOn: $saveImages)
            Toggle("Save Files", isOn: $saveFiles)
            
            Spacer()
        }
    }
}
