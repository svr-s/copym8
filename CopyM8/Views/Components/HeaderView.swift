import SwiftUI
import AppKit

/// `HeaderView` acts as the top navigation and window drag handle for the expanded interface.
/// It contains window controls (close), contextual actions (edit, delete), and app settings.
/// The entire background of this view intercepts drag gestures to move the app natively, magnetically snapping to edges.
struct HeaderView: View {
    @EnvironmentObject var clipboard: ClipboardManager
    @EnvironmentObject var shortcut: ShortcutManager
    @Binding var isHoveringClose: Bool
    @Binding var isEditMode: Bool
    @Binding var selectedItemsForDeletion: Set<UUID>
    @Binding var isDense: Bool
    @Binding var windowWidth: Double
    @Binding var windowHeight: Double
    @Binding var draftHistoryCount: Int
    @Binding var maxHistoryCount: Int
    @Binding var activeTab: String
    @Binding var previousTab: String
    
    var adjustWindowFrame: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(Color.red).frame(width: 12, height: 12)
                if isHoveringClose {
                    Image(systemName: "xmark").font(.system(size: 7, weight: .black)).foregroundColor(.black.opacity(0.6))
                }
            }
            .onHover { hover in
                isHoveringClose = hover
            }
            .onTapGesture { NSApplication.shared.terminate(nil) }
            
            Button(action: {
                withAnimation {
                    isEditMode.toggle()
                    if !isEditMode { selectedItemsForDeletion.removeAll() }
                }
            }) {
                Image(systemName: isEditMode ? "checkmark.circle.fill" : "checklist")
                    .font(.system(size: 11))
                    .foregroundColor(isEditMode ? .primary : .primary.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
            
            if clipboard.selectedDevice == "Local (This Mac)" {
                Button(action: {
                    withAnimation {
                        if activeTab == "Trash" {
                            activeTab = previousTab
                        } else {
                            previousTab = activeTab
                            activeTab = "Trash"
                        }
                    }
                }) {
                    Image(systemName: activeTab == "Trash" ? "trash.fill" : "trash")
                        .font(.system(size: 11))
                        .foregroundColor(activeTab == "Trash" ? .primary : .primary.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
            
            HStack(spacing: 1) {
                Text("copym").font(.custom("Gill Sans", size: 15))
                Image(systemName: "infinity").font(.system(size: 19, weight: .heavy))
            }
            .foregroundColor(.primary)
                
            Spacer()
            
            Picker("", selection: $isDense) {
                Image(systemName: "rectangle.grid.1x3").tag(true)
                Image(systemName: "rectangle.grid.1x2").tag(false)
            }
            .pickerStyle(.segmented)
            .frame(width: 60)
            
            Button(action: {
                SettingsWindowManager.shared.showSettings(
                    draftHistoryCount: $draftHistoryCount,
                    maxHistoryCount: $maxHistoryCount,
                    clipboard: clipboard,
                    shortcut: shortcut
                )
            }) {
                Image(systemName: "gearshape").font(.system(size: 11)).foregroundColor(.primary.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
            .keyboardShortcut(",", modifiers: .command)
            .onHover { hover in
                if hover { NSCursor.arrow.push() } else { NSCursor.pop() }
            }
            
            Divider().frame(height: 12).background(Color.primary.opacity(0.2))
            
            Button(action: {
                withAnimation(.spring()) {
                    windowWidth = 340
                    windowHeight = 420
                    adjustWindowFrame()
                }
            }) {
                Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                    .font(.system(size: 10)).foregroundColor(.primary.opacity(0.7))
            }.buttonStyle(PlainButtonStyle())
        }
        .background(
            Color.white.opacity(0.001)
                .overlay(NativeDragView(onDragEnded: { adjustWindowFrame() }, onTap: {}))
        )
        .padding(.horizontal, 10)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(VisualEffectView(material: .windowBackground, blendingMode: .behindWindow))
    }
}
