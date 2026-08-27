import SwiftUI

struct ReorderFooterView: View {
    @EnvironmentObject var clipboard: ClipboardManager
    @Binding var isReorderMode: Bool
    @Binding var reorderTarget: ReorderTarget?
    @Binding var reorderFreezeLimit: String
    var isFreezeFieldFocused: FocusState<Bool>.Binding
    var isPlayFromFocused: FocusState<Bool>.Binding
    @Binding var reorderQueuePlayhead: String
    @Binding var reorderBackupHistory: [ClipboardItem]
    @Binding var reorderBackupFolders: [ClipboardFolder]
    @Binding var reorderBackupQueueIDs: [UUID]
    @Binding var selectedItemsForDeletion: Set<UUID>
    
    @State private var footerWidth: CGFloat = 300
    
    var body: some View {
        HStack {
            if reorderTarget == .queue {
                HStack(spacing: 6) {
                    Text("Play From ⌃P")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary.opacity(0.8))
                    
                    TextField("1", text: Binding(
                        get: { reorderQueuePlayhead },
                        set: { newValue in
                            let filtered = newValue.filter { "0123456789".contains($0) }
                            reorderQueuePlayhead = filtered
                        }
                    ))
                    .focused(isPlayFromFocused)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 11, weight: .medium))
                    .multilineTextAlignment(.center)
                    .frame(width: 30)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.1))
                    .cornerRadius(4)
                    .foregroundColor(isPlayFromFocused.wrappedValue ? .primary : .primary.opacity(0.8))
                    .allowsHitTesting(false)
                }
            } else if reorderTarget == .pinned || (reorderTarget != .folders && { if case .items = reorderTarget { return true } else { return false } }()) {
                HStack(spacing: 6) {
                    Text("Freeze Top ⌃F")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary.opacity(0.8))
                    
                    TextField("0", text: Binding(
                        get: { reorderFreezeLimit },
                        set: { newValue in
                            let filtered = newValue.filter { "0123456789".contains($0) }
                            if let num = Int(filtered), num <= 10 {
                                reorderFreezeLimit = filtered.isEmpty ? "0" : filtered
                            } else if filtered.isEmpty {
                                reorderFreezeLimit = ""
                            }
                        }
                    ))
                    .focused(isFreezeFieldFocused)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 11, weight: .medium))
                    .multilineTextAlignment(.center)
                    .frame(width: 30)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.1))
                    .cornerRadius(4)
                    .foregroundColor(isFreezeFieldFocused.wrappedValue ? .primary : .primary.opacity(0.8))
                    .allowsHitTesting(false)
                    
                    Text("Rows")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary.opacity(0.8))
                }
            } else {
                Text("Reorder Folders")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary.opacity(0.8))
            }
            
            Spacer()
            
            GhostHoverButton(
                icon: "checkmark.circle.fill",
                text: reorderTarget == .queue ? "Save Queue Sequence" : "Save",
                shortcut: "↵",
                color: .blue,
                isDisabled: false,
                maxWidth: reorderTarget == .queue ? footerWidth / 2.2 : footerWidth / 3,
                action: saveReorder
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.05))
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { footerWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { newValue in footerWidth = newValue }
            }
        )
    }
    
    private func cancelReorder() {
        if reorderTarget != .queue {
            clipboard.history = reorderBackupHistory
            clipboard.folders = reorderBackupFolders
            clipboard.isReordering = false
        } else {
            clipboard.queueIDs = reorderBackupQueueIDs
        }
        isReorderMode = false
    }
    
    private func saveReorder() {
        if reorderTarget == .queue {
            if let newPlayhead = Int(reorderQueuePlayhead) {
                let clampedPlayhead = max(0, min(newPlayhead - 1, clipboard.queueIDs.count - 1))
                clipboard.queuePlayheadIndex = clampedPlayhead
            }
            clipboard.saveQueueState()
        } else {
            let freezeLimit = Int(reorderFreezeLimit) ?? 0
            clipboard.applyReorder(target: reorderTarget, freezeLimit: freezeLimit)
        }
        
        selectedItemsForDeletion.removeAll()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if reorderTarget != .queue {
                clipboard.isReordering = false
            }
            isReorderMode = false
        }
    }
}
