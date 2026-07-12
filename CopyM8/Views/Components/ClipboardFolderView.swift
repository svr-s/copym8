import SwiftUI
import AppKit

struct ClipboardFolderView: View {
    let folder: ClipboardFolder
    let shortcutIndex: Int?
    let isSelected: Bool
    let isDense: Bool
    let activeColor: Color
    let isEditMode: Bool
    let isChecked: Bool
    let onTap: () -> Void
    var isExpanded: Bool = false
    
    @State private var hover = false
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
            HStack(spacing: 12) {
                if isEditMode {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isChecked ? .primary : .primary.opacity(0.3))
                        .font(.system(size: 14))
                } else {
                    if let sIndex = shortcutIndex, sIndex < 26 {
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
                    .foregroundColor(secondaryTextColor.opacity(0.6))
                    .frame(width: 10)
                
                HStack(spacing: 8) {
                    Image(nsImage: NSImage(named: NSImage.folderName)!)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .opacity(isExpanded ? 1.0 : 0.7)
                    
                    Text(folder.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(primaryTextColor)
                }
                
                Spacer()
            }
            .padding(.vertical, isDense ? 6 : 10)
            .padding(.horizontal, 12)
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
