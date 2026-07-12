import re

with open('/Users/dodos/Documents/repositories/vatsa_codes/CopyM8/CopyM8/Views/Settings/SettingsView.swift', 'r') as f:
    content = f.read()

old_shortcuts = """                shortcutRow(action: "Open Search", key: "Cmd + F")
                shortcutRow(action: "Toggle Layout", key: "Cmd + D")
                shortcutRow(action: "Cycle Colors", key: "Cmd + K")
                shortcutRow(action: "Settings", key: "Cmd + ,")
                shortcutRow(action: "Edit Mode", key: "Cmd + E")
                shortcutRow(action: "Next Tab", key: "Opt + Tab")
                shortcutRow(action: "Previous Tab", key: "Opt + Shift + Tab")
                shortcutRow(action: "All Tab", key: "Opt + A / 1")
                shortcutRow(action: "Pinned Tab", key: "Opt + P / 2")
                shortcutRow(action: "Groups Tab", key: "Opt + G / 3")
                shortcutRow(action: "Text Tab", key: "Opt + T / 4")
                shortcutRow(action: "Links Tab", key: "Opt + L / 5")
                shortcutRow(action: "Images Tab", key: "Opt + I / 6")
                shortcutRow(action: "Files Tab", key: "Opt + F / 7")
                shortcutRow(action: "Reorder Item/Group", key: "Cmd + Up/Down")
                shortcutRow(action: "Assign Group", key: "Cmd + G")
                shortcutRow(action: "Navigate Assign Modal", key: "Up/Down")
                shortcutRow(action: "Quick Assign Group", key: "A-Z")
                shortcutRow(action: "Pin Item", key: "Cmd + P")
                shortcutRow(action: "Unpin / Ungroup (Edit)", key: "Cmd + U")
                shortcutRow(action: "Delete Selected (Edit)", key: "⌫ Delete")
                shortcutRow(action: "Select All (Current Tab)", key: "Cmd + A")
                shortcutRow(action: "Multi-Select (Edit)", key: "Shift + Up/Down")"""

new_shortcuts = """                Group {
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
                }"""

if old_shortcuts in content:
    content = content.replace(old_shortcuts, new_shortcuts)
    
    # We also need to add shortcutCategory function
    func_str = """    private func shortcutCategory(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
            .padding(.bottom, 2)
    }
    
    private func shortcutRow(action: String, key: String) -> some View {"""
    
    content = content.replace('    private func shortcutRow(action: String, key: String) -> some View {', func_str)
    
    with open('/Users/dodos/Documents/repositories/vatsa_codes/CopyM8/CopyM8/Views/Settings/SettingsView.swift', 'w') as f:
        f.write(content)
    print("SettingsView shortcuts updated.")
else:
    print("Could not find old_shortcuts in SettingsView.swift")
