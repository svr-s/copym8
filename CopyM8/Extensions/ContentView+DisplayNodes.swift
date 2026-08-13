import SwiftUI
import AppKit

extension ContentView {
    /// A dynamically computed list of nodes representing the current view state of the clipboard.
    /// This property translates the raw `history` and `folders` arrays into a flat list of `DisplayNode`s
    /// suitable for rendering in a `LazyVStack`. It handles filtering, sorting, and injecting divider nodes.
    var displayNodes: [DisplayNode] {
        if viewModel.isReorderMode {
            switch viewModel.reorderTarget {
            case .folders:
                return clipboard.folders.filter { $0.id != cloudFolderId && $0.id != restoredFolderId }.map { DisplayNode(id: "folder_\($0.id.uuidString)", isFolder: true, folder: $0, item: nil, parentFolderId: nil) }
            case .items(let folderId):
                var items = clipboard.activeHistory.filter { !($0.isDeleted ?? false) && $0.folderId == folderId }
                items.sort { item1, item2 in
                    if item1.orderIndex > 0 && item2.orderIndex > 0 { return item1.orderIndex < item2.orderIndex }
                    if item1.orderIndex > 0 { return true }
                    if item2.orderIndex > 0 { return false }
                    return item1.timestamp > item2.timestamp
                }
                var nodes: [DisplayNode] = []
                let freezeLimit = Int(viewModel.reorderFreezeLimit) ?? 0
                for (i, item) in items.enumerated() {
                    if i == freezeLimit && freezeLimit > 0 {
                        nodes.append(DisplayNode(id: "divider_reorder", isFolder: false, folder: nil, item: nil, parentFolderId: folderId, isDivider: true))
                    }
                    nodes.append(DisplayNode(id: "item_\(item.id.uuidString)", isFolder: false, folder: nil, item: item, parentFolderId: folderId))
                }
                return nodes
            case .pinned:
                var items = clipboard.activeHistory.filter { !($0.isDeleted ?? false) && $0.isPinned && $0.folderId == nil }
                items.sort { item1, item2 in
                    if item1.orderIndex > 0 && item2.orderIndex > 0 { return item1.orderIndex < item2.orderIndex }
                    if item1.orderIndex > 0 { return true }
                    if item2.orderIndex > 0 { return false }
                    return item1.timestamp > item2.timestamp
                }
                var nodes: [DisplayNode] = []
                let freezeLimit = Int(viewModel.reorderFreezeLimit) ?? 0
                for (i, item) in items.enumerated() {
                    if i == freezeLimit && freezeLimit > 0 {
                        nodes.append(DisplayNode(id: "divider_reorder", isFolder: false, folder: nil, item: nil, parentFolderId: nil, isDivider: true))
                    }
                    nodes.append(DisplayNode(id: "item_\(item.id.uuidString)", isFolder: false, folder: nil, item: item, parentFolderId: nil))
                }
                return nodes
            case .none:
                return []
            }
        }
        
        if viewModel.activeTab == "Queue" {
            var nodes: [DisplayNode] = []
            for (index, id) in clipboard.queueIDs.enumerated() {
                if let item = clipboard.history.first(where: { $0.id == id }) {
                    let status: QueueStatus
                    if index < clipboard.queuePlayheadIndex {
                        status = .pasted
                    } else if index == clipboard.queuePlayheadIndex {
                        status = .next
                    } else {
                        status = .upcoming
                    }
                    nodes.append(DisplayNode(id: "item_\(item.id.uuidString)", isFolder: false, folder: nil, item: item, parentFolderId: nil, queueStatus: status))
                }
            }
            return nodes
        }
        
        if viewModel.activeTab == "Trash" {
            var items = clipboard.history.filter { ($0.isDeleted ?? false) }
            
            if !viewModel.searchText.isEmpty {
                let searchLower = viewModel.searchText.lowercased()
                items = items.filter { item in
                    let contentMatch = item.text.lowercased().contains(searchLower)
                    let sourceMatch = item.sourceApp?.lowercased().contains(searchLower) ?? false
                    return contentMatch || sourceMatch
                }
            }
            
            items.sort { $0.deletedAt ?? Date() > $1.deletedAt ?? Date() }
            
            var nodes: [DisplayNode] = []
            for item in items {
                nodes.append(DisplayNode(id: "item_\(item.id.uuidString)", isFolder: false, folder: nil, item: item, parentFolderId: nil))
            }
            return nodes
        }
        
        if viewModel.activeTab == "Groups" {
            let filteredFolders = clipboard.getFilteredFolders(searchText: viewModel.searchText)
            var nodes: [DisplayNode] = []
            
            for folder in filteredFolders {
                nodes.append(DisplayNode(id: "folder_\(folder.id.uuidString)", isFolder: true, folder: folder, item: nil, parentFolderId: nil))
                
                if viewModel.expandedFolderIds.contains(folder.id) {
                    var items = clipboard.activeHistory.filter { !($0.isDeleted ?? false) && $0.folderId == folder.id }
                    if !viewModel.searchText.isEmpty {
                        let bypassFilter = folder.name.localizedCaseInsensitiveContains(viewModel.searchText)
                        if !bypassFilter {
                            items = items.filter { item in
                                if item.text.localizedCaseInsensitiveContains(viewModel.searchText) { return true }
                                if item.sourceApp?.localizedCaseInsensitiveContains(viewModel.searchText) == true { return true }
                                return false
                            }
                        }
                    }
                    
                    items.sort { item1, item2 in
                        if item1.orderIndex > 0 && item2.orderIndex > 0 { return item1.orderIndex < item2.orderIndex }
                        if item1.orderIndex > 0 { return true }
                        if item2.orderIndex > 0 { return false }
                        return item1.timestamp > item2.timestamp
                    }
                    
                    var addedDivider = false
                    let hasFrozen = items.contains(where: { $0.orderIndex > 0 })
                    for item in items {
                        if item.orderIndex == 0 && !addedDivider && hasFrozen {
                            nodes.append(DisplayNode(id: "divider_\(folder.id.uuidString)", isFolder: false, folder: nil, item: nil, parentFolderId: folder.id, isDivider: true))
                            addedDivider = true
                        }
                        nodes.append(DisplayNode(id: "item_\(item.id.uuidString)", isFolder: false, folder: nil, item: item, parentFolderId: folder.id))
                    }
                }
            }
            return nodes
        } else {
            // Re-use existing filteredHistory logic
            var results = clipboard.activeHistory.filter { !($0.isDeleted ?? false) }
            
            switch viewModel.activeTab {
            case "Pinned": results = results.filter { $0.isPinned && $0.folderId == nil }
            case "Text": results = results.filter { $0.itemType == .text }
            case "Links": results = results.filter { $0.itemType == .link }
            case "Images": results = results.filter { $0.itemType == .image }
            case "Files": results = results.filter { $0.itemType == .file }
            default:
                let customTab8 = UserDefaults.standard.string(forKey: "customTab8") ?? ""
                let customTab9 = UserDefaults.standard.string(forKey: "customTab9") ?? ""
                let customTab0 = UserDefaults.standard.string(forKey: "customTab0") ?? ""
                
                if viewModel.activeTab == customTab8 && !customTab8.isEmpty {
                    results = results.filter { $0.sourceApp == customTab8 }
                } else if viewModel.activeTab == customTab9 && !customTab9.isEmpty {
                    results = results.filter { $0.sourceApp == customTab9 }
                } else if viewModel.activeTab == customTab0 && !customTab0.isEmpty {
                    results = results.filter { $0.sourceApp == customTab0 }
                }
            }
            
            if !viewModel.searchText.isEmpty {
                results = results.filter { item in
                    if item.text.localizedCaseInsensitiveContains(viewModel.searchText) { return true }
                    if item.sourceApp?.localizedCaseInsensitiveContains(viewModel.searchText) == true { return true }
                    if let folderId = item.folderId, let folder = clipboard.activeFolders.first(where: { $0.id == folderId }) {
                        if folder.name.localizedCaseInsensitiveContains(viewModel.searchText) { return true }
                    }
                    return false
                }
            }
            
            if viewModel.activeTab == "Pinned" {
                results.sort { item1, item2 in
                    if item1.orderIndex > 0 && item2.orderIndex > 0 { return item1.orderIndex < item2.orderIndex }
                    if item1.orderIndex > 0 { return true }
                    if item2.orderIndex > 0 { return false }
                    return item1.timestamp > item2.timestamp
                }
                
                var nodes: [DisplayNode] = []
                var addedDivider = false
                let hasFrozen = results.contains(where: { $0.orderIndex > 0 })
                
                for item in results {
                    if item.orderIndex == 0 && !addedDivider && hasFrozen {
                        nodes.append(DisplayNode(id: "divider_pinned", isFolder: false, folder: nil, item: nil, parentFolderId: nil, isDivider: true))
                        addedDivider = true
                    }
                    nodes.append(DisplayNode(id: "item_\(item.id.uuidString)", isFolder: false, folder: nil, item: item, parentFolderId: nil))
                }
                return nodes
            }
            
            return results.map { DisplayNode(id: "item_\($0.id.uuidString)", isFolder: false, folder: nil, item: $0, parentFolderId: nil) }
        }
    }
}
