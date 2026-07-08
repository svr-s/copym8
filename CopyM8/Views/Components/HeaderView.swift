import SwiftUI
import AppKit

struct HeaderView: View {
    @EnvironmentObject var clipboard: ClipboardManager
    @Binding var isHoveringClose: Bool
    @Binding var isEditMode: Bool
    @Binding var selectedItemsForDeletion: Set<UUID>
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
            

            
            Spacer()
            
            HStack(spacing: 1) {
                Text("copym").font(.custom("Gill Sans", size: 15))
                Image(systemName: "infinity").font(.system(size: 19, weight: .heavy))
            }.foregroundColor(.primary)
                
            Spacer()
            
            Picker("", selection: $isDense) {
                Image(systemName: "rectangle.grid.1x3").tag(true)
                Image(systemName: "rectangle.grid.1x2").tag(false)
            }
            .pickerStyle(.segmented)
            .frame(width: 60)

            
            Button(action: { showingSettings.toggle() }) {
                Image(systemName: "gearshape").font(.system(size: 11)).foregroundColor(.primary.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hover in
                if hover { NSCursor.arrow.push() } else { NSCursor.pop() }
            }
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
