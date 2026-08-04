import Foundation
import AppKit

extension ClipboardManager {
    func disableSync() {
        CloudSyncService.shared.disableSync()
    }

    func enableSync() {
        DispatchQueue.main.async {
            if let syncPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !syncPath.isEmpty {
                if !self.folders.contains(where: { $0.id == cloudFolderId }) {
                    let cloudFolder = ClipboardFolder(id: cloudFolderId, name: "Cloud Copy", orderIndex: -1)
                    self.folders.insert(cloudFolder, at: 0)
                    self.saveFolders()
                }
                self.saveHistory()
                CloudSyncService.shared.startPolling()
            }
        }
    }

    func renameDeviceFiles(from oldName: String, to newName: String) {
        CloudSyncService.shared.renameDeviceFiles(from: oldName, to: newName)
    }

    func purgeRemoteDevice(_ deviceName: String) {
        CloudSyncService.shared.purgeRemoteDevice(deviceName)
    }

    func fetchRemoteHistory(for device: String) {
        CloudSyncService.shared.fetchRemoteHistory(for: device)
    }

    func removeFromCloudCopyFile(itemId: UUID) {
        guard let syncPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !syncPath.isEmpty else { return }
        let cloudURL = URL(fileURLWithPath: syncPath).appendingPathComponent("cloud_copy_entries.json")
        if let data = try? Data(contentsOf: cloudURL),
           var cloudItems = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            cloudItems.removeAll { $0.id == itemId }
            if let encoded = try? JSONEncoder().encode(cloudItems) {
                try? encoded.write(to: cloudURL, options: .atomic)
            }
        }
    }

    func moveToCloud(itemIds: [UUID]) -> Bool {
        guard let syncPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !syncPath.isEmpty else { return false }
        
        let cloudURL = URL(fileURLWithPath: syncPath).appendingPathComponent("cloud_copy_entries.json")
        var cloudItems: [ClipboardItem] = []
        if let data = try? Data(contentsOf: cloudURL),
           let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            cloudItems = decoded
        }
        
        let maxSizeInt = UserDefaults.standard.integer(forKey: "cloudCopyMaxTotalStorageMB")
        let maxItemInt = UserDefaults.standard.integer(forKey: "cloudCopyMaxItemSizeMB")
        let maxSizeMB = Double(maxSizeInt == 0 ? 50 : maxSizeInt)
        let maxItemMB = Double(maxItemInt == 0 ? 10 : maxItemInt)
        
        for itemId in itemIds {
            guard let idx = history.firstIndex(where: { $0.id == itemId }) else { continue }
            var item = history[idx]
            
            var itemSizeMB = 0.0
            if item.itemType == .image { itemSizeMB += LocalImageStore.shared.getFileSizeMB(id: item.id) }
            if item.hasRTF { itemSizeMB += LocalPayloadStore.shared.getFileSizeMB(id: item.id, type: .rtf) }
            if item.hasHTML { itemSizeMB += LocalPayloadStore.shared.getFileSizeMB(id: item.id, type: .html) }
            if item.itemType == .file, let urls = item.fileURLs {
                for u in urls {
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: URL(fileURLWithPath: u).path),
                       let size = attrs[.size] as? UInt64 {
                        itemSizeMB += Double(size) / (1024.0 * 1024.0)
                    }
                }
            }
            
            if itemSizeMB > maxItemMB {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowToast"), object: "Error: Item exceeds max allowed size (\(Int(maxItemMB))MB).")
                }
                return false
            }
            
            do {
                let itemsToEvict = try HistoryEvictionService.shared.getCloudItemsToEvict(
                    forNewItemSizeMB: itemSizeMB,
                    cloudItems: cloudItems,
                    maxSizeMB: maxSizeMB
                )
                
                for evict in itemsToEvict {
                    cloudItems.removeAll { $0.id == evict.id }
                    history.removeAll { $0.id == evict.id }
                    LocalPayloadStore.shared.deletePayloads(for: evict.id, inCloud: true)
                    LocalImageStore.shared.deleteImage(id: evict.id, inCloud: true)
                    LocalFileStore.shared.deleteFiles(for: evict.id)
                }
            } catch {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowToast"), object: "Error: Cloud Copy full. Unfreeze items to make space.")
                }
                return false
            }
            
            item.folderId = cloudFolderId
            item.isPinned = false
            
            do {
                if item.itemType == .image { try LocalImageStore.shared.migrateImage(id: item.id, toCloud: true) }
                if item.hasRTF || item.hasHTML { try LocalPayloadStore.shared.migratePayloads(for: item.id, toCloud: true) }
                if item.itemType == .file, let urls = item.fileURLs {
                    item.fileURLs = try LocalFileStore.shared.migrateFiles(for: item.id, fileURLs: urls, toCloud: true)
                }
            } catch {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowToast"), object: "Error: Sync storage is full.")
                }
                return false
            }
            
            cloudItems.append(item)
            history[idx] = item
        }
        
        if let encoded = try? JSONEncoder().encode(cloudItems) {
            try? encoded.write(to: cloudURL, options: .atomic)
        }
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("ShowToast"), object: "Moved to Cloud Copy.")
        }
        return true
    }

}
