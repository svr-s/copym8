import Foundation
import AppKit

extension ClipboardManager {
    /// Deletes a specific clipboard item at the given index.
    /// - Parameters:
    ///   - index: The array index of the item to delete.
    ///   - hardDelete: If `true`, permanently removes the item and its payload from disk. 
    ///                 If `false`, marks it as deleted (moves it to the Trash).
    func deleteItem(at index: Int, hardDelete: Bool = false) {
        let item = history[index]
        removeFromQueue(ids: [item.id]) // Ensure we remove from the queue
        if hardDelete {
            LocalPayloadStore.shared.deletePayloads(for: item.id)
            if item.itemType == .image {
                LocalImageStore.shared.deleteImage(id: item.id)
            }
            history.remove(at: index)
        } else {
            history[index].isDeleted = true
            history[index].deletedAt = Date()
        }
        saveHistory()
    }

    /// Deletes all clipboard items matching a specific predicate condition.
    /// - Parameters:
    ///   - predicate: A closure that returns `true` for items that should be deleted.
    ///   - hardDelete: If `true`, permanently removes the matched items and their payloads from disk. 
    ///                 If `false`, marks them as deleted (moves them to the Trash).
    func deleteItems(where predicate: (ClipboardItem) -> Bool, hardDelete: Bool = false) {
        if hardDelete {
            let itemsToDelete = history.filter(predicate)
            removeFromQueue(ids: itemsToDelete.map { $0.id })
            for item in itemsToDelete {
                LocalPayloadStore.shared.deletePayloads(for: item.id)
                if item.itemType == .image {
                    LocalImageStore.shared.deleteImage(id: item.id)
                }
            }
            history.removeAll(where: predicate)
        } else {
            var idsToRemove: [UUID] = []
            for i in 0..<history.count {
                if predicate(history[i]) {
                    idsToRemove.append(history[i].id)
                    history[i].isDeleted = true
                    history[i].deletedAt = Date()
                }
            }
            removeFromQueue(ids: idsToRemove)
        }
    }

    /// Moves all unpinned, unfiled clipboard items to the Trash.
    func clearAll() {
        deleteItems(where: { _ in true })
    }

    /// Restores previously deleted items from the Trash back into the active history.
    /// Restored items are placed in a special "Restored" folder.
    /// - Parameter ids: An array of UUIDs of the items to restore.
    func restoreItems(ids: [UUID]) {
        for id in ids {
            if let index = history.firstIndex(where: { $0.id == id }) {
                let item = history[index]
                // Deduplication logic for restored items
                if let activeIndex = history.firstIndex(where: { $0.text == item.text && !($0.isDeleted ?? false) && $0.id != item.id }) {
                    history[activeIndex].timestamp = Date()
                    deleteItem(at: index, hardDelete: true)
                } else {
                    history[index].isDeleted = false
                    history[index].deletedAt = nil
                    history[index].timestamp = Date()
                    
                    if history[index].isPinned {
                        history[index].folderId = nil
                    } else {
                        history[index].folderId = restoredFolderId
                    }
                }
            }
        }
        saveHistory()
    }

    /// Toggles the pinned status of a clipboard item.
    /// Pinning an item prevents it from being evicted during automatic cleanup.
    /// - Parameter id: The UUID of the item to pin or unpin.
    func togglePin(for id: UUID) {
        if let index = history.firstIndex(where: { $0.id == id }) {
            history[index].isPinned.toggle()
            if history[index].isPinned {
                setFolderId(for: [history[index].id], folderId: nil) // Pin directly to unassigned
            } else {
                setFolderId(for: [history[index].id], folderId: nil) // Clear folder if unpinned
            }
            saveHistory()
        }
    }

