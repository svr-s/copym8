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
    
    var body: some View {
        HStack {
            Button(action: cancelReorder) {
                Text("Cancel")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            if reorderTarget != .folders {
                HStack(spacing: 6) {
                    Text("Freeze Top")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
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
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(4)
                    .foregroundColor(isFreezeFieldFocused.wrappedValue ? .blue : .white)
                    .allowsHitTesting(false)
                    
                    Text("Rows")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            } else {
                Text("Reorder Folders")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            Button(action: saveReorder) {
                Text("Save")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue)
                    .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.5))
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
