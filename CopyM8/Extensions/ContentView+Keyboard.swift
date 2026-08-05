import SwiftUI
import AppKit

extension ContentView {
    func handleKeyPress(_ event: NSEvent) -> NSEvent? {
        guard NSApplication.shared.windows.first?.isVisible == true else { return event }
            if SettingsWindowManager.shared.isSettingsOpen {
                return event
            }
            
            if viewModel.showingDeleteSelectedAlert || viewModel.showingFolderDeleteAlert || viewModel.showingUngroupAlert || viewModel.itemToAssignGroup != nil || viewModel.showingDeviceSwitcher || viewModel.showingEmptyTrashAlert {
                if event.keyCode == 53 {
                    if viewModel.itemToAssignGroup != nil { viewModel.itemToAssignGroup = nil }
                    if viewModel.showingDeviceSwitcher { viewModel.showingDeviceSwitcher = false }
                    return nil
                }
                return event
            }
            
            // GATEKEEPER for remote sources
            if clipboard.selectedDevice != "Local (This Mac)" {
                let isDestructiveShortcut: Bool = {
                    if event.modifierFlags.contains(.command) {
                        return [5, 35, 32, 15].contains(event.keyCode) // G, P, U, R
                            || event.keyCode == 125 || event.keyCode == 126 // Cmd+Up/Down
                    }
                    if event.keyCode == 51 || event.keyCode == 117 { // Delete, Backspace
                        return true
                    }
                    return false
                }()
                
                if isDestructiveShortcut {
                    if !viewModel.showingReadOnlyToast {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.showingReadOnlyToast = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.showingReadOnlyToast = false
                            }
                        }
                    }
                    return nil
                }
            }
            
            let activeTab = viewModel.activeTab
            let isEditMode = viewModel.isEditMode
            let expandedItemIndex = viewModel.expandedItemIndex
            let displayNodesLocal = self.displayNodes
            
            if event.modifierFlags.contains(.command) {
                switch event.keyCode {
                case 3: // F
                    if viewModel.isReorderMode && (viewModel.reorderTarget == .pinned || (viewModel.activeTab == "Groups" && viewModel.reorderTarget != .folders)) {
                        isFreezeFieldFocused = true
                    } else {
                        isSearchFocused = true
                    }
                    return nil
                case 34: // I
                    if clipboard.selectedDevice != "Local (This Mac)" {
                        var itemsToImport: [ClipboardItem] = []
                        if viewModel.isEditMode {
                            itemsToImport = clipboard.history.filter { viewModel.selectedItemsForDeletion.contains($0.id) }
                            viewModel.selectedItemsForDeletion.removeAll()
                            viewModel.isEditMode = false
                        } else if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                            let node = displayNodesLocal[viewModel.selectedIndex]
                            if !node.isFolder, let item = node.item {
                                itemsToImport.append(item)
                            }
                        }
                        if !itemsToImport.isEmpty {
                            clipboard.importItems(itemsToImport)
                        }
                    }
                    return nil
                case 37: // L
                    isDense.toggle()
                    return nil
                case 2: // D
                    if event.modifierFlags.contains(.shift) {
                        if !clipboard.availableDevices.isEmpty {
                            viewModel.showingDeviceSwitcher = true
                        }
                        return nil
                    }
                    return event
                case 15: // R
                    if viewModel.activeTab == "Pinned" || viewModel.activeTab == "Groups" {
                        if viewModel.isReorderMode {
                            viewModel.isReorderMode = false
                        } else {
                            viewModel.isEditMode = false
                            clipboard.isReordering = true
                            viewModel.isReorderMode = true
                            viewModel.reorderBackupHistory = clipboard.history
                            viewModel.reorderBackupFolders = clipboard.folders
                            
                            if viewModel.activeTab == "Pinned" {
                                viewModel.reorderTarget = .pinned
                                let pinned = clipboard.history.filter { $0.isPinned && $0.folderId == nil }
                                let frozenCount = pinned.filter { $0.orderIndex > 0 }.count
                                viewModel.reorderFreezeLimit = "\(frozenCount)"
                            } else if viewModel.activeTab == "Groups" {
                                if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                                    let node = displayNodesLocal[viewModel.selectedIndex]
                                    if node.isFolder {
                                        viewModel.reorderTarget = .folders
                                        viewModel.reorderFreezeLimit = "0"
                                    } else if let fid = node.parentFolderId {
                                        viewModel.reorderTarget = .items(folderId: fid)
                                        let items = clipboard.history.filter { $0.folderId == fid }
                                        let frozenCount = items.filter { $0.orderIndex > 0 }.count
                                        viewModel.reorderFreezeLimit = "\(frozenCount)"
                                    }
                                } else {
                                    viewModel.reorderTarget = .folders
                                    viewModel.reorderFreezeLimit = "0"
                                }
                            }
                            viewModel.selectedIndex = 0
                            viewModel.isReorderMode = true
                        }
                    }
                    return nil
                case 17: // T
                    let isCmd = event.modifierFlags.contains(.command)
                    let isShift = event.modifierFlags.contains(.shift)
                    if isCmd && isShift {
                        if clipboard.selectedDevice == "Local (This Mac)" {
                            if viewModel.activeTab == "Trash" {
                                viewModel.activeTab = viewModel.previousTab
                            } else {
                                viewModel.previousTab = viewModel.activeTab
                                viewModel.activeTab = "Trash"
                            }
                        }
                        return nil
                    }
                    return nil
                case 6: // Z
                    let isCmd = event.modifierFlags.contains(.command)
                    let isShift = event.modifierFlags.contains(.shift)
                    if isCmd && !isShift && viewModel.activeTab == "Trash" {
                        if viewModel.isEditMode {
                            let ids = Array(viewModel.selectedItemsForDeletion)
                            if !ids.isEmpty {
                                clipboard.restoreItems(ids: ids)
                                viewModel.selectedItemsForDeletion.removeAll()
                                viewModel.isEditMode = false
                            }
                        } else {
                            if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                                let node = displayNodesLocal[viewModel.selectedIndex]
                                if let id = node.item?.id {
                                    if viewModel.selectedIndex > 0 && viewModel.selectedIndex == displayNodesLocal.count - 1 { viewModel.selectedIndex -= 1 }
                                    clipboard.restoreItems(ids: [id])
                                }
                            }
                        }
                        return nil
                    }
                    if !clipboard.history.isEmpty {
                        // Undo logic would go here if needed, but 'Cmd+Z' to restore single item in Trash Bin is handled within TrashBinView.
                    }
                    return nil
                default: break
                }
            }
            
            if isSearchFocused || viewModel.editingFolderId != nil {
                let allowedWhenFocused: Set<UInt16> = [36, 48, 53, 125, 126, 123, 124]
                if !allowedWhenFocused.contains(event.keyCode) {
                    return event
                }
            }
            
            if event.modifierFlags.contains(.option) && event.keyCode == 15 { // Option + R
                if viewModel.activeTab == "Groups" && !viewModel.isEditMode && !viewModel.isReorderMode {
                    if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                        let node = displayNodesLocal[viewModel.selectedIndex]
                        if node.isFolder, let folder = node.folder {
                            if folder.id != cloudFolderId {
                                viewModel.editingFolderId = folder.id
                            }
                            return nil
                        }
                    }
                }
            }
            
            if event.modifierFlags.contains(.option) && event.keyCode != 48 && event.keyCode != 123 && event.keyCode != 15 {
                if viewModel.isReorderMode { return nil }
                var newTab: String? = nil
                switch event.keyCode {
                case 35, 19: newTab = "Pinned" // P or 2
                case 5, 20: newTab = "Groups" // G or 3
                case 17, 21: newTab = "Text" // T or 4
                case 37, 23: newTab = "Links" // L or 5
                case 34, 22: newTab = "Images" // I or 6
                case 3, 26: newTab = "Files" // F or 7
                case 0, 18: newTab = "All" // A or 1
                default: break
                }
                
                if let tab = newTab, tab != viewModel.activeTab {
                    withAnimation {
                        viewModel.activeTab = tab
                        viewModel.selectedIndex = 0
                        viewModel.expandedItemIndex = nil
                    }
                    return nil
                }
            }
            
            if let chars = event.charactersIgnoringModifiers, chars.count == 1 {
                let char = chars.uppercased()
                if viewModel.isReorderMode && char == "F" && event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) {
                    isFreezeFieldFocused.toggle()
                    return nil
                }
                
                if viewModel.activeTab == "Groups" && chars == "`" && !event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.control) && !event.modifierFlags.contains(.option) {
                    if let nodeIndex = displayNodesLocal.firstIndex(where: { $0.isFolder && $0.folder?.id == UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }) {
                        withAnimation {
                            viewModel.selectedIndex = nodeIndex
                            if !viewModel.expandedFolderIds.contains(UUID(uuidString: "00000000-0000-0000-0000-000000000000")!) {
                                viewModel.expandedFolderIds.insert(UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
                            } else {
                                viewModel.expandedFolderIds.remove(UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
                            }
                        }
                        return nil
                    }
                }

                if viewModel.activeTab == "Groups" && chars == "=" && !event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.control) && !event.modifierFlags.contains(.option) {
                    if let nodeIndex = displayNodesLocal.firstIndex(where: { $0.isFolder && $0.folder?.id == restoredFolderId }) {
                        withAnimation {
                            viewModel.selectedIndex = nodeIndex
                            if !viewModel.expandedFolderIds.contains(restoredFolderId) {
                                viewModel.expandedFolderIds.insert(restoredFolderId)
                            } else {
                                viewModel.expandedFolderIds.remove(restoredFolderId)
                            }
                        }
                        return nil
                    }
                }
                
                if viewModel.activeTab == "Groups" && char >= "A" && char <= "Z" && !event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.control) && !event.modifierFlags.contains(.option) {
                    let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                    if let letterIndex = alphabet.firstIndex(of: Character(char)) {
                        let folderIndex = alphabet.distance(from: alphabet.startIndex, to: letterIndex)
                        let standardFolders = clipboard.activeFolders.filter { $0.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }
                        if folderIndex < standardFolders.count {
                            let targetFolder = standardFolders[folderIndex]
                            if let nodeIndex = displayNodesLocal.firstIndex(where: { $0.isFolder && $0.folder?.id == targetFolder.id }) {
                                withAnimation {
                                    viewModel.selectedIndex = nodeIndex
                                    if !viewModel.expandedFolderIds.contains(targetFolder.id) {
                                        viewModel.expandedFolderIds.insert(targetFolder.id)
                                    } else {
                                        viewModel.expandedFolderIds.remove(targetFolder.id)
                                    }
                                }
                                return nil
                            }
                        }
                    }
                }
            }
            
            switch event.keyCode {
            case 18...29:
                if isFreezeFieldFocused { return nil }
                if viewModel.activeTab == "Trash" { return nil }
                let keyMap: [UInt16: Int] = [18: 0, 19: 1, 20: 2, 21: 3, 23: 4, 22: 5, 26: 6, 28: 7, 25: 8, 29: 9]
                if let relativeIndex = keyMap[event.keyCode] {
                    let hasCmd = event.modifierFlags.contains(.command)
                    let hasCtrl = event.modifierFlags.contains(.control)
                    let format: PasteFormatType = (hasCmd && hasCtrl) ? .richNoLinks : (hasCmd ? .rich : .plain)
                    if viewModel.activeTab == "Groups" {
                        var targetFolderId: UUID? = nil
                        if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                            let selectedNode = displayNodesLocal[viewModel.selectedIndex]
                            targetFolderId = selectedNode.isFolder ? selectedNode.folder?.id : selectedNode.parentFolderId
                        }
                        if let targetFolderId = targetFolderId {
                            let folderItemIndices = displayNodesLocal.indices.filter { displayNodesLocal[$0].parentFolderId == targetFolderId }
                            if relativeIndex < folderItemIndices.count {
                                pasteItem(index: folderItemIndices[relativeIndex], format: format)
                            }
                        }
                    } else {
                        if relativeIndex < displayNodesLocal.count {
                            pasteItem(index: relativeIndex, format: format)
                        }
                    }
                }
                return nil
            case 51: // Backspace
                let isCmd = event.modifierFlags.contains(.command)
                let isShift = event.modifierFlags.contains(.shift)
                
                if viewModel.activeTab == "Trash" {
                    if isCmd && isShift {
                        let hasItems = clipboard.history.contains { $0.isDeleted ?? false }
                        if hasItems { viewModel.showingEmptyTrashAlert = true }
                        return nil
                    }
                    if viewModel.isEditMode {
                        if !viewModel.selectedItemsForDeletion.isEmpty {
                            viewModel.showingDeleteSelectedAlert = true
                        }
                    } else {
                        if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                            if let id = displayNodesLocal[viewModel.selectedIndex].item?.id ?? displayNodesLocal[viewModel.selectedIndex].folder?.id {
                                viewModel.selectedItemsForDeletion = [id]
                                viewModel.showingDeleteSelectedAlert = true
                            }
                        }
                    }
                    return nil
                }
                

                if viewModel.isEditMode {
                    let validDeletions = viewModel.selectedItemsForDeletion.filter { $0 != cloudFolderId && $0 != restoredFolderId }
                    if !validDeletions.isEmpty {
                        if isCmd {
                            // Hard Delete (with popup)
                            viewModel.selectedItemsForDeletion = validDeletions
                            let hasFoldersSelected = validDeletions.contains { id in clipboard.folders.contains(where: { $0.id == id }) }
                            if hasFoldersSelected {
                                viewModel.showingFolderDeleteAlert = true
                            } else {
                                viewModel.showingDeleteSelectedAlert = true
                            }
                        } else {
                            // Soft Delete (no popup)
                            let folderIds = validDeletions.filter { id in clipboard.folders.contains(where: { $0.id == id }) }
                            let independentItemIds = validDeletions.filter { !folderIds.contains($0) }
                            
                            clipboard.deleteItems(where: { item in
                                if let fId = item.folderId { return folderIds.contains(fId) }
                                return false
                            })
                            clipboard.folders.removeAll { folderIds.contains($0.id) }
                            clipboard.deleteItems(where: { independentItemIds.contains($0.id) })
                            
                            viewModel.selectedItemsForDeletion.removeAll()
                            viewModel.isEditMode = false
                        }
                    }
                } else if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                    let node = displayNodesLocal[viewModel.selectedIndex]
                    if node.isFolder, let folder = node.folder {
                        if folder.id != cloudFolderId && folder.id != restoredFolderId {
                            if isCmd {
                                viewModel.selectedItemsForDeletion = [folder.id]
                                viewModel.showingFolderDeleteAlert = true
                            } else {
                                clipboard.deleteItems(where: { $0.folderId == folder.id })
                                clipboard.folders.removeAll(where: { $0.id == folder.id })
                                if viewModel.selectedIndex >= displayNodesLocal.count - 1 && viewModel.selectedIndex > 0 { viewModel.selectedIndex -= 1 }
                            }
                        }
                    } else if let id = node.item?.id {
                        if isCmd {
                            viewModel.selectedItemsForDeletion = [id]
                            viewModel.showingDeleteSelectedAlert = true
                        } else {
                            if viewModel.selectedIndex >= displayNodesLocal.count - 1 && viewModel.selectedIndex > 0 { viewModel.selectedIndex -= 1 }
                            withAnimation { clipboard.deleteItems(where: { $0.id == id }) }
                        }
                    }
                }
                return nil
            case 35: // P
                if event.modifierFlags.contains(.command) {
                    if viewModel.activeTab == "Trash" { return nil }
                    if viewModel.isEditMode {
                        if viewModel.selectedItemsForDeletion.isEmpty { return nil }
                        if viewModel.activeTab != "Pinned" {
                            for id in viewModel.selectedItemsForDeletion {
                                if let idx = clipboard.history.firstIndex(where: { $0.id == id }) {
                                    clipboard.history[idx].isPinned = true
                                    clipboard.setFolderId(for: [id], folderId: nil)
                                }
                            }
                            viewModel.selectedItemsForDeletion.removeAll()
                            viewModel.isEditMode = false
                        }
                    } else if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                        if let id = displayNodesLocal[viewModel.selectedIndex].item?.id { clipboard.togglePin(for: id) }
                    }
                }
                return nil
            case 5: // G
                if event.modifierFlags.contains(.command) {
                    if viewModel.activeTab == "Trash" { return nil }
                    if viewModel.isEditMode {
                        if !viewModel.selectedItemsForDeletion.isEmpty {
                            viewModel.itemToAssignGroup = GroupAssignmentPayload(itemIds: viewModel.selectedItemsForDeletion) {
                                viewModel.selectedItemsForDeletion.removeAll()
                                viewModel.isEditMode = false
                            }
                        }
                    } else if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                        let node = displayNodesLocal[viewModel.selectedIndex]
                        if !node.isFolder, let item = node.item {
                            viewModel.itemToAssignGroup = GroupAssignmentPayload(itemIds: [item.id])
                        }
                    }
                }
                return nil
            case 32: // U
                if event.modifierFlags.contains(.command) {
                    if viewModel.activeTab == "Trash" { return nil }
                    if viewModel.isEditMode {
                        if viewModel.selectedItemsForDeletion.isEmpty { return nil }
                        if viewModel.activeTab == "Pinned" {
                            for id in viewModel.selectedItemsForDeletion {
                                if let idx = clipboard.history.firstIndex(where: { $0.id == id }) {
                                    clipboard.history[idx].isPinned = false
                                }
                            }
                            viewModel.selectedItemsForDeletion.removeAll()
                            viewModel.isEditMode = false
                        } else if viewModel.activeTab == "Groups" {
                            let hasGroupedItem = clipboard.history.contains { item in viewModel.selectedItemsForDeletion.contains(item.id) && item.folderId != nil }
                            if hasGroupedItem {
                                viewModel.showingUngroupAlert = true
                            }
                        }
                    } else if viewModel.activeTab == "Groups" && viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                        let node = displayNodesLocal[viewModel.selectedIndex]
                        if !node.isFolder, let item = node.item, item.folderId != nil {
                            viewModel.selectedItemsForDeletion = [item.id]
                            viewModel.showingUngroupAlert = true
                        }
                    }
                }
                return nil
            case 126: // Up
                if viewModel.editingFolderId != nil { return event }
                if isFreezeFieldFocused {
                    let current = Int(viewModel.reorderFreezeLimit) ?? 0
                    if current < 10 { viewModel.reorderFreezeLimit = "\(current + 1)" }
                    return nil
                }
                if event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) && viewModel.activeTab == "Groups" {
                    viewModel.expandedFolderIds.removeAll()
                    return nil
                }
                if viewModel.isReorderMode && event.modifierFlags.contains(.command) && (viewModel.activeTab == "Pinned" || viewModel.activeTab == "Groups") {
                    var idsToMove: [(index: Int, id: UUID, isFolder: Bool)] = []
                    if viewModel.selectedItemsForDeletion.isEmpty {
                        return nil

                    } else {
                        for (i, node) in displayNodesLocal.enumerated() {
                            if node.isFolder, let fid = node.folder?.id, viewModel.selectedItemsForDeletion.contains(fid) {
                                idsToMove.append((i, fid, true))
                            } else if let iid = node.item?.id, viewModel.selectedItemsForDeletion.contains(iid) {
                                idsToMove.append((i, iid, false))
                            }
                        }
                    }
                    
                    let folderIds = idsToMove.filter { $0.isFolder }.map { $0.id }
                    let itemIds = idsToMove.filter { !$0.isFolder }.map { $0.id }
                    if !folderIds.isEmpty { clipboard.moveFolders(up: true, ids: folderIds) }
                    if !itemIds.isEmpty { clipboard.moveItems(up: true, ids: itemIds) }
                    if viewModel.selectedIndex > 0 { viewModel.selectedIndex -= 1 }
                    return nil
                }
                
                let maxIndex = displayNodesLocal.count - 1
                if viewModel.isEditMode || viewModel.isReorderMode {
                    if event.modifierFlags.contains(.shift) {
                        if viewModel.selectionAnchorIndex == nil { viewModel.selectionAnchorIndex = viewModel.selectedIndex }
                    } else {
                        viewModel.selectionAnchorIndex = nil
                    }
                }
                if viewModel.selectedIndex > 0 {
                    var nextIndex = viewModel.selectedIndex - 1
                    if nextIndex > 0 && displayNodesLocal[nextIndex].isDivider { nextIndex -= 1 }
                    viewModel.selectedIndex = nextIndex
                }
                else { viewModel.selectedIndex = maxIndex }
                return nil
            case 125: // Down
                if viewModel.editingFolderId != nil { return event }
                if isFreezeFieldFocused {
                    let current = Int(viewModel.reorderFreezeLimit) ?? 0
                    if current > 0 { viewModel.reorderFreezeLimit = "\(current - 1)" }
                    return nil
                }
                if event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) && viewModel.activeTab == "Groups" {
                    viewModel.expandedFolderIds = Set(clipboard.folders.map { $0.id })
                    return nil
                }
                if viewModel.isReorderMode && event.modifierFlags.contains(.command) && (viewModel.activeTab == "Pinned" || viewModel.activeTab == "Groups") {
                    var idsToMove: [(index: Int, id: UUID, isFolder: Bool)] = []
                    if viewModel.selectedItemsForDeletion.isEmpty {
                        return nil

                    } else {
                        for (i, node) in displayNodesLocal.enumerated() {
                            if node.isFolder, let fid = node.folder?.id, viewModel.selectedItemsForDeletion.contains(fid) {
                                idsToMove.append((i, fid, true))
                            } else if let iid = node.item?.id, viewModel.selectedItemsForDeletion.contains(iid) {
                                idsToMove.append((i, iid, false))
                            }
                        }
                    }
                    
                    let folderIds = idsToMove.filter { $0.isFolder }.map { $0.id }
                    let itemIds = idsToMove.filter { !$0.isFolder }.map { $0.id }
                    if !folderIds.isEmpty { clipboard.moveFolders(up: false, ids: folderIds) }
                    if !itemIds.isEmpty { clipboard.moveItems(up: false, ids: itemIds) }
                    if viewModel.selectedIndex < displayNodesLocal.count - 1 { viewModel.selectedIndex += 1 }
                    return nil
                }
                
                let maxIndex = displayNodesLocal.count - 1
                if viewModel.isEditMode || viewModel.isReorderMode {
                    if event.modifierFlags.contains(.shift) {
                        if viewModel.selectionAnchorIndex == nil { viewModel.selectionAnchorIndex = viewModel.selectedIndex }
                    } else {
                        viewModel.selectionAnchorIndex = nil
                    }
                }
                if viewModel.selectedIndex < maxIndex {
                    var nextIndex = viewModel.selectedIndex + 1
                    if nextIndex < maxIndex && displayNodesLocal[nextIndex].isDivider { nextIndex += 1 }
                    viewModel.selectedIndex = nextIndex
                }
                else { viewModel.selectedIndex = 0 }
                return nil
            case 36: // Enter
                if viewModel.activeTab == "Trash" {
                    return nil
                }
                if isFreezeFieldFocused {
                    isFreezeFieldFocused = false
                    return nil
                }
                if viewModel.editingFolderId != nil {
                    // Let the textfield handle the Enter key to submit
                    return event
                }
                if viewModel.isReorderMode {
                    clipboard.isReordering = false
                    viewModel.isReorderMode = false
                    
                    let freezeLimit = Int(viewModel.reorderFreezeLimit) ?? 0
                    clipboard.applyReorder(target: viewModel.reorderTarget, freezeLimit: freezeLimit)
                    
                    viewModel.reorderTarget = .none
                    viewModel.selectedItemsForDeletion.removeAll()
                    return nil
                }
                
                if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                    let node = displayNodesLocal[viewModel.selectedIndex]
                    if node.isFolder, let folder = node.folder {
                        withAnimation {
                            if viewModel.expandedFolderIds.contains(folder.id) { viewModel.expandedFolderIds.remove(folder.id) }
                            else { viewModel.expandedFolderIds.insert(folder.id) }
                        }
                    } else {
                        let hasCmd = event.modifierFlags.contains(.command)
                        let hasCtrl = event.modifierFlags.contains(.control)
                        let format: PasteFormatType = (hasCmd && hasCtrl) ? .richNoLinks : (hasCmd ? .rich : .plain)
                        pasteItem(index: viewModel.selectedIndex, format: format)
                    }
                }
                return nil
            case 124: // Right
                if viewModel.editingFolderId != nil { return event }
                if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                    let node = displayNodesLocal[viewModel.selectedIndex]
                    if node.isFolder, let folder = node.folder {
                        withAnimation { _ = viewModel.expandedFolderIds.insert(folder.id) }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { viewModel.expandedItemIndex = viewModel.selectedIndex }
                    }
                }
                return nil
            case 123: // Left
                if viewModel.editingFolderId != nil { return event }
                if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                    let node = displayNodesLocal[viewModel.selectedIndex]
                    if event.modifierFlags.contains(.option) {
                        if let parentId = node.parentFolderId ?? node.folder?.id {
                            withAnimation {
                                viewModel.expandedFolderIds.remove(parentId)
                                if let pIdx = displayNodesLocal.firstIndex(where: { $0.folder?.id == parentId }) { viewModel.selectedIndex = pIdx }
                                viewModel.expandedItemIndex = nil
                            }
                        }
                        return nil
                    }
                    if node.isFolder, let folder = node.folder {
                        withAnimation { _ = viewModel.expandedFolderIds.remove(folder.id) }
                    } else if viewModel.expandedItemIndex == viewModel.selectedIndex {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { viewModel.expandedItemIndex = nil }
                    } else if viewModel.activeTab == "Groups", let parentId = node.parentFolderId {
                        if let pIdx = displayNodesLocal.firstIndex(where: { $0.folder?.id == parentId }) {
                            withAnimation { viewModel.selectedIndex = pIdx; viewModel.expandedItemIndex = nil }
                        }
                    }
                }
                return nil
            case 49: // Space
                if (viewModel.isEditMode || viewModel.isReorderMode) && viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                    if let anchor = viewModel.selectionAnchorIndex {
                        let start = min(anchor, viewModel.selectedIndex)
                        let end = max(anchor, viewModel.selectedIndex)
                        
                        var idsToToggle: [UUID] = []
                        for i in start...end {
                            if i < displayNodesLocal.count {
                                if let id = displayNodesLocal[i].item?.id { idsToToggle.append(id) }
                                else if let id = displayNodesLocal[i].folder?.id, id != cloudFolderId, id != restoredFolderId, clipboard.selectedDevice == "Local (This Mac)" { idsToToggle.append(id) }
                            }
                        }
                        
                        let allSelected = idsToToggle.allSatisfy { viewModel.selectedItemsForDeletion.contains($0) }
                        withAnimation {
                            for id in idsToToggle {
                                if allSelected {
                                    viewModel.selectedItemsForDeletion.remove(id)
                                } else {
                                    viewModel.selectedItemsForDeletion.insert(id)
                                }
                            }
                            viewModel.selectionAnchorIndex = nil
                        }
                    } else {
                        let node = displayNodesLocal[viewModel.selectedIndex]
                        if let id = node.item?.id ?? (node.folder?.id != cloudFolderId && node.folder?.id != restoredFolderId && clipboard.selectedDevice == "Local (This Mac)" ? node.folder?.id : nil) {
                            withAnimation {
                                if viewModel.selectedItemsForDeletion.contains(id) { viewModel.selectedItemsForDeletion.remove(id) }
                                else { viewModel.selectedItemsForDeletion.insert(id) }
                            }
                        }
                    }
                    return nil
                }
                if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) { return event }
                return nil

            case 14: // E
                if event.modifierFlags.contains(.command) {
                    withAnimation {
                        viewModel.isEditMode.toggle()
                        if viewModel.isEditMode {
                            if viewModel.isReorderMode {
                                clipboard.history = viewModel.reorderBackupHistory
                                clipboard.folders = viewModel.reorderBackupFolders
                                clipboard.isReordering = false
                                viewModel.isReorderMode = false
                            }
                        } else {
                            viewModel.selectedItemsForDeletion.removeAll()
                        }
                    }
                    return nil
                }
                if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) { return event }
                return nil
            case 0: // A
                if (viewModel.isEditMode || viewModel.isReorderMode) && event.modifierFlags.contains(.command) {
                    withAnimation {
                        let ids = Set(displayNodesLocal.compactMap { $0.item?.id ?? (clipboard.selectedDevice == "Local (This Mac)" && $0.folder?.id != cloudFolderId ? $0.folder?.id : nil) })
                        if viewModel.selectedItemsForDeletion.isSuperset(of: ids) { viewModel.selectedItemsForDeletion.subtract(ids) }
                        else { viewModel.selectedItemsForDeletion.formUnion(ids) }
                    }
                    return nil
                }
                if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) { return event }
                return nil
            case 53: // Esc
                if viewModel.activeTab == "Trash" {
                    viewModel.activeTab = viewModel.previousTab
                    return nil
                }
                if viewModel.isEditMode {
                    viewModel.isEditMode = false
                    return nil
                }
                if isSearchFocused { isSearchFocused = false }
                else if viewModel.isReorderMode {
                    clipboard.history = viewModel.reorderBackupHistory
                    clipboard.folders = viewModel.reorderBackupFolders
                    clipboard.isReordering = false
                    viewModel.isReorderMode = false
                    viewModel.selectedItemsForDeletion.removeAll()
                }
                else if viewModel.isEditMode {
                    viewModel.isEditMode = false
                    viewModel.selectedItemsForDeletion.removeAll()
                }
                else { 
                    if SettingsWindowManager.shared.isSettingsOpen {
                        SettingsWindowManager.shared.closeSettings()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { shortcut.isExpanded = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            previousApp?.activate(options: [])
                        }
                    }
                }
                return nil
            case 48: // Tab
                if event.modifierFlags.contains(.option) {
                    if viewModel.isReorderMode { return nil }
                    let isShift = event.modifierFlags.contains(.shift)
                    let visibleTabs = self.getVisibleTabs()
                    if let currentIndex = visibleTabs.firstIndex(of: viewModel.activeTab) {
                        let nextIndex = isShift 
                            ? (currentIndex - 1 + visibleTabs.count) % visibleTabs.count 
                            : (currentIndex + 1) % visibleTabs.count
                        withAnimation {
                            viewModel.activeTab = visibleTabs[nextIndex]
                            viewModel.selectedIndex = 0
                            viewModel.expandedItemIndex = nil
                        }
                        DispatchQueue.main.async {
                            isSearchFocused = false
                        }
                    } else {
                        // We are in a tab not in visibleTabs (like Trash). Jump to first or last tab.
                        withAnimation {
                            viewModel.activeTab = isShift ? (visibleTabs.last ?? "All") : (visibleTabs.first ?? "All")
                            viewModel.selectedIndex = 0
                            viewModel.expandedItemIndex = nil
                        }
                        DispatchQueue.main.async {
                            isSearchFocused = false
                        }
                    }
                    return nil
                }
                if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) { return event }
                return nil
            default:
                if event.isAllowedSystemCommand() {
                    return event
                }
                return nil
            }
        }

}
import AppKit

extension NSEvent {
    /// Determines if the event is a standard macOS system command shortcut
    /// (e.g., Cmd+Q, Cmd+W, Cmd+M, Cmd+,) that should be allowed to pass through to the system.
    /// This prevents unhandled command shortcuts from triggering the macOS error beep.
    func isAllowedSystemCommand(additionalAllowedKeys: Set<UInt16> = []) -> Bool {
        guard self.modifierFlags.contains(.command) || self.modifierFlags.contains(.control) else {
            return false
        }
        
        var allowedKeys: Set<UInt16> = [
            12, // Q (Quit)
            13, // W (Close Window)
            46, // M (Minimize)
            43  // , (Settings)
        ]
        
        allowedKeys.formUnion(additionalAllowedKeys)
        
        return allowedKeys.contains(self.keyCode)
    }
}
