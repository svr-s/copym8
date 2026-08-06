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
            
            Divider().padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Custom App Tabs")
                    .font(.system(size: 13, weight: .semibold))
                
                Text("Select up to 3 applications. These will appear as dedicated tabs when you are on this Mac.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                customTabRow(title: "Custom Tab (Opt + 8)", tabBinding: $customTab8)
                customTabRow(title: "Custom Tab (Opt + 9)", tabBinding: $customTab9)
                customTabRow(title: "Custom Tab (Opt + 0)", tabBinding: $customTab0)
            }
            
            Spacer()
        }
    }
    
    private func customTabRow(title: String, tabBinding: Binding<String>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
            Spacer()
            if !tabBinding.wrappedValue.isEmpty {
                Text(tabBinding.wrappedValue)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.1))
                    .cornerRadius(4)
                
                Button(action: {
                    tabBinding.wrappedValue = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Button("Select App...") {
                    selectAppForCustomTab { appName in
                        tabBinding.wrappedValue = appName
                    }
                }
                .font(.system(size: 11))
            }
        }
    }
}
