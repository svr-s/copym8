import SwiftUI
import AppKit

struct HeaderView: View {
    @EnvironmentObject var clipboard: ClipboardManager
    @Binding var isHoveringClose: Bool
    @Binding var isEditMode: Bool
    @Binding var selectedItemsForDeletion: Set<UUID>
    @Binding var showingEmptyToast: Bool
    @Binding var showingClearAlert: Bool
    @Binding var isDense: Bool
    @Binding var windowWidth: Double
    @Binding var windowHeight: Double
    @Binding var showingSettings: Bool
    @Binding var draftHistoryCount: Int
    @Binding var maxHistoryCount: Int
    
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
                if hover { NSCursor.pointingHand.push() } else { NSCursor.pop() }
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
                    .foregroundColor(isEditMode ? Color.accentColor : .primary.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hover in if hover { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            
            Button(action: {
                if clipboard.history.isEmpty {
                    withAnimation { showingEmptyToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { showingEmptyToast = false } }
                } else {
                    showingClearAlert = true
                }
            }) {
                Image(systemName: "trash").font(.system(size: 11)).foregroundColor(.primary.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hover in if hover { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            .alert("Clear all copied items?", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) { clipboard.clearAll() }
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: "infinity").font(.system(size: 14, weight: .bold))
                Text("CopyM8").font(.system(size: 13, weight: .black, design: .rounded))
            }.foregroundColor(.primary)
                
            Spacer()
            
            HStack(spacing: 0) {
                Text(windowWidth < 360 ? "D..." : "Dense")
                    .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                    .font(.system(size: 9, weight: isDense ? .bold : .regular))
                    .foregroundColor(isDense ? .primary : .primary.opacity(0.5))
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(isDense ? Color.primary.opacity(0.15) : Color.clear).cornerRadius(4)
                    .onTapGesture { isDense = true }
                Text(windowWidth < 360 ? "S..." : "Spaced")
                    .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                    .font(.system(size: 9, weight: !isDense ? .bold : .regular))
                    .foregroundColor(!isDense ? .primary : .primary.opacity(0.5))
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(!isDense ? Color.primary.opacity(0.15) : Color.clear).cornerRadius(4)
                    .onTapGesture { isDense = false }
            }.background(Color.primary.opacity(0.05)).cornerRadius(4)
            
            Button(action: { showingSettings.toggle() }) {
                Image(systemName: "gearshape").font(.system(size: 11)).foregroundColor(.primary.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hover in if hover { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            .popover(isPresented: $showingSettings, arrowEdge: .bottom) {
                SettingsView(draftHistoryCount: $draftHistoryCount, maxHistoryCount: $maxHistoryCount)
            }
            .onChange(of: showingSettings) { _, isShowing in
                if isShowing { draftHistoryCount = maxHistoryCount } else { maxHistoryCount = max(5, draftHistoryCount) }
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
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(VisualEffectView(material: .windowBackground, blendingMode: .behindWindow))
    }
}
