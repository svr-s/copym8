import Foundation
import AppKit

extension ClipboardManager {
    /// Reorders the list of folders based on a drag-and-drop operation.
    /// Updates the `orderIndex` of each folder to reflect its new position.
    /// - Parameters:
    ///   - source: The original index set of the dragged folders.
    ///   - destination: The target insertion index.
    func reorderFolders(source: IndexSet, destination: Int) {
        folders.move(fromOffsets: source, toOffset: destination)
        for i in folders.indices {
            folders[i].orderIndex = i + 1
        }
    }

    /// Reorders items within a specific folder based on a drag-and-drop operation.
    /// Updates the `orderIndex` to persist the manual sort order.
    /// - Parameters:
    ///   - folderId: The UUID of the folder containing the items.
    ///   - source: The original index set of the dragged items.
    ///   - destination: The target insertion index.
    func reorderGroupItems(folderId: UUID, source: IndexSet, destination: Int) {
        var items = history.filter { $0.folderId == folderId }
        items.sort { item1, item2 in
            if item1.orderIndex > 0 && item2.orderIndex > 0 { return item1.orderIndex < item2.orderIndex }
            if item1.orderIndex > 0 { return true }
            if item2.orderIndex > 0 { return false }
            return item1.timestamp > item2.timestamp
        }
        items.move(fromOffsets: source, toOffset: destination)
        for i in 0..<items.count {
            if let idx = history.firstIndex(where: { $0.id == items[i].id }) {
                history[idx].orderIndex = i + 1
            }
        }
        saveHistory()
    }

    /// Reorders unassigned, pinned items based on a drag-and-drop operation.
    /// Calculates a `maxIndexToFreeze` to ensure items shifted out of manually ordered positions
    /// revert back to temporal sorting if they lose their explicit `orderIndex`.
    /// - Parameters:
    ///   - source: The original index set of the dragged items.
    ///   - destination: The target insertion index.
    func reorderPinnedItems(source: IndexSet, destination: Int) {
        var items = history.filter { $0.isPinned && $0.folderId == nil }
        items.sort { item1, item2 in
            if item1.orderIndex > 0 && item2.orderIndex > 0 { return item1.orderIndex < item2.orderIndex }
            if item1.orderIndex > 0 { return true }
            if item2.orderIndex > 0 { return false }
            return item1.timestamp > item2.timestamp
        }
        
        var maxIndexToFreeze = -1
        for (i, item) in items.enumerated() { if item.orderIndex > 0 { maxIndexToFreeze = max(maxIndexToFreeze, i) } }
        maxIndexToFreeze = max(maxIndexToFreeze, destination - (destination > (source.first ?? 0) ? 1 : 0))
        
        items.move(fromOffsets: source, toOffset: destination)
        
        if maxIndexToFreeze >= 0 {
            for i in 0...maxIndexToFreeze {
                if i < items.count {
                    if let idx = history.firstIndex(where: { $0.id == items[i].id }) {
                        history[idx].orderIndex = i + 1
                    }
                }
            }
        }
        saveHistory()
    }

    /// Moves a single item up or down in its current list (pinned or folder).
    /// - Parameters:
    ///   - up: `true` to move the item up (lower index), `false` to move it down.
    ///   - id: The UUID of the item to move.
    func moveItem(up: Bool, id: UUID) {
        moveItems(up: up, ids: [id])
    }

