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
                    .foregroundColor(.white)
                    
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
        
        switch reorderTarget {
        case .pinned:
            var pinned = clipboard.history.filter { $0.isPinned && $0.folderId == nil }
            pinned.sort { item1, item2 in
                if item1.orderIndex > 0 && item2.orderIndex > 0 { return item1.orderIndex < item2.orderIndex }
                if item1.orderIndex > 0 { return true }
                if item2.orderIndex > 0 { return false }
                return item1.timestamp > item2.timestamp
            }
            
            for (i, item) in pinned.enumerated() {
                if let idx = clipboard.history.firstIndex(where: { $0.id == item.id }) {
                    clipboard.history[idx].orderIndex = i < freezeLimit ? (i + 1) : 0
                }
            }
            
        case .items(let folderId):
            var items = clipboard.history.filter { $0.folderId == folderId }
            items.sort { item1, item2 in
                if item1.orderIndex > 0 && item2.orderIndex > 0 { return item1.orderIndex < item2.orderIndex }
                if item1.orderIndex > 0 { return true }
                if item2.orderIndex > 0 { return false }
                return item1.timestamp > item2.timestamp
            }
            
            for (i, item) in items.enumerated() {
                if let idx = clipboard.history.firstIndex(where: { $0.id == item.id }) {
                    clipboard.history[idx].orderIndex = i < freezeLimit ? (i + 1) : 0
                }
            }
            
        case .folders:
            // Folders are strictly manually ordered, so orderIndex is just sequential
            for i in 0..<clipboard.folders.count {
                clipboard.folders[i].orderIndex = i + 1
            }
        case .none:
            break
        }
        
        clipboard.isReordering = false
        clipboard.saveHistory()
        clipboard.saveFolders()
        selectedItemsForDeletion.removeAll()
        isReorderMode = false
    }
}
