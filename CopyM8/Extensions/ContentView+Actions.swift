import SwiftUI
import AppKit

extension ContentView {
    /// Swaps the currently selected clipboard item with the adjacent item in the `displayNodes` list.
    /// Updates both the underlying `history` array and the UI selection index.
    /// - Parameter up: `true` to move the item up (decrease index), `false` to move it down.
    func moveSelectedItem(up: Bool) {
        let nodes = displayNodes
        guard viewModel.selectedIndex >= 0 && viewModel.selectedIndex < nodes.count else { return }
        
        let targetIndex = up ? viewModel.selectedIndex - 1 : viewModel.selectedIndex + 1
        guard targetIndex >= 0 && targetIndex < nodes.count else { return }
        
        if let item1 = nodes[viewModel.selectedIndex].item, let item2 = nodes[targetIndex].item {
            if let idx1 = clipboard.history.firstIndex(where: { $0.id == item1.id }),
               let idx2 = clipboard.history.firstIndex(where: { $0.id == item2.id }) {
                clipboard.history.swapAt(idx1, idx2)
                viewModel.selectedIndex = targetIndex
            }
        }
    }

    /// Swaps the currently selected folder with the adjacent folder in the `folders` list.
    /// Updates both the underlying `folders` array and the UI selection index.
    /// - Parameter up: `true` to move the folder up (decrease index), `false` to move it down.
    func moveSelectedFolder(up: Bool) {
        guard viewModel.selectedIndex >= 0 && viewModel.selectedIndex < clipboard.folders.count else { return }
        let targetIndex = up ? viewModel.selectedIndex - 1 : viewModel.selectedIndex + 1
        guard targetIndex >= 0 && targetIndex < clipboard.folders.count else { return }
        
        clipboard.folders.swapAt(viewModel.selectedIndex, targetIndex)
        viewModel.selectedIndex = targetIndex
    }

    /// Permanently deletes all items currently selected in Edit Mode.
    /// Clears the selection state and exits Edit Mode upon completion.
    func deleteSelectedItems() {
        clipboard.deleteItems(where: { viewModel.selectedItemsForDeletion.contains($0.id) }, hardDelete: true)
        viewModel.selectedItemsForDeletion.removeAll()
        viewModel.isEditMode = false
    }

    /// Deletes the folders currently selected in Edit Mode.
    /// Can optionally preserve the items contained within those folders by moving them to the Pinned list.
    /// - Parameter keepItems: `true` to un-file and pin the items, `false` to permanently delete them with the folder.
    func deleteFolders(keepItems: Bool) {
        let folderIds = viewModel.selectedItemsForDeletion.filter { id in clipboard.folders.contains(where: { $0.id == id }) && id != cloudFolderId }
        let independentItemIds = viewModel.selectedItemsForDeletion.filter { id in !clipboard.folders.contains(where: { $0.id == id }) }
        
        if keepItems {
            for i in 0..<clipboard.history.count {
                if let fId = clipboard.history[i].folderId, folderIds.contains(fId) {
                    clipboard.setFolderId(for: [clipboard.history[i].id], folderId: nil)
                    clipboard.history[i].isPinned = true
                }
            }
        } else {
            clipboard.deleteItems(where: { item in
                if let fId = item.folderId { return folderIds.contains(fId) }
                return false
            }, hardDelete: true)
        }
        
        clipboard.folders.removeAll { folderIds.contains($0.id) }
        clipboard.deleteItems(where: { independentItemIds.contains($0.id) }, hardDelete: true)
        
        viewModel.selectedItemsForDeletion.removeAll()
        viewModel.isEditMode = false
    }

    /// Removes the selected items from their current folder assignments.
    /// - Parameter pin: `true` to pin the items after ungrouping, `false` to leave them unpinned (subject to eviction).
    func ungroupSelectedItems(pin: Bool) {
        for i in 0..<clipboard.history.count {
            if viewModel.selectedItemsForDeletion.contains(clipboard.history[i].id) {
                clipboard.setFolderId(for: [clipboard.history[i].id], folderId: nil)
                if pin {
                    clipboard.history[i].isPinned = true
                }
            }
        }
        viewModel.selectedItemsForDeletion.removeAll()
        viewModel.isEditMode = false
    }

    /// Initiates a paste operation for a specific item in the display list.
    /// Prepares the pasteboard, collapses the app window, re-activates the previously focused app,
    /// and synthesizes a `Cmd+V` keystroke.
    /// - Parameters:
    ///   - index: The index of the item within the `displayNodes` array.
    ///   - format: The requested paste format (plain text, rich text, etc.).
    func pasteItem(index: Int, format: PasteFormatType = .plain) {
        if index >= 0 && index < displayNodes.count {
            if let item = displayNodes[index].item {
                clipboard.prepareForPaste(item, formatType: format)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { shortcut.isExpanded = false }
                previousApp?.activate(options: [])
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { clipboard.triggerPasteKeystroke() }
            }
        }
    }
}
