import SwiftUI
import AppKit

struct ClipboardItemView: View {
    let index: Int
    let item: ClipboardItem
    let isSelected: Bool
    let isExpanded: Bool
    let isDense: Bool
    let activeColor: Color
    let isEditMode: Bool
    let isChecked: Bool
    let onPaste: () -> Void
    let onExpandToggle: () -> Void
    
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
        Button(action: onPaste) {
            HStack(spacing: 12) {
                if isEditMode {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isChecked ? Color.accentColor : .primary.opacity(0.3))
                        .font(.system(size: 14))
                } else {
                    let shortcutText = index == 9 ? "0" : "\(index + 1)"
                    Text(shortcutText)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(secondaryTextColor)
                        .frame(width: 16, alignment: .leading)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if item.itemType == .image, let nsImage = LocalImageStore.shared.loadImage(id: item.id) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: isExpanded ? 200 : 40)
                            .cornerRadius(4)
                    } else if item.itemType == .file, let path = item.fileURL {
                        HStack(spacing: 6) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                                .resizable()
                                .frame(width: 16, height: 16)
                            Text(item.text)
                                .lineLimit(isExpanded ? nil : 1)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(primaryTextColor)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Text(item.text)
                            .lineLimit(isExpanded ? nil : 1)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(primaryTextColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    if !isDense, let app = item.sourceApp {
                        Text("\(app) • \(item.timestamp.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 9))
                            .foregroundColor(isSelected && isWindowActive ? .white.opacity(0.8) : .primary.opacity(0.4))
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, isDense ? 4 : 8)
            .padding(.horizontal, 12)
            .background(
                isSelected 
                ? (isWindowActive ? Color.accentColor : Color(nsColor: .unemphasizedSelectedContentBackgroundColor)) 
                : (hover ? Color.primary.opacity(0.05) : Color.clear)
            )
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            hover = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

// MARK: - Native Drag View
