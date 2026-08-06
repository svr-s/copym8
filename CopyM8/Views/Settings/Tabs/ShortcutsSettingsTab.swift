import SwiftUI
import AppKit
import KeyboardShortcuts

extension SettingsView {
    var shortcutsTab: some View {
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Global Launch Shortcuts")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                    
                HStack {
                    Text("Open CopyM8:").font(.system(size: 12))
                    Spacer()
                    KeyboardShortcuts.Recorder("", name: .toggleApp)
                }
                HStack {
                    Text("Open Pinned Tab:").font(.system(size: 12))
                    Spacer()
                    KeyboardShortcuts.Recorder("", name: .openPinned)
                }
                
                Divider().padding(.vertical, 4)
                
                customGlobalRow(title: "Custom Launch 1:", targetBinding: $customGlobalTarget1, groupBinding: $customGlobalGroup1, shortcut: .customGlobal1)
                customGlobalRow(title: "Custom Launch 2:", targetBinding: $customGlobalTarget2, groupBinding: $customGlobalGroup2, shortcut: .customGlobal2)
                customGlobalRow(title: "Custom Launch 3:", targetBinding: $customGlobalTarget3, groupBinding: $customGlobalGroup3, shortcut: .customGlobal3)
                
                
                Text("Tip: Use Cmd+Opt+P (Pinned) and Cmd+Opt+G (Groups) for tabs!")
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
                shortcutRow(action: "Toggle Layout", key: "Cmd + L")
                shortcutRow(action: "Device Switcher", key: "Cmd + Shift + D")
                shortcutRow(action: "Import from Device", key: "Cmd + I")
                shortcutRow(action: "Settings", key: "Cmd + ,")
                shortcutRow(action: "Close Window", key: "Esc")
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
                shortcutRow(action: "Paste Rich (No Links)", key: "Cmd + Ctrl + Enter")
                shortcutRow(action: "Quick Paste (1st-10th)", key: "1 - 0")
                shortcutRow(action: "Quick Paste Rich (1st-10th)", key: "Cmd + 1 - 0")
                shortcutRow(action: "Quick Paste Rich (No Links)", key: "Cmd + Ctrl + 1 - 0")
                shortcutRow(action: "Pin Item", key: "Cmd + P")
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
                shortcutRow(action: "Rename Folder", key: "Opt + R")
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
            
            Group {
                shortcutCategory("Trash & Deletion")
                shortcutRow(action: "Soft Delete Item", key: "⌫ Delete")
                shortcutRow(action: "Hard Delete Item", key: "Cmd + ⌫ Delete")
                shortcutRow(action: "Toggle Trash Bin", key: "Cmd + Shift + T")
                shortcutRow(action: "Restore Item (in Trash)", key: "Cmd + Z")
                shortcutRow(action: "Empty Trash (in Trash)", key: "Cmd + Shift + ⌫ Delete")
            }
            
            Group {
                shortcutCategory("Mouse Interactions")
                shortcutRow(action: "Paste Plain Text", key: "Left Click")
                shortcutRow(action: "Paste Rich Text", key: "Cmd + Click")
                shortcutRow(action: "Paste Rich (No Links)", key: "Opt + Click")
            }
        }
    }
    
    private func customGlobalRow(title: String, targetBinding: Binding<String>, groupBinding: Binding<String>, shortcut: KeyboardShortcuts.Name) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title).font(.system(size: 12))
                
                Picker("", selection: targetBinding) {
                    Text("All").tag("All")
                    Text("Groups").tag("Groups")
                    Text("Text").tag("Text")
                    Text("Links").tag("Links")
                    Text("Images").tag("Images")
                    Text("Files").tag("Files")
                    
                    if !customTab8.isEmpty { Text(customTab8).tag(customTab8) }
                    if !customTab9.isEmpty { Text(customTab9).tag(customTab9) }
                    if !customTab0.isEmpty { Text(customTab0).tag(customTab0) }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 100)
                
                Spacer()
                KeyboardShortcuts.Recorder("", name: shortcut)
            }
            
            if targetBinding.wrappedValue == "Groups" {
                HStack {
                    Text("Folder:").font(.system(size: 11)).foregroundColor(.secondary)
                    Spacer()
                    Picker("", selection: groupBinding) {
                        Text("Select Folder").tag("")
                        let standardFolders = clipboard.activeFolders.filter { $0.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")! && $0.name != "Restored Items" }
                        ForEach(Array(standardFolders.enumerated()), id: \.element.id) { index, folder in
                            let identifier = String(UnicodeScalar(UInt8(65 + index)))
                            Text("[\(identifier)] \(folder.name)").tag(folder.id.uuidString)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 120)
                }
                .padding(.leading, 12)
            }
        }
    }
}