    /// Checks the current storage limits (both retention time and max storage size)
    /// and triggers eviction via `HistoryEvictionService` if necessary.
    func pruneStorageIfNeeded() {
        let retentionDays = UserDefaults.standard.integer(forKey: "deleteAfterDays")
        let expiredIDs = HistoryEvictionService.shared.getExpiredTrashIDs(from: history, retentionDays: retentionDays)
        if !expiredIDs.isEmpty {
            deleteItems(where: { expiredIDs.contains($0.id) }, hardDelete: true)
        }
        
        let pruneIDs = HistoryEvictionService.shared.getIDsToPrune(from: history, maxTotalStorageMB: maxTotalStorageMB)
        if !pruneIDs.isEmpty {
            deleteItems(where: { pruneIDs.contains($0.id) }, hardDelete: true)
        }
    }

    /// Ensures the clipboard history does not exceed the maximum allowed number of unpinned items.
    /// Permanently deletes older unpinned items from disk to enforce the limit.
    /// - Parameter limit: The maximum number of unpinned, unfiled items to retain.
    func truncateHistory(to limit: Int) {
        let unpinnedCount = history.filter { !$0.isPinned && $0.folderId == nil }.count
        if unpinnedCount > limit {
            let elementsToRemove = unpinnedCount - limit
            var removed = 0
            for i in stride(from: history.count - 1, through: 0, by: -1) {
                let item = history[i]
                if !item.isPinned && item.folderId == nil {
                    if item.itemType == .image {
                        LocalImageStore.shared.deleteImage(id: item.id)
                    }
                    LocalPayloadStore.shared.deletePayloads(for: item.id)
                    history.remove(at: i)
                    removed += 1
                    if removed >= elementsToRemove { break }
                }
            }
        }
    }

    /// Verifies whether the payload for a clipboard item is available on disk.
    /// If the item is in the cloud, it checks if the ubiquitous file has been downloaded.
    /// - Parameter item: The clipboard item to check.
    /// - Returns: `true` if the payload is available, `false` otherwise.
    func isItemAvailable(_ item: ClipboardItem) -> Bool {
        if item.folderId != cloudFolderId { return true }
        
        let fileManager = FileManager.default
        if item.itemType == .image {
            guard let dir = LocalImageStore.shared.getDirectory(inCloud: true) else { return false }
            return fileManager.fileExists(atPath: dir.appendingPathComponent("\(item.id.uuidString).png").path)
        }
        if item.hasRTF {
            guard let dir = LocalPayloadStore.shared.getDirectory(inCloud: true) else { return false }
            return fileManager.fileExists(atPath: dir.appendingPathComponent("\(item.id.uuidString).rtf").path)
        }
        if item.hasHTML {
            guard let dir = LocalPayloadStore.shared.getDirectory(inCloud: true) else { return false }
            return fileManager.fileExists(atPath: dir.appendingPathComponent("\(item.id.uuidString).html").path)
        }
        if item.itemType == .file { return true }
        return true
    }

