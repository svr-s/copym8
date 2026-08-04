import Foundation
import AppKit

extension ClipboardManager {
    func getFilteredFolders(searchText: String) -> [ClipboardFolder] {
        if searchText.isEmpty { return activeFolders }
        return activeFolders.filter { folder in
            if folder.name.localizedCaseInsensitiveContains(searchText) { return true }
            return activeHistory.contains(where: { $0.folderId == folder.id && $0.text.localizedCaseInsensitiveContains(searchText) })
        }
    }

    func setFolderId(for itemIds: [UUID], folderId: UUID?) {
        var cloudMoves: [UUID] = []
        for itemId in itemIds {
            if folderId == cloudFolderId {
                cloudMoves.append(itemId)
            } else {
                if let idx = history.firstIndex(where: { $0.id == itemId }) {
                    let wasInCloud = history[idx].folderId == cloudFolderId
                    history[idx].folderId = folderId
                    if folderId != nil {
                        history[idx].isPinned = false
                    }
                    
                    if wasInCloud {
                        if history[idx].itemType == .image { try? LocalImageStore.shared.migrateImage(id: itemId, toCloud: false) }
                        if history[idx].hasRTF || history[idx].hasHTML { try? LocalPayloadStore.shared.migratePayloads(for: itemId, toCloud: false) }
                        if history[idx].itemType == .file, let urls = history[idx].fileURLs {
                            history[idx].fileURLs = try? LocalFileStore.shared.migrateFiles(for: itemId, fileURLs: urls, toCloud: false)
                        }
                        removeFromCloudCopyFile(itemId: itemId)
                    }
                }
            }
        }
        
        if !cloudMoves.isEmpty {
            let success = moveToCloud(itemIds: cloudMoves)
            if !success { return } // Abort if pre-flight check failed
        }
        saveHistory()
    }

    func saveFolders() {
        if isReordering { return }
        let foldersToSave = folders.filter { $0.id != cloudFolderId }
        if let encoded = try? JSONEncoder().encode(foldersToSave) {
            if let url = foldersFileURL {
                try? encoded.write(to: url, options: .atomic)
            }
            
            // Sync to Cloud Folder
            if let syncPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !syncPath.isEmpty {
                let deviceName = UserDefaults.standard.string(forKey: "syncDeviceName") ?? (Host.current().localizedName ?? "My Mac")
                let safeName = deviceName.replacingOccurrences(of: "/", with: "-")
                let syncURL = URL(fileURLWithPath: syncPath).appendingPathComponent("\(safeName)_folders.json")
                try? encoded.write(to: syncURL, options: .atomic)
            }
        }
    }

}