    /// Moves multiple selected items up or down in their current list.
    /// - Parameters:
    ///   - up: `true` to move the items up, `false` to move them down.
    ///   - ids: An array of UUIDs of the items to move.
    func moveItems(up: Bool, ids: [UUID]) {
        guard !ids.isEmpty else { return }
        guard let firstItem = history.first(where: { $0.id == ids.first }) else { return }
        
        var items: [ClipboardItem]
        if firstItem.isPinned && firstItem.folderId == nil {
            items = history.filter { $0.isPinned && $0.folderId == nil }
        } else if let folderId = firstItem.folderId {
            items = history.filter { $0.folderId == folderId }
        } else {
            return
        }
        
        items.sort { item1, item2 in
            if item1.orderIndex > 0 && item2.orderIndex > 0 { return item1.orderIndex < item2.orderIndex }
            if item1.orderIndex > 0 { return true }
            if item2.orderIndex > 0 { return false }
            return item1.timestamp > item2.timestamp
        }
        
        let indices = ids.compactMap { id in items.firstIndex(where: { $0.id == id }) }.sorted()
        guard !indices.isEmpty else { return }
        
        var source = IndexSet()
        for idx in indices { source.insert(idx) }
        
        if up {
            guard indices.first! > 0 else { return }
            let dest = indices.first! - 1
            if firstItem.isPinned && firstItem.folderId == nil {
                reorderPinnedItems(source: source, destination: dest)
            } else if let folderId = firstItem.folderId {
                reorderGroupItems(folderId: folderId, source: source, destination: dest)
            }
        } else {
            guard indices.last! < items.count - 1 else { return }
            let dest = indices.last! + 2
            if firstItem.isPinned && firstItem.folderId == nil {
                reorderPinnedItems(source: source, destination: dest)
            } else if let folderId = firstItem.folderId {
                reorderGroupItems(folderId: folderId, source: source, destination: dest)
            }
        }
    }

    /// Moves a single folder up or down in the sidebar list.
    /// - Parameters:
    ///   - up: `true` to move the folder up, `false` to move it down.
    ///   - id: The UUID of the folder to move.
    func moveFolder(up: Bool, id: UUID) {
        moveFolders(up: up, ids: [id])
    }

    /// Moves multiple selected folders up or down in the sidebar list.
    /// Prevents movement above the "Cloud Copy" folder if it exists.
    /// - Parameters:
    ///   - up: `true` to move the folders up, `false` to move them down.
    ///   - ids: An array of UUIDs of the folders to move.
    func moveFolders(up: Bool, ids: [UUID]) {
        let validIds = ids.filter { $0 != cloudFolderId }
        guard !validIds.isEmpty else { return }
        let indices = validIds.compactMap { id in folders.firstIndex(where: { $0.id == id }) }.sorted()
        guard !indices.isEmpty else { return }
        
        var source = IndexSet()
        for idx in indices { source.insert(idx) }
        
        let limit = (folders.first?.id == cloudFolderId) ? 1 : 0
        
        if up {
            guard indices.first! > limit else { return }
            let dest = indices.first! - 1
            reorderFolders(source: source, destination: dest)
        } else {
            guard indices.last! < folders.count - 1 else { return }
            let dest = indices.last! + 2
            reorderFolders(source: source, destination: dest)
        }
    }

    /// Finalizes a reordering operation by updating the `orderIndex` properties
    /// of the affected items up to the specified `freezeLimit`. Items beyond the limit
    /// have their `orderIndex` reset to 0 (default temporal sorting).
    /// - Parameters:
    ///   - target: The target context of the reorder (e.g., pinned items, specific folder, or folders list).
    ///   - freezeLimit: The index up to which items should retain an explicit sort order.
    func applyReorder(target: ReorderTarget?, freezeLimit: Int) {
        switch target {
        case .pinned:
            var pinned = history.filter { $0.isPinned && $0.folderId == nil }
            pinned.sort { item1, item2 in
                if item1.orderIndex > 0 && item2.orderIndex > 0 { return item1.orderIndex < item2.orderIndex }
                if item1.orderIndex > 0 { return true }
                if item2.orderIndex > 0 { return false }
                return item1.timestamp > item2.timestamp
            }
            for (i, item) in pinned.enumerated() {
                if let idx = history.firstIndex(where: { $0.id == item.id }) {
                    history[idx].orderIndex = i < freezeLimit ? (i + 1) : 0
                }
            }
            saveHistory()
            
        case .items(let folderId):
            var items = history.filter { $0.folderId == folderId }
            items.sort { item1, item2 in
                if item1.orderIndex > 0 && item2.orderIndex > 0 { return item1.orderIndex < item2.orderIndex }
                if item1.orderIndex > 0 { return true }
                if item2.orderIndex > 0 { return false }
                return item1.timestamp > item2.timestamp
            }
            for (i, item) in items.enumerated() {
                if let idx = history.firstIndex(where: { $0.id == item.id }) {
                    history[idx].orderIndex = i < freezeLimit ? (i + 1) : 0
                }
            }
            saveHistory()
            
        case .folders:
            for i in 0..<folders.count {
                folders[i].orderIndex = i + 1
            }
            saveFolders()
            
        case .queue:
            break
            
        case .none:
            break
        }
    }

}