    /// Prepares the system pasteboard for a paste operation based on the requested format.
    /// Extracts the appropriate payload (e.g., RTF, HTML, plain text) and writes it to the pasteboard.
    /// Temporarily suspends polling to prevent the app from registering its own paste action as a new copy.
    /// - Parameters:
    ///   - item: The clipboard item to paste.
    ///   - formatType: The requested format (e.g., plain text, rich text, rich text without links).
    func prepareForPaste(_ item: ClipboardItem, formatType: PasteFormatType = .plain) {
        ignoreNextChange = true

        let inCloud = item.folderId == cloudFolderId
        var isDownloading = false
        
        let checkDownload = {
            if isDownloading { return }
            NSSound.beep()
            self.pasteboard.setString("[Downloading from Cloud... Please try pasting again in a moment]", forType: .string)
            isDownloading = true
        }
    
        pasteboard.clearContents()
        
        let hasFiles = item.fileURLs != nil && !item.fileURLs!.isEmpty
        
        switch formatType {
        case .plain:
            if !isDownloading {
                if hasFiles {
                    let nsUrls = item.fileURLs!.map { NSURL(fileURLWithPath: $0) }
                    pasteboard.writeObjects(nsUrls)
                } else {
                    self.pasteboard.setString(item.text, forType: .string)
                }
            }
            
        case .rich:
            if item.hasRTF {
                if let data = LocalPayloadStore.shared.loadPayload(id: item.id, type: .rtf, inCloud: inCloud) { pasteboard.setData(data, forType: .rtf) } else if inCloud { checkDownload() }
            }
            if item.hasHTML {
                if let data = LocalPayloadStore.shared.loadPayload(id: item.id, type: .html, inCloud: inCloud) { pasteboard.setData(data, forType: .html) } else if inCloud { checkDownload() }
            }
            if item.hasRTFD {
                if let data = LocalPayloadStore.shared.loadPayload(id: item.id, type: .rtfd, inCloud: inCloud) { pasteboard.setData(data, forType: .rtfd) } else if inCloud { checkDownload() }
            }
            if item.hasWebArchive {
                if let data = LocalPayloadStore.shared.loadPayload(id: item.id, type: .webArchive, inCloud: inCloud) { pasteboard.setData(data, forType: NSPasteboard.PasteboardType("Apple Web Archive pasteboard type")) } else if inCloud { checkDownload() }
            }
            if item.hasPDF {
                if let data = LocalPayloadStore.shared.loadPayload(id: item.id, type: .pdf, inCloud: inCloud) { pasteboard.setData(data, forType: .pdf) } else if inCloud { checkDownload() }
            }
            if !isDownloading {
                if hasFiles {
                    let nsUrls = item.fileURLs!.map { NSURL(fileURLWithPath: $0) }
                    pasteboard.writeObjects(nsUrls)
                } else {
                    self.pasteboard.setString(item.text, forType: .string)
                }
            }
            
        case .richNoLinks:
            let stripRtfLinks = {
                if item.hasRTF,
                   let rtfData = LocalPayloadStore.shared.loadPayload(id: item.id, type: .rtf),
                   let attrString = try? NSMutableAttributedString(data: rtfData, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
                    
                    attrString.enumerateAttribute(.link, in: NSRange(location: 0, length: attrString.length), options: []) { value, range, _ in
                        if value != nil {
                            attrString.removeAttribute(.link, range: range)
                            attrString.removeAttribute(.foregroundColor, range: range)
                            attrString.removeAttribute(.underlineStyle, range: range)
                        }
                    }
                    
                    if let cleanedRtfData = try? attrString.data(from: NSRange(location: 0, length: attrString.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
                        self.pasteboard.setData(cleanedRtfData, forType: .rtf)
                    }
                }
            }
            
            if item.hasHTML,
               let htmlData = LocalPayloadStore.shared.loadPayload(id: item.id, type: .html) {
                if let htmlString = String(data: htmlData, encoding: .utf8),
                   let htmlDoc = try? XMLDocument(xmlString: htmlString, options: .documentTidyHTML) {
                    
                    if let links = try? htmlDoc.nodes(forXPath: "//a") {
                        for link in links {
                            let textNode = XMLNode(kind: .text)
                            textNode.stringValue = link.stringValue
                            if let parent = link.parent as? XMLElement {
                                let index = link.index
                                parent.replaceChild(at: index, with: textNode)
                            }
                        }
                    }
                    
                    let xmlStr = htmlDoc.xmlString
                    let cleanHtmlStr = xmlStr.replacingOccurrences(of: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n", with: "")
                    if let cleanedHtmlData = cleanHtmlStr.data(using: .utf8), !cleanedHtmlData.isEmpty {
                        pasteboard.setData(cleanedHtmlData, forType: .html)
                    } else {
                        pasteboard.setData(htmlData, forType: .html)
                        stripRtfLinks()
                    }
                } else {
                    pasteboard.setData(htmlData, forType: .html)
                    stripRtfLinks()
                }
            } else {
                stripRtfLinks()
            }
            
            if !isDownloading {
                if hasFiles {
                    var resolvedURLs = item.fileURLs!
                    if item.folderId == cloudFolderId, let syncPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !syncPath.isEmpty {
                        let cloudDir = URL(fileURLWithPath: syncPath).appendingPathComponent("Files")
                        resolvedURLs = item.fileURLs!.map { url in
                            let filename = URL(fileURLWithPath: url).lastPathComponent
                            return cloudDir.appendingPathComponent(filename).path
                        }
                    }
                    let nsUrls = resolvedURLs.map { NSURL(fileURLWithPath: $0) }
                    pasteboard.writeObjects(nsUrls)
                } else {
                    self.pasteboard.setString(item.text, forType: .string)
                }
            }
        }
        
        // Ensure our internal state ignores this exact change we just made
        lastChangeCount = pasteboard.changeCount
    }

    /// Synthesizes a native `Cmd+V` keystroke using `CGEvent` to perform an automated paste operation.
    func triggerPasteKeystroke() {
        let src = CGEventSource(stateID: .combinedSessionState)
        
        // Key code 0x09 is 'v'
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        vDown?.flags = .maskCommand
        vDown?.post(tap: .cgAnnotatedSessionEventTap)
        
        let vUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand
        vUp?.post(tap: .cgAnnotatedSessionEventTap)
    }

    /// Imports clipboard items from a remote device into the local device's clipboard history.
    /// Handles duplicate checking and progressive upgrades (pinning and folder assignment).
    /// - Parameter items: The array of `ClipboardItem`s to import.
    func importItems(_ items: [ClipboardItem]) {
        let remoteDevice = self.selectedDevice != "Local (This Mac)" ? self.selectedDevice : "Remote"
        var skippedCount = 0
        var importedCount = 0
        
        for item in items {
            // Find existing local item by content match
            if let existingIndex = self.history.firstIndex(where: { $0.text == item.text && $0.itemType == item.itemType }) {
                if self.history[existingIndex].folderId == cloudFolderId {
                    skippedCount += 1
                    continue
                }
                
                var existingItem = self.history.remove(at: existingIndex)
                existingItem.timestamp = Date()
                
                // Progressive upgrade logic
                if !existingItem.isPinned && existingItem.folderId == nil {
                    existingItem.isPinned = item.isPinned
                    
                    if let remoteFolderId = item.folderId {
                        if let remoteFolder = self.remoteFolders.first(where: { $0.id == remoteFolderId }) {
                            let localFolderName = "\(remoteDevice) - \(remoteFolder.name)"
                            
                            if let existingLocalFolder = self.folders.first(where: { $0.name == localFolderName }) {
                                existingItem.folderId = existingLocalFolder.id
                            } else {
                                var newFolder = ClipboardFolder(name: localFolderName)
                                newFolder.orderIndex = self.folders.count + 1
                                self.folders.append(newFolder)
                                existingItem.folderId = newFolder.id
                            }
                        }
                    }
                }
                
                self.history.insert(existingItem, at: 0)
            } else {
                var newItem = item
                newItem.id = UUID()
                newItem.orderIndex = 0
                newItem.timestamp = Date()
                
                if let remoteFolderId = newItem.folderId {
                    if let remoteFolder = self.remoteFolders.first(where: { $0.id == remoteFolderId }) {
                        let localFolderName = "\(remoteDevice) - \(remoteFolder.name)"
                        
                        if let existingLocalFolder = self.folders.first(where: { $0.name == localFolderName }) {
                            newItem.folderId = existingLocalFolder.id
                        } else {
                            var newFolder = ClipboardFolder(name: localFolderName)
                            newFolder.orderIndex = self.folders.count + 1
                            self.folders.append(newFolder)
                            newItem.folderId = newFolder.id
                        }
                    } else {
                        newItem.folderId = nil // Fallback
                    }
                }
                
                self.history.insert(newItem, at: 0)
            }
            importedCount += 1
        }
        
        var msg = "Import successful"
        if skippedCount > 0 {
            msg = "Imported \(importedCount), skipped \(skippedCount) (already in Cloud Copy)"
        }
        
        NotificationCenter.default.post(name: Notification.Name("ImportSuccessful"), object: msg)
        
        if self.history.count > maxHistoryCount {
            let removedItems = Array(self.history[maxHistoryCount...])
            self.history = Array(self.history.prefix(maxHistoryCount))
            for item in removedItems {
                if item.itemType == .image {
                    LocalImageStore.shared.deleteImage(id: item.id)
                }
            }
        }
    }
}
