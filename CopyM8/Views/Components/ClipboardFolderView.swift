import SwiftUI
import AppKit

struct ClipboardFolderView: View {
    @EnvironmentObject var clipboard: ClipboardManager
    let folder: ClipboardFolder
    let shortcutIndex: Int?
    let isSelected: Bool
    let isDense: Bool
    let activeColor: Color
    let isEditMode: Bool
    let isChecked: Bool
    @Binding var editingFolderId: UUID?
    let onTap: () -> Void
    var isExpanded: Bool = false
    
    @State private var hover = false
    @State private var renameText = ""
    @FocusState private var isRenameFocused: Bool
    @Environment(\.controlActiveState) private var controlActiveState
    
    private var isWindowActive: Bool {
        controlActiveState == .key || controlActiveState == .active
    }
    
    private var primaryTextColor: Color {
        isSelected && isWindowActive ? .white : .primary.opacity(0.95)
    }
    
    private var secondaryTextColor: Color {
        isSelected && isWindowActive ? .white.opacity(0.8) : .primary.opacity(0.6)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                if isEditMode {
                    if folder.id == UUID(uuidString: "00000000-0000-0000-0000-000000000000")! {
                        Spacer().frame(width: 14)
                    } else {
                        Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isChecked ? .primary : .primary.opacity(0.3))
                            .font(.system(size: 14))
                    }
                } else {
                    if folder.id == UUID(uuidString: "00000000-0000-0000-0000-000000000000")! {
                        Text("`")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(secondaryTextColor)
                            .frame(width: 16, alignment: .leading)
                    } else if let sIndex = shortcutIndex, sIndex < 26 {
                        let shortcutLetter = String(UnicodeScalar(UInt8(65 + sIndex)))
                        Text(shortcutLetter)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(secondaryTextColor)
                            .frame(width: 16, alignment: .leading)
                    } else {
                        Spacer().frame(width: 16)
                    }
                }
                
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(secondaryTextColor.opacity(0.8))
                    .frame(width: 10)
                
                HStack(spacing: 8) {
                    if folder.id == UUID(uuidString: "00000000-0000-0000-0000-000000000000")! {
                        Image(systemName: "cloud.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 14)
                            .foregroundColor(.blue.opacity(0.8))
                            .opacity(isExpanded ? 1.0 : 0.7)
                    } else {
                        Image(nsImage: NSImage(named: NSImage.folderName)!)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 14)
                            .opacity(isExpanded ? 1.0 : 0.7)
                    }
                    
                    if editingFolderId == folder.id {
                        TextField("", text: $renameText)
                            .font(.system(size: 13, weight: .medium))
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(.primary)
                            .focused($isRenameFocused)
                            .onSubmit {
                                if !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                                    if let idx = clipboard.folders.firstIndex(where: { $0.id == folder.id }) {
                                        clipboard.folders[idx].name = renameText.trimmingCharacters(in: .whitespaces)
                                    }
                                }
                                editingFolderId = nil
                            }
                            .onAppear {
                                renameText = folder.name
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isRenameFocused = true
                                }
                            }
                            .onChange(of: isRenameFocused) { focused in
                                if !focused && editingFolderId == folder.id {
                                    editingFolderId = nil
                                }
                            }
                    } else {
                        Text(folder.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(primaryTextColor)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, isDense ? 6 : 10)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
            .background(
                isSelected 
                ? (isWindowActive ? Color(nsColor: .selectedContentBackgroundColor) : Color(nsColor: .unemphasizedSelectedContentBackgroundColor)) 
                : (hover ? Color.primary.opacity(0.05) : Color.clear)
            )
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            hover = hovering
        }
    }
}
