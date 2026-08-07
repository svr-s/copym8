import SwiftUI

struct ReorderFooterView: View {
    @EnvironmentObject var clipboard: ClipboardManager
    @Binding var isReorderMode: Bool
    @Binding var reorderTarget: ReorderTarget?
    @Binding var reorderFreezeLimit: String
    var isFreezeFieldFocused: FocusState<Bool>.Binding
    @Binding var reorderBackupHistory: [ClipboardItem]
    @Binding var reorderBackupFolders: [ClipboardFolder]
    @Binding var selectedItemsForDeletion: Set<UUID>
    
    @State private var footerWidth: CGFloat = 300
    
    var body: some View {
        HStack {
            Spacer()
            
            if reorderTarget != .folders {
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
                text: "Save",
                shortcut: "↵",
                color: .blue,
                isDisabled: false,
                maxWidth: footerWidth / 3,
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
        clipboard.history = reorderBackupHistory
        clipboard.folders = reorderBackupFolders
        clipboard.isReordering = false
        isReorderMode = false
    }
    
    private func saveReorder() {
        let freezeLimit = Int(reorderFreezeLimit) ?? 0
        
        clipboard.applyReorder(target: reorderTarget, freezeLimit: freezeLimit)
        selectedItemsForDeletion.removeAll()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            clipboard.isReordering = false
            isReorderMode = false
        }
    }
}
