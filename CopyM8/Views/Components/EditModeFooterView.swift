import SwiftUI

struct EditModeFooterView: View {
    @EnvironmentObject var clipboard: ClipboardManager
    @Binding var selectedItemsForDeletion: Set<UUID>
    @Binding var isEditMode: Bool
    @Binding var showingDeleteSelectedAlert: Bool
    
    var body: some View {
        HStack {
            Button(action: {
                if selectedItemsForDeletion.count == clipboard.history.count { selectedItemsForDeletion.removeAll() }
                else { selectedItemsForDeletion = Set(clipboard.history.map { $0.id }) }
            }) {
                Text(selectedItemsForDeletion.count == clipboard.history.count ? "Deselect All" : "Select All")
                    .font(.system(size: 11)).foregroundColor(.primary.opacity(0.6))
            }.buttonStyle(PlainButtonStyle())
            .onHover { hover in if hover { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            
            Spacer()
            
            Button(action: {
                for id in selectedItemsForDeletion { clipboard.togglePin(for: id) }
                selectedItemsForDeletion.removeAll()
                isEditMode = false
            }) {
                Text("Pin Selected")
                    .font(.system(size: 11, weight: .bold)).foregroundColor(.primary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.primary.opacity(0.1)).cornerRadius(6)
            }.buttonStyle(PlainButtonStyle())
            .onHover { hover in if hover { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            
            Button(action: {
                if !selectedItemsForDeletion.isEmpty { showingDeleteSelectedAlert = true }
            }) {
                Text("Delete Selected (\(selectedItemsForDeletion.count))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(selectedItemsForDeletion.isEmpty ? .primary.opacity(0.4) : .white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(selectedItemsForDeletion.isEmpty ? Color.primary.opacity(0.1) : Color.red.opacity(0.8))
                    .cornerRadius(6)
            }.buttonStyle(PlainButtonStyle())
            .disabled(selectedItemsForDeletion.isEmpty)
            .onHover { hover in
                if !selectedItemsForDeletion.isEmpty { if hover { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            }
            .alert("Delete selected items?", isPresented: $showingDeleteSelectedAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    clipboard.history.removeAll { selectedItemsForDeletion.contains($0.id) }
                    selectedItemsForDeletion.removeAll()
                    isEditMode = false
                }
            } message: {
                Text("Are you sure you want to delete \(selectedItemsForDeletion.count) items? This action cannot be undone.")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 12).background(Color.primary.opacity(0.05))
    }
}
