import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var clipboard: ClipboardManager
    @Binding var draftHistoryCount: Int
    @Binding var maxHistoryCount: Int
    
    @State private var showingClearAlert = false
    
    @AppStorage("maxItemSizeMB") private var maxItemSizeMB: Int = 10
    @AppStorage("maxTotalStorageMB") private var maxTotalStorageMB: Int = 50
    
    @AppStorage("saveText") private var saveText: Bool = true
    @AppStorage("saveLinks") private var saveLinks: Bool = true
    @AppStorage("saveImages") private var saveImages: Bool = true
    @AppStorage("saveFiles") private var saveFiles: Bool = true
    
    @AppStorage("themePreference") private var themePreference: String = "System"
    @AppStorage("activeColorName") private var activeColorName: String = "Glacier"
    
    @State private var selectedTab = "General"
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("General").tag("General")
                Text("Types").tag("Types")
                Text("Shortcuts").tag("Shortcuts")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            Divider()
            
            ScrollView {
                Group {
                    switch selectedTab {
                    case "General":
                        generalTab
                    case "Types":
                        typesTab
                    case "Shortcuts":
                        shortcutsTab
                    default:
                        EmptyView()
                    }
                }
                .padding()
            }
            .frame(height: 280)
        }
        .frame(width: 300)
    }
    
    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("History Limit:")
                    .font(.system(size: 13))
                Spacer()
                TextField("", value: $draftHistoryCount, format: .number)
                    .frame(width: 50)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        maxHistoryCount = max(5, draftHistoryCount)
                    }
                Stepper("", value: $draftHistoryCount, in: 5...500)
                    .labelsHidden()
            }
            Text("Maximum number of items to keep in history.")
                .font(.system(size: 11))
                .foregroundColor(.primary.opacity(0.5))
            
            Divider()
            
            HStack {
                Text("Theme:")
                    .font(.system(size: 13))
                Spacer()
                Picker("", selection: $themePreference) {
                    Text("System").tag("System")
                    Text("Light").tag("Light")
                    Text("Dark").tag("Dark")
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 150)
            }
            
            Divider()
            
            Text("Accent Color:")
                .font(.system(size: 13))
            
            HStack(spacing: 8) {
                ForEach(colors, id: \.name) { c in
                    Circle()
                        .fill(c.name == "Clear" ? Color.primary.opacity(0.1) : c.color)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Color.primary, lineWidth: activeColorName == c.name ? 2 : 0)
                        )
                        .onTapGesture { 
                            activeColorName = c.name
                        }
                }
            }
            
            Divider()
            
            HStack {
                Text("Max Item Size (MB):")
                    .font(.system(size: 13))
                Spacer()
                TextField("", value: $maxItemSizeMB, format: .number)
                    .frame(width: 50)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: maxItemSizeMB) { newValue in
                        if newValue > 20 { maxItemSizeMB = 20 }
                        else if newValue < 1 { maxItemSizeMB = 1 }
                    }
                Stepper("", value: $maxItemSizeMB, in: 1...20)
                    .labelsHidden()
            }
            
            HStack {
                Text("Total Storage Cap (MB):")
                    .font(.system(size: 13))
                Spacer()
                TextField("", value: $maxTotalStorageMB, format: .number)
                    .frame(width: 50)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: maxTotalStorageMB) { newValue in
                        if newValue > 100 { maxTotalStorageMB = 100 }
                        else if newValue < 1 { maxTotalStorageMB = 1 }
                    }
                Stepper("", value: $maxTotalStorageMB, in: 1...100)
                    .labelsHidden()
            }
            
            Spacer()
            
            Divider()
            
            Button(action: { showingClearAlert = true }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear All History")
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
            .alert("Clear all copied items?", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) { clipboard.clearAll() }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
    
    private var typesTab: some View {
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
    
    private var shortcutsTab: some View {
        ScrollView {
            VStack(spacing: 8) {
                shortcutRow(action: "Open Search", key: "Cmd + F")
                shortcutRow(action: "Toggle Layout", key: "Cmd + D")
                shortcutRow(action: "Cycle Colors", key: "Cmd + K")
                shortcutRow(action: "Settings", key: "Cmd + ,")
                shortcutRow(action: "Edit Mode", key: "Cmd + E")
                shortcutRow(action: "Switch Tabs", key: "Opt + 1-6")
                shortcutRow(action: "Pin Selected (Edit)", key: "P")
                shortcutRow(action: "Delete Selected (Edit)", key: "⌫ Delete")
                shortcutRow(action: "Select All (Current Tab)", key: "Cmd + A")
                shortcutRow(action: "Toggle Selection (Edit)", key: "Space")
                shortcutRow(action: "Close Window", key: "Esc")
            }
            .padding(.trailing, 12)
        }
    }
    
    private func shortcutRow(action: String, key: String) -> some View {
        HStack {
            Text(action).font(.system(size: 12))
            Spacer()
            Text(key)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.1))
                .cornerRadius(4)
        }
    }
}
