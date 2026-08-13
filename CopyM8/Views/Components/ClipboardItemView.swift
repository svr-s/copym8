import SwiftUI
import AppKit

struct ClipboardItemView: View {
    @EnvironmentObject var clipboard: ClipboardManager
    let item: ClipboardItem
    let shortcutIndex: Int?
    let isSelected: Bool
    let isExpanded: Bool
    let isDense: Bool
    let activeColor: Color
    let isEditMode: Bool
    let isChecked: Bool
    let folderIdentifier: String?
    var queueStatus: QueueStatus? = nil
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
    
    private var titleText: String {
        if (item.itemType == .file || item.itemType == .image), let range = item.text.range(of: " (", options: .backwards) {
            return String(item.text[..<range.lowerBound])
        }
        return item.text
    }
    
    private var filenameText: String {
        let title = titleText
        if title.hasSuffix(" more"), let range = title.range(of: " + ", options: .backwards) {
            return String(title[..<range.lowerBound])
        }
        return title
    }
    
    private var suffixText: String? {
        let title = titleText
        if title.hasSuffix(" more"), let range = title.range(of: " + ", options: .backwards) {
            return String(title[range.lowerBound...])
        }
        return nil
    }
    
    private var metaText: String? {
        if (item.itemType == .file || item.itemType == .image), let range = item.text.range(of: " (", options: .backwards) {
            return String(item.text[range.lowerBound...])
        }
        return nil
    }
    
    @ViewBuilder
    private var titleAndMetaView: some View {
        HStack(spacing: 0) {
            Text(filenameText)
                .lineLimit(isExpanded ? nil : ((item.itemType == .file || item.itemType == .image) ? 1 : (isDense ? 1 : 2)))
                .truncationMode((item.itemType == .file || item.itemType == .image) ? .middle : .tail)
            
            if let suffix = suffixText {
                Text(suffix)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            
            if let meta = metaText {
                Text(meta)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 13, weight: .regular))
        .foregroundColor(primaryTextColor)
        .fixedSize(horizontal: false, vertical: true)
    }

    var body: some View {
        Button(action: onPaste) {
            HStack(spacing: 12) {
                if let status = queueStatus {
                    // Render queue status vertical line
                    let color: Color = {
                        switch status {
                        case .next: return .green
                        case .upcoming: return .yellow
                        case .pasted: return .red
                        }
                    }()
                    Rectangle()
                        .fill(color)
                        .frame(width: 3)
                        .cornerRadius(1.5)
                        .padding(.vertical, 4)
                        
                    // Render play/pause icon instead of index for Queue items
                    if status == .next {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                            .frame(width: 16, alignment: .leading)
                    } else if status == .upcoming {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.yellow.opacity(0.8))
                            .frame(width: 16, alignment: .leading)
                    } else {
                        Spacer().frame(width: 16)
                    }
                } else if isEditMode {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isChecked ? .primary : .primary.opacity(0.3))
                        .font(.system(size: 14))
                        .frame(width: 16, alignment: .leading)
                } else {
                    if let sIndex = shortcutIndex {
                        let shortcutText = sIndex == 9 ? "0" : "\(sIndex + 1)"
                        Text(shortcutText)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(secondaryTextColor)
                            .frame(width: 16, alignment: .leading)
                    } else {
                        Spacer().frame(width: 16)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if item.itemType == .image {
                        HStack(spacing: 6) {
                            if let paths = item.fileURLs, paths.count > 1 {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .foregroundColor(.secondary)
                            } else {
                                Image(systemName: "photo.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .foregroundColor(.secondary)
                            }
                            titleAndMetaView
                        }
                    } else if item.itemType == .file, let paths = item.fileURLs, let path = paths.first {
                        HStack(spacing: 6) {
                            if paths.count > 1 {
                                Image(systemName: "doc.on.doc.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .foregroundColor(.secondary)
                            } else {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                                    .resizable()
                                    .frame(width: 16, height: 16)
                            }
                            titleAndMetaView
                        }
                    } else {
                        titleAndMetaView
                    }
                    
                    if !isDense, let app = item.sourceApp {
                        Text("\(app) • \(item.timestamp.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 9))
                            .foregroundColor(isSelected && isWindowActive ? .white.opacity(0.8) : .primary.opacity(0.4))
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Group {
                        if item.isPinned {
                            Image(systemName: "pin.fill")
                                .foregroundColor(secondaryTextColor)
                                .font(.system(size: 11))
                        }
                    }
                    .frame(width: 12)
                    
                    Group {
                        if !clipboard.isItemAvailable(item) {
                            Image(systemName: "arrow.down.icloud.fill")
                                .foregroundColor(.blue.opacity(0.8))
                                .font(.system(size: 11))
                        } else if let folderId = folderIdentifier {
                            Text("[\(folderId)]")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                    .frame(width: 24, alignment: .trailing)
                }
            }
            .padding(.vertical, isDense ? 4 : 8)
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

// MARK: - Native Drag View
