import SwiftUI
import AppKit
import KeyboardShortcuts

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
            .frame(height: 380)
        }
        .frame(width: 300)
    }
    
    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 16) {
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
            Text("Maximum number of unpinned items to keep in history.")
                .font(.system(size: 11))
                .foregroundColor(.primary.opacity(0.5))
            
            HStack {
                Text("Max Item Size (MB):")
                    .font(.system(size: 13))
                Spacer()
                TextField("", value: $maxItemSizeMB, format: .number)
                    .frame(width: 50)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: maxItemSizeMB) { _, newValue in
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
                    .onChange(of: maxTotalStorageMB) { _, newValue in
                        if newValue > 100 { maxTotalStorageMB = 100 }
                        else if newValue < 1 { maxTotalStorageMB = 1 }
                    }
                Stepper("", value: $maxTotalStorageMB, in: 1...100)
                    .labelsHidden()
            }
            
            Spacer()
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                Text("📊 Storage Statistics")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.bottom, 2)
                
                HStack {
                    Text("Total Items:")
                        .font(.system(size: 12))
                    Spacer()
                    Text("\(clipboard.history.count)")
                        .font(.system(size: 12, weight: .medium))
                }
                
                HStack {
                    Text("Pinned Items:")
                        .font(.system(size: 12))
                    Spacer()
                    Text("\(clipboard.history.filter { $0.isPinned }.count)")
                        .font(.system(size: 12, weight: .medium))
                }
                
                HStack {
                    Text("Image Storage:")
                        .font(.system(size: 12))
                    Spacer()
                    Text(String(format: "%.1f MB", LocalImageStore.shared.getTotalSizeMB()))
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(8)
            
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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Global Launch Shortcuts")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                        
                    KeyboardShortcuts.Recorder("Open CopyM8:", name: .toggleApp)
                    KeyboardShortcuts.Recorder("Open Pinned Tab:", name: .openPinned)
                    KeyboardShortcuts.Recorder("Open Groups Tab:", name: .openGroups)
                    
                    Text("Tip: Use Cmd+Opt+P and Cmd+Opt+G for tabs!")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                }
                .padding(10)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(8)
                
                Text("In-App Shortcuts")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)

                Group {
                    shortcutCategory("General & Navigation")
                    shortcutRow(action: "Open Search", key: "Cmd + F")
                    shortcutRow(action: "Toggle Layout", key: "Cmd + D")
                    shortcutRow(action: "Cycle Colors", key: "Cmd + K")
                    shortcutRow(action: "Settings", key: "Cmd + ,")
                }
                
                Group {
                    shortcutCategory("Tabs")
                    shortcutRow(action: "Next Tab", key: "Opt + Tab")
                    shortcutRow(action: "Previous Tab", key: "Opt + Shift + Tab")
                    shortcutRow(action: "Quick Switch Tabs", key: "Opt + 1-7")
                }
                
                Group {
                    shortcutCategory("Clipboard Items")
                    shortcutRow(action: "Navigate Items", key: "Up / Down")
                    shortcutRow(action: "Expand / Collapse Item", key: "Right / Left")
                    shortcutRow(action: "Paste Plain Text", key: "Enter")
                    shortcutRow(action: "Paste Rich Text", key: "Cmd + Enter")
                    shortcutRow(action: "Quick Paste (1st-9th)", key: "1 - 9")
                    shortcutRow(action: "Pin Item", key: "Cmd + P")
                    shortcutRow(action: "Delete Item", key: "⌫ Delete")
                }
                
                Group {
                    shortcutCategory("Groups & Folders")
                    shortcutRow(action: "Expand / Collapse Folder", key: "Right / Left")
                    shortcutRow(action: "Super Collapse to Parent", key: "Opt + Left")
                    shortcutRow(action: "Expand All Folders", key: "Cmd + Shift + Down")
                    shortcutRow(action: "Collapse All Folders", key: "Cmd + Shift + Up")
                    shortcutRow(action: "Assign Group Modal", key: "Cmd + G")
                    shortcutRow(action: "Quick Assign (in Modal)", key: "A - Z")
                    shortcutRow(action: "Create New Group", key: "Cmd + N")
                }
                
                Group {
                    shortcutCategory("Edit Mode (Bulk Actions)")
                    shortcutRow(action: "Toggle Edit Mode", key: "Cmd + E")
                    shortcutRow(action: "Reorder Item/Group", key: "Cmd + Up/Down")
                    shortcutRow(action: "Multi-Select Range", key: "Shift + Up/Down")
                    shortcutRow(action: "Toggle Selection", key: "Space")
                    shortcutRow(action: "Select All in Tab", key: "Cmd + A")
                    shortcutRow(action: "Unpin / Ungroup", key: "Cmd + U")
                }
                shortcutRow(action: "Toggle Selection (Edit)", key: "Space")
                shortcutRow(action: "Expand Item/Folder", key: "Right")
                shortcutRow(action: "Collapse/Jump Up", key: "Left")
                shortcutRow(action: "Super Collapse", key: "Opt + Left")
                shortcutRow(action: "Close Window", key: "Esc")
            }
            .padding(.trailing, 12)
        }
    }
    
    private func shortcutCategory(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
            .padding(.bottom, 2)
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
