import SwiftUI
import AppKit
import KeyboardShortcuts

extension SettingsView {
    var privacyTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Clipboard Filters")
                    .font(.system(size: 13, weight: .semibold))
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ignore Passwords & Sensitive Fields")
                            .font(.system(size: 12))
                        Text("e.g. 1Password, Bitwarden, Keychain, hidden fields")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $ignorePasswords)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ignore Temporary & Macro Data")
                            .font(.system(size: 12))
                        Text("e.g. background automation scripts or macro tools")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $ignoreTransient)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ignore Universal Clipboard")
                            .font(.system(size: 12))
                        Text("Ignore copies from your iPhone/iPad via Handoff")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $ignoreUniversalClipboard)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
            Text("App Blacklist")
                .font(.system(size: 13, weight: .semibold))
            
            Text("Items copied from these apps will NOT be saved to CopyM8.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            List {
                ForEach(blacklistedApps, id: \.self) { app in
                    HStack {
                        Text(app)
                            .font(.system(size: 12))
                        Spacer()
                        Button(action: {
                            removeBlacklistedApp(app)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
            .frame(height: 150)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1), lineWidth: 1))
            
            HStack {
                Button("Add App to Blacklist via Finder...") {
                    addAppViaFinder()
                }
                .font(.system(size: 11))
                
                Spacer()
            }
            
                Spacer()
            }
            
            Spacer()
        }
    }
}
