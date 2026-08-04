import Foundation
import AppKit

extension ClipboardManager {
    func reorderFolders(source: IndexSet, destination: Int) {
        folders.move(fromOffsets: source, toOffset: destination)
        for i in folders.indices {
            folders[i].orderIndex = i + 1
        }
    }

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

    func moveItem(up: Bool, id: UUID) {
        moveItems(up: up, ids: [id])
    }

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

    func moveFolder(up: Bool, id: UUID) {
        moveFolders(up: up, ids: [id])
    }

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
            
case .none:
            break
        }
    }

}
