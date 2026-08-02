import Foundation
import AppKit

enum ItemType: String, Codable {
    case text
    case link
    case image
    case file
}

enum PasteFormatType {
    case plain
    case rich
    case richNoLinks
}

struct ClipboardFolder: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
    var orderIndex: Int = 0
}

struct ClipboardItem: Identifiable, Equatable, Codable {
    var id = UUID()
    let text: String
    var timestamp: Date
    var sourceApp: String?
    var hasRTF: Bool = false
    var hasHTML: Bool = false
    var hasRTFD: Bool = false
    var hasWebArchive: Bool = false
    var hasPDF: Bool = false
    var isPinned: Bool = false
    var itemType: ItemType = .text
    var fileURLs: [String]?
    var folderId: UUID? = nil
    var orderIndex: Int = 0
    var isDeleted: Bool? = false
    var deletedAt: Date? = nil
}

let restoredFolderId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!


class LocalImageStore {
    static let shared = LocalImageStore()
    
    private let fileManager = FileManager.default
    private var imagesDirectory: URL? {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = appSupport.appendingPathComponent("CopyM8/Images")
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private var cloudDirectory: URL? {
        guard let syncPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !syncPath.isEmpty else { return nil }
        let dir = URL(fileURLWithPath: syncPath).appendingPathComponent("Images")
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    func getDirectory(inCloud: Bool) -> URL? {
        return inCloud ? cloudDirectory : imagesDirectory
    }
    
    func saveImage(_ data: Data, id: UUID, inCloud: Bool = false) -> Bool {
        guard let dir = getDirectory(inCloud: inCloud) else { return false }
        let fileURL = dir.appendingPathComponent("\(id.uuidString).png")
        do {
            try data.write(to: fileURL)
            return true
        } catch {
            print("Failed to save image: \(error)")
            return false
        }
    }
    
    func loadImage(id: UUID, inCloud: Bool = false) -> NSImage? {
        guard let dir = getDirectory(inCloud: inCloud) else { return nil }
        let fileURL = dir.appendingPathComponent("\(id.uuidString).png")
        if !fileManager.fileExists(atPath: fileURL.path) && inCloud {
            let placeholder = fileURL.deletingPathExtension().appendingPathExtension("png.icloud")
            if fileManager.fileExists(atPath: placeholder.path) {
                try? fileManager.startDownloadingUbiquitousItem(at: fileURL)
            }
            return nil
        }
        return NSImage(contentsOf: fileURL)
    }
    
    func deleteImage(id: UUID, inCloud: Bool = false) {
        guard let dir = getDirectory(inCloud: inCloud) else { return }
        let fileURL = dir.appendingPathComponent("\(id.uuidString).png")
        try? fileManager.removeItem(at: fileURL)
    }
    
    func getFileSizeMB(id: UUID, inCloud: Bool = false) -> Double {
        guard let dir = getDirectory(inCloud: inCloud) else { return 0 }
        let fileURL = dir.appendingPathComponent("\(id.uuidString).png")
        if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path), let size = attrs[.size] as? UInt64 {
            return Double(size) / (1024.0 * 1024.0)
        }
        return 0
    }
    
    
    func migrateImage(id: UUID, toCloud: Bool) throws {
        guard let sourceDir = getDirectory(inCloud: !toCloud), let destDir = getDirectory(inCloud: toCloud) else { return }
        let sourceURL = sourceDir.appendingPathComponent("\(id.uuidString).png")
        let destURL = destDir.appendingPathComponent("\(id.uuidString).png")
        if fileManager.fileExists(atPath: sourceURL.path) {
            try fileManager.copyItem(at: sourceURL, to: destURL)
        }
    }

    func getTotalSizeMB() -> Double {
        guard let dir = imagesDirectory,
              let files = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        
        var totalBytes: Int64 = 0
        for file in files {
            if let attrs = try? file.resourceValues(forKeys: [.fileSizeKey]), let size = attrs.fileSize {
                totalBytes += Int64(size)
            }
        }
        return Double(totalBytes) / (1024.0 * 1024.0)
    }
}

enum PayloadType: String {
    case rtf
    case html
    case rtfd
    case webArchive
    case pdf
}

class LocalPayloadStore {
    static let shared = LocalPayloadStore()
    
    private let fileManager = FileManager.default
    private var payloadsDirectory: URL? {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = appSupport.appendingPathComponent("CopyM8/Payloads")
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private var cloudDirectory: URL? {
        guard let syncPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !syncPath.isEmpty else { return nil }
        let dir = URL(fileURLWithPath: syncPath).appendingPathComponent("Payloads")
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    func getDirectory(inCloud: Bool) -> URL? {
        return inCloud ? cloudDirectory : payloadsDirectory
    }
    
    func savePayload(_ data: Data, id: UUID, type: PayloadType, inCloud: Bool = false) -> Bool {
        guard let dir = getDirectory(inCloud: inCloud) else { return false }
        let fileURL = dir.appendingPathComponent("\(id.uuidString).\(type.rawValue)")
        do {
            try data.write(to: fileURL)
            return true
        } catch {
            print("Failed to save payload: \(error)")
            return false
        }
    }
    
    func loadPayload(id: UUID, type: PayloadType, inCloud: Bool = false) -> Data? {
        guard let dir = getDirectory(inCloud: inCloud) else { return nil }
        let fileURL = dir.appendingPathComponent("\(id.uuidString).\(type.rawValue)")
        if !fileManager.fileExists(atPath: fileURL.path) && inCloud {
            let placeholder = fileURL.deletingPathExtension().appendingPathExtension("\(type.rawValue).icloud")
            if fileManager.fileExists(atPath: placeholder.path) {
                try? fileManager.startDownloadingUbiquitousItem(at: fileURL)
            }
            return nil
        }
        return try? Data(contentsOf: fileURL)
    }
    
    func deletePayloads(for id: UUID, inCloud: Bool = false) {
        guard let dir = getDirectory(inCloud: inCloud) else { return }
        let types: [PayloadType] = [.rtf, .html, .rtfd, .webArchive, .pdf]
        for type in types {
            let fileURL = dir.appendingPathComponent("\(id.uuidString).\(type.rawValue)")
            try? fileManager.removeItem(at: fileURL)
        }
    }
    
    func getFileSizeMB(id: UUID, type: PayloadType, inCloud: Bool = false) -> Double {
        guard let dir = getDirectory(inCloud: inCloud) else { return 0 }
        let fileURL = dir.appendingPathComponent("\(id.uuidString).\(type.rawValue)")
        if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path), let size = attrs[.size] as? UInt64 {
            return Double(size) / (1024.0 * 1024.0)
        }
        return 0
    }
    
    
    func migratePayloads(for id: UUID, toCloud: Bool) throws {
        guard let sourceDir = getDirectory(inCloud: !toCloud), let destDir = getDirectory(inCloud: toCloud) else { return }
        let types: [PayloadType] = [.rtf, .html, .rtfd, .webArchive, .pdf]
        for type in types {
            let sourceURL = sourceDir.appendingPathComponent("\(id.uuidString).\(type.rawValue)")
            let destURL = destDir.appendingPathComponent("\(id.uuidString).\(type.rawValue)")
            if fileManager.fileExists(atPath: sourceURL.path) {
                try fileManager.copyItem(at: sourceURL, to: destURL)
            }
        }
    }

    func getTotalSizeMB() -> Double {
        guard let dir = payloadsDirectory,
              let files = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        
        var totalBytes: Int64 = 0
        for file in files {
            if let attrs = try? file.resourceValues(forKeys: [.fileSizeKey]), let size = attrs.fileSize {
                totalBytes += Int64(size)
            }
        }
        return Double(totalBytes) / (1024.0 * 1024.0)
    }
}

class LocalFileStore {
    static let shared = LocalFileStore()
    private let fileManager = FileManager.default
    
    private var cloudDirectory: URL? {
        guard let syncPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !syncPath.isEmpty else { return nil }
        let dir = URL(fileURLWithPath: syncPath).appendingPathComponent("Files")
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    func migrateFiles(for id: UUID, fileURLs: [String], toCloud: Bool) throws -> [String] {
        guard let destDir = cloudDirectory else { return fileURLs }
        
        if toCloud {
            var newURLs: [String] = []
            for path in fileURLs {
                let sourceURL = URL(fileURLWithPath: path)
                let destURL = destDir.appendingPathComponent("\(id.uuidString)_\(sourceURL.lastPathComponent)")
                if fileManager.fileExists(atPath: sourceURL.path) {
                    try fileManager.copyItem(at: sourceURL, to: destURL)
                    newURLs.append(destURL.path)
                }
            }
            return newURLs
        } else {
            // Migrating out of cloud - just delete the cloud copies
            for path in fileURLs {
                let sourceURL = URL(fileURLWithPath: path)
                if sourceURL.path.hasPrefix(destDir.path) {
                    try? fileManager.removeItem(at: sourceURL)
                }
            }
            return fileURLs // When moving out of cloud, we lose the files since they were in iCloud. Or we keep the iCloud path? Actually, for files, we should just delete the iCloud copy. The original files on local disk might still be there, but they aren't tracked.
        }
    }
    
    func deleteFiles(for id: UUID) {
        guard let dir = cloudDirectory,
              let files = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        
        for file in files {
            if file.lastPathComponent.hasPrefix("\(id.uuidString)_") {
                try? fileManager.removeItem(at: file)
            }
        }
    }
    
    func getFileSizeMB(for id: UUID) -> Double {
        guard let dir = cloudDirectory,
              let files = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        
        var totalBytes: Int64 = 0
        for file in files {
            if file.lastPathComponent.hasPrefix("\(id.uuidString)_") {
                if let attrs = try? file.resourceValues(forKeys: [.fileSizeKey]), let size = attrs.fileSize {
                    totalBytes += Int64(size)
                }
            }
        }
        return Double(totalBytes) / (1024.0 * 1024.0)
    }
}

let cloudFolderId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

class ClipboardManager: ObservableObject {
    @Published var history: [ClipboardItem] = [] {
        didSet {
            saveHistory()
        }
    }
    
    @Published var folders: [ClipboardFolder] = [] {
        didSet {
            saveFolders()
        }
    }
    
    @Published var remoteHistory: [ClipboardItem] = []
    @Published var remoteFolders: [ClipboardFolder] = []
    
    var activeHistory: [ClipboardItem] {
        return selectedDevice == "Local (This Mac)" ? history : remoteHistory
    }
    
    var activeFolders: [ClipboardFolder] {
        var baseFolders = selectedDevice == "Local (This Mac)" ? folders : remoteFolders
        if !baseFolders.contains(where: { $0.id == restoredFolderId }) {
            let restored = ClipboardFolder(id: restoredFolderId, name: "Restored", orderIndex: Int.max)
            baseFolders.append(restored)
        }
        return baseFolders
    }
    
    @Published var availableDevices: [String] = []
    @Published var selectedDevice: String = "Local (This Mac)" {
        didSet {
            if selectedDevice != "Local (This Mac)" {
                fetchRemoteHistory(for: selectedDevice)
            }
        }
    }
    
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    private var syncTimer: Timer?
    private let storageKey = "copym8_clipboard_history"
    private let foldersKey = "copym8_clipboard_folders"
    private let queue = DispatchQueue(label: "com.copym8.clipboard", qos: .userInteractive)
    
    var isReordering: Bool = false
    
    init() {
        loadHistory()
        lastChangeCount = pasteboard.changeCount
        startPolling()
        startSyncPolling()
    }
    
    private var historyFileURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = appSupport.appendingPathComponent("CopyM8/Data")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("history.json")
    }
    
    private var foldersFileURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = appSupport.appendingPathComponent("CopyM8/Data")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("folders.json")
    }
    
    private func processLoadedHistory(_ decoded: [ClipboardItem]) -> [ClipboardItem] {
        var updated = decoded
        for i in 0..<updated.count {
            if updated[i].itemType == .text {
                let str = updated[i].text.lowercased()
                if str.hasPrefix("http://") || str.hasPrefix("https://") {
                    updated[i].itemType = .link
                }
            }
            if updated[i].folderId != nil && updated[i].isPinned {
                updated[i].isPinned = false
            }
        }
        return updated
    }
    


    private func loadHistory() {
        var didMigrateHistory = false
        if let url = historyFileURL, let data = try? Data(contentsOf: url) {
            if let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
                self.history = processLoadedHistory(decoded)
            }
        } else if let data = UserDefaults.standard.data(forKey: storageKey) {
            if let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
                self.history = processLoadedHistory(decoded)
                didMigrateHistory = true
            }
        }
        
        var didMigrateFolders = false
        if let url = foldersFileURL, let folderData = try? Data(contentsOf: url) {
            if let decodedFolders = try? JSONDecoder().decode([ClipboardFolder].self, from: folderData) {
                self.folders = decodedFolders
            }
        } else if let folderData = UserDefaults.standard.data(forKey: foldersKey) {
            if let decodedFolders = try? JSONDecoder().decode([ClipboardFolder].self, from: folderData) {
                self.folders = decodedFolders
                didMigrateFolders = true
            }
        }
        
        if didMigrateHistory {
            saveHistory()
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
        if didMigrateFolders {
            saveFolders()
            UserDefaults.standard.removeObject(forKey: foldersKey)
        }
        
        self.folders.removeAll { $0.id == cloudFolderId }
        if let syncPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !syncPath.isEmpty {
            let cloudFolder = ClipboardFolder(id: cloudFolderId, name: "Cloud Copy", orderIndex: -1)
            self.folders.insert(cloudFolder, at: 0)
        }
    }
    
    func saveHistory() {
        if isReordering { return }
        if let encoded = try? JSONEncoder().encode(history) {
            if let url = historyFileURL {
                try? encoded.write(to: url, options: .atomic)
            }
            
            // Sync to Cloud Folder
            if let syncPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !syncPath.isEmpty {
                let deviceName = UserDefaults.standard.string(forKey: "syncDeviceName") ?? (Host.current().localizedName ?? "My Mac")
                let safeName = deviceName.replacingOccurrences(of: "/", with: "-")
                let syncURL = URL(fileURLWithPath: syncPath).appendingPathComponent("\(safeName)_entries.json")
                let syncHistory = history.filter { $0.folderId != cloudFolderId }
                if let syncEncoded = try? JSONEncoder().encode(syncHistory) {
                    try? syncEncoded.write(to: syncURL, options: .atomic)
                }
            }
        }
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
    
    func getFilteredFolders(searchText: String) -> [ClipboardFolder] {
        if searchText.isEmpty { return activeFolders }
        return activeFolders.filter { folder in
            if folder.name.localizedCaseInsensitiveContains(searchText) { return true }
            return activeHistory.contains(where: { $0.folderId == folder.id && $0.text.localizedCaseInsensitiveContains(searchText) })
        }
    }
    
    
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

    func deleteItem(at index: Int, hardDelete: Bool = false) {
        let item = history[index]
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
            
            var currentTotalSize = 0.0
            for cItem in cloudItems {
                if cItem.itemType == .image { currentTotalSize += LocalImageStore.shared.getFileSizeMB(id: cItem.id, inCloud: true) }
                if cItem.hasRTF { currentTotalSize += LocalPayloadStore.shared.getFileSizeMB(id: cItem.id, type: .rtf, inCloud: true) }
                if cItem.hasHTML { currentTotalSize += LocalPayloadStore.shared.getFileSizeMB(id: cItem.id, type: .html, inCloud: true) }
                if cItem.itemType == .file { currentTotalSize += LocalFileStore.shared.getFileSizeMB(for: cItem.id) }
            }
            
            let spaceNeeded = (currentTotalSize + itemSizeMB) - maxSizeMB
            if spaceNeeded > 0 {
                var evictableItems = cloudItems.filter { $0.orderIndex == 0 && !$0.isPinned }
                evictableItems.sort { $0.timestamp < $1.timestamp }
                
                var spaceAvailable = 0.0
                var itemsToEvict: [ClipboardItem] = []
                for evictable in evictableItems {
                    if spaceAvailable >= spaceNeeded { break }
                    itemsToEvict.append(evictable)
                    if evictable.itemType == .image { spaceAvailable += LocalImageStore.shared.getFileSizeMB(id: evictable.id, inCloud: true) }
                    if evictable.hasRTF { spaceAvailable += LocalPayloadStore.shared.getFileSizeMB(id: evictable.id, type: .rtf, inCloud: true) }
                    if evictable.hasHTML { spaceAvailable += LocalPayloadStore.shared.getFileSizeMB(id: evictable.id, type: .html, inCloud: true) }
                    if evictable.itemType == .file { spaceAvailable += LocalFileStore.shared.getFileSizeMB(for: evictable.id) }
                }
                
                if spaceAvailable < spaceNeeded {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name("ShowToast"), object: "Error: Cloud Copy full. Unfreeze items to make space.")
                    }
                    return false
                }
                
                for evict in itemsToEvict {
                    cloudItems.removeAll { $0.id == evict.id }
                    history.removeAll { $0.id == evict.id }
                    LocalPayloadStore.shared.deletePayloads(for: evict.id, inCloud: true)
                    LocalImageStore.shared.deleteImage(id: evict.id, inCloud: true)
                    LocalFileStore.shared.deleteFiles(for: evict.id)
                }
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

    func deleteItems(where predicate: (ClipboardItem) -> Bool, hardDelete: Bool = false) {
        if hardDelete {
            let itemsToDelete = history.filter(predicate)
            for item in itemsToDelete {
                LocalPayloadStore.shared.deletePayloads(for: item.id)
                if item.itemType == .image {
                    LocalImageStore.shared.deleteImage(id: item.id)
                }
            }
            history.removeAll(where: predicate)
        } else {
            for i in 0..<history.count {
                if predicate(history[i]) {
                    history[i].isDeleted = true
                    history[i].deletedAt = Date()
                }
            }
        }
    }

    func clearAll() {
        deleteItems(where: { _ in true })
    }
    
    func restoreItems(ids: [UUID]) {
        for id in ids {
            if let index = history.firstIndex(where: { $0.id == id }) {
                let item = history[index]
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
    
    func getItemSizeMB(item: ClipboardItem) -> Double {
        var size = 0.0
        if item.itemType == .image { size += LocalImageStore.shared.getFileSizeMB(id: item.id) }
        if item.hasRTF { size += LocalPayloadStore.shared.getFileSizeMB(id: item.id, type: .rtf) }
        if item.hasHTML { size += LocalPayloadStore.shared.getFileSizeMB(id: item.id, type: .html) }
        if item.itemType == .file { size += LocalFileStore.shared.getFileSizeMB(for: item.id) }
        return size
    }
    
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
    
    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }
    
    private func startSyncPolling() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.pollSyncFolder()
        }
    }
    
    private func pollSyncFolder() {
        guard let syncPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !syncPath.isEmpty else {
            DispatchQueue.main.async {
                if !self.availableDevices.isEmpty { self.availableDevices = [] }
                if self.selectedDevice != "Local (This Mac)" { self.selectedDevice = "Local (This Mac)" }
            }
            return
        }
        
        let localDeviceName = UserDefaults.standard.string(forKey: "syncDeviceName") ?? (Host.current().localizedName ?? "My Mac")
        let url = URL(fileURLWithPath: syncPath)
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { return }
        
        let devices = files
            .filter { $0.lastPathComponent.hasSuffix("_entries.json") && !$0.lastPathComponent.hasPrefix("cloud_copy") }
            .map { $0.lastPathComponent.replacingOccurrences(of: "_entries.json", with: "") }
            .filter { $0 != localDeviceName }
            .sorted()
            
        let cloudURL = url.appendingPathComponent("cloud_copy_entries.json")
        var cloudItems: [ClipboardItem]? = nil
        
        if !FileManager.default.fileExists(atPath: cloudURL.path) {
            try? FileManager.default.startDownloadingUbiquitousItem(at: cloudURL)
        }
        
        if let data = try? Data(contentsOf: cloudURL) {
            cloudItems = try? JSONDecoder().decode([ClipboardItem].self, from: data)
        }
            
        DispatchQueue.main.async {
            if self.availableDevices != devices {
                self.availableDevices = devices
            }
            // Auto-refresh remote history if currently viewing one
            if self.selectedDevice != "Local (This Mac)" {
                self.fetchRemoteHistory(for: self.selectedDevice)
            }
            
            // Sync Cloud Copy items to local history
            if let items = cloudItems {
                let currentCloudItems = self.history.filter { $0.folderId == cloudFolderId }
                
                if currentCloudItems != items {
                    self.history.removeAll { $0.folderId == cloudFolderId }
                    self.history.append(contentsOf: items)
                    self.history.sort { $0.timestamp > $1.timestamp }
                }
            }
        }
    }
    
    func fetchRemoteHistory(for deviceName: String) {
        guard let syncPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !syncPath.isEmpty else { return }
        let url = URL(fileURLWithPath: syncPath).appendingPathComponent("\(deviceName)_entries.json")
        
        guard let data = try? Data(contentsOf: url) else { return }
        
        if let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            // Filter out files/images since they rely on local UUIDs or paths
            var filtered = decoded.filter { $0.itemType != .file && $0.itemType != .image }
            
            // Remove remote Cloud Copy items to avoid duplicates; we will use the universal local synced ones
            filtered.removeAll { $0.folderId == cloudFolderId }
            
            // We append a tag so users know it's remote
            for i in 0..<filtered.count {
                if let app = filtered[i].sourceApp {
                    filtered[i].sourceApp = "\(app) (via \(deviceName))"
                } else {
                    filtered[i].sourceApp = "via \(deviceName)"
                }
            }
            
            let foldersUrl = URL(fileURLWithPath: syncPath).appendingPathComponent("\(deviceName)_folders.json")
            var fetchedFolders: [ClipboardFolder] = []
            if let folderData = try? Data(contentsOf: foldersUrl) {
                fetchedFolders = (try? JSONDecoder().decode([ClipboardFolder].self, from: folderData)) ?? []
            }
            
            // INJECT UNIFIED CLOUD COPY INTO REMOTE VIEW
            fetchedFolders.removeAll { $0.id == cloudFolderId }
            let cloudFolder = ClipboardFolder(id: cloudFolderId, name: "Cloud Copy", orderIndex: -1)
            fetchedFolders.insert(cloudFolder, at: 0)
            
            let currentCloudItems = self.history.filter { $0.folderId == cloudFolderId }
            filtered.append(contentsOf: currentCloudItems)
            
            DispatchQueue.main.async {
                self.remoteHistory = filtered
                self.remoteFolders = fetchedFolders
            }
        }
    }
    
    private var ignoreNextChange = false
    
private func checkForChanges() {
        let currentCount = pasteboard.changeCount
        if currentCount != lastChangeCount {
            lastChangeCount = currentCount
            if ignoreNextChange {
                ignoreNextChange = false
                return
            }
            
            let ignorePasswords = UserDefaults.standard.object(forKey: "ignorePasswords") as? Bool ?? true
            let ignoreTransient = UserDefaults.standard.object(forKey: "ignoreTransient") as? Bool ?? true
            let ignoreUniversalClipboard = UserDefaults.standard.object(forKey: "ignoreUniversalClipboard") as? Bool ?? false
            
            let types = pasteboard.types ?? []
            
            let passwordTypes = [
                NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
                NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType"),
                NSPasteboard.PasteboardType("com.agilebits.onepassword"),
                NSPasteboard.PasteboardType("com.apple.webinspector.password")
            ]
            let transientTypes = [
                NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
            ]
            let universalTypes = [
                NSPasteboard.PasteboardType("com.apple.is-remote-clipboard")
            ]
            
            if ignorePasswords {
                for type in passwordTypes {
                    if types.contains(type) { return }
                }
            }
            if ignoreTransient {
                for type in transientTypes {
                    if types.contains(type) { return }
                }
            }
            if ignoreUniversalClipboard {
                for type in universalTypes {
                    if types.contains(type) { return }
                }
            }
            
            let saveText = UserDefaults.standard.object(forKey: "saveText") as? Bool ?? true
            let saveLinks = UserDefaults.standard.object(forKey: "saveLinks") as? Bool ?? true
            let saveImages = UserDefaults.standard.object(forKey: "saveImages") as? Bool ?? true
            let saveFiles = UserDefaults.standard.object(forKey: "saveFiles") as? Bool ?? true
            
            let vsCodeFileType = NSPasteboard.PasteboardType("code/file-list")
            let isURL = types.contains(.URL)
            let isFile = types.contains(.fileURL) || types.contains(vsCodeFileType)
            let isImage = types.contains(.tiff) || types.contains(.png)
            
            if isFile && !saveFiles { return }
            if isImage && !saveImages { return }
            if isURL && !saveLinks { return }
            if !isURL && !isFile && !isImage && !saveText { return }
            
            let appName = NSWorkspace.shared.frontmostApplication?.localizedName
            if let activeApp = appName {
                let blacklisted = UserDefaults.standard.stringArray(forKey: "blacklistedApps") ?? ["1Password", "Bitwarden", "Keychain Access"]
                if blacklisted.contains(activeApp) {
                    return
                }
            }
            
            var newItem: ClipboardItem? = nil
            
            if isFile {
                if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
                    newItem = createFileClipboardItem(urls: urls, appName: appName, isImage: isImage)
                } else if let str = pasteboard.string(forType: vsCodeFileType) {
                    let lines = str.components(separatedBy: .newlines).filter { !$0.isEmpty }
                    let urls = lines.compactMap { URL(string: $0) }
                    newItem = createFileClipboardItem(urls: urls, appName: appName, isImage: isImage)
                }
            }
            
            if newItem == nil && isImage {
                let imgData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff)
                if let data = imgData {
                    if data.count <= maxItemSizeMB * 1024 * 1024 {
                        let id = UUID()
                        if LocalImageStore.shared.saveImage(data, id: id) {
                            let formatter = DateFormatter()
                            formatter.timeStyle = .short
                            let name = "Screenshot at \(formatter.string(from: Date()))"
                            newItem = ClipboardItem(id: id, text: name, timestamp: Date(), sourceApp: appName, hasRTF: false, hasHTML: false, isPinned: false, itemType: .image, fileURLs: nil)
                        }
                    }
                }
            }
            
            if newItem == nil {
                var extractedString: String? = pasteboard.string(forType: .string)
                if extractedString == nil {
                    extractedString = pasteboard.string(forType: NSPasteboard.PasteboardType("public.utf8-plain-text"))
                }
                if extractedString == nil {
                    extractedString = pasteboard.string(forType: NSPasteboard.PasteboardType("NSStringPboardType"))
                }
                
                if let newString = extractedString {
                    let newItemId = UUID()
                    var hasRTF = false
                    if let rtf = pasteboard.data(forType: .rtf) {
                        if rtf.count <= maxItemSizeMB * 1024 * 1024 {
                            let _ = LocalPayloadStore.shared.savePayload(rtf, id: newItemId, type: .rtf)
                            hasRTF = true
                        }
                    }
                    
                    var hasHTML = false
                    if let html = pasteboard.data(forType: .html) ?? pasteboard.data(forType: NSPasteboard.PasteboardType("public.html")) {
                        if html.count <= maxItemSizeMB * 1024 * 1024 {
                            let _ = LocalPayloadStore.shared.savePayload(html, id: newItemId, type: .html)
                            hasHTML = true
                        }
                    }
                    
                    var hasRTFD = false
                    if let rtfd = pasteboard.data(forType: .rtfd) ?? pasteboard.data(forType: NSPasteboard.PasteboardType("com.apple.flat-rtfd")) {
                        if rtfd.count <= maxItemSizeMB * 1024 * 1024 {
                            let _ = LocalPayloadStore.shared.savePayload(rtfd, id: newItemId, type: .rtfd)
                            hasRTFD = true
                        }
                    }
                    
                    var hasWebArchive = false
                    if let webArchive = pasteboard.data(forType: NSPasteboard.PasteboardType("Apple Web Archive pasteboard type")) {
                        if webArchive.count <= maxItemSizeMB * 1024 * 1024 {
                            let _ = LocalPayloadStore.shared.savePayload(webArchive, id: newItemId, type: .webArchive)
                            hasWebArchive = true
                        }
                    }
                    
                    var hasPDF = false
                    if let pdf = pasteboard.data(forType: .pdf) ?? pasteboard.data(forType: NSPasteboard.PasteboardType("com.adobe.pdf")) {
                        if pdf.count <= maxItemSizeMB * 1024 * 1024 {
                            let _ = LocalPayloadStore.shared.savePayload(pdf, id: newItemId, type: .pdf)
                            hasPDF = true
                        }
                    }
                    
                    var type: ItemType = .text
                    let trimmedStr = newString.trimmingCharacters(in: .whitespacesAndNewlines)
                    let lowerStr = trimmedStr.lowercased()
                    
                    // Browsers often attach a .URL type to regular text copies.
                    // We should only classify it as a link if the text itself is actually a URL.
                    let isActuallyURL = lowerStr.hasPrefix("http://") || lowerStr.hasPrefix("https://") || 
                                        (isURL && !trimmedStr.contains(" ") && URL(string: trimmedStr) != nil)
                                        
                    if isActuallyURL { type = .link }
                    
                    newItem = ClipboardItem(id: newItemId, text: newString, timestamp: Date(), sourceApp: appName, hasRTF: hasRTF, hasHTML: hasHTML, hasRTFD: hasRTFD, hasWebArchive: hasWebArchive, hasPDF: hasPDF, isPinned: false, itemType: type, fileURLs: nil)
                }
            }
            
            guard let itemToSave = newItem else { return }
            
            // Deduplication
            if let existingIndex = history.firstIndex(where: { $0.text == itemToSave.text && $0.itemType == itemToSave.itemType }) {
                let existingId = history[existingIndex].id
                if itemToSave.hasRTF, let data = LocalPayloadStore.shared.loadPayload(id: itemToSave.id, type: .rtf) {
                    let _ = LocalPayloadStore.shared.savePayload(data, id: existingId, type: .rtf)
                }
                if itemToSave.hasHTML, let data = LocalPayloadStore.shared.loadPayload(id: itemToSave.id, type: .html) {
                    let _ = LocalPayloadStore.shared.savePayload(data, id: existingId, type: .html)
                }
                if itemToSave.hasRTFD, let data = LocalPayloadStore.shared.loadPayload(id: itemToSave.id, type: .rtfd) {
                    let _ = LocalPayloadStore.shared.savePayload(data, id: existingId, type: .rtfd)
                }
                if itemToSave.hasWebArchive, let data = LocalPayloadStore.shared.loadPayload(id: itemToSave.id, type: .webArchive) {
                    let _ = LocalPayloadStore.shared.savePayload(data, id: existingId, type: .webArchive)
                }
                if itemToSave.hasPDF, let data = LocalPayloadStore.shared.loadPayload(id: itemToSave.id, type: .pdf) {
                    let _ = LocalPayloadStore.shared.savePayload(data, id: existingId, type: .pdf)
                }
                LocalPayloadStore.shared.deletePayloads(for: itemToSave.id)
                
                DispatchQueue.main.async {
                    var item = self.history.remove(at: existingIndex)
                    if item.itemType == .text {
                        if itemToSave.hasRTF {
                            item.hasRTF = true
                        }
                        if itemToSave.hasHTML {
                            item.hasHTML = true
                        }
                        if itemToSave.hasRTFD {
                            item.hasRTFD = true
                        }
                        if itemToSave.hasWebArchive {
                            item.hasWebArchive = true
                        }
                        if itemToSave.hasPDF {
                            item.hasPDF = true
                        }
                    }
                    self.history.insert(item, at: 0)
                }
                return
            }
            
            DispatchQueue.main.async {
                self.history.insert(itemToSave, at: 0)
                self.truncateHistory(to: self.maxHistoryCount)
                self.pruneStorageIfNeeded()
            }
        }
    }

var maxHistoryCount: Int {
        let val = UserDefaults.standard.integer(forKey: "maxHistoryCount")
        return val == 0 ? 25 : val
    }
    
    var maxItemSizeMB: Int {
        let val = UserDefaults.standard.integer(forKey: "maxItemSizeMB")
        return val == 0 ? 10 : val
    }
    
    var maxTotalStorageMB: Int {
        let val = UserDefaults.standard.integer(forKey: "maxTotalStorageMB")
        return val == 0 ? 50 : val
    }
    
    func cleanupTrashItems() {
        let retentionDays = UserDefaults.standard.integer(forKey: "deleteAfterDays")
        let limit = retentionDays == 0 ? 7 : retentionDays
        let thresholdDate = Calendar.current.date(byAdding: .day, value: -limit, to: Date())!
        
        let expiredTrash = history.filter { ($0.isDeleted ?? false) && ($0.deletedAt ?? Date.distantFuture) < thresholdDate }
        for item in expiredTrash {
            if let idx = history.firstIndex(where: { $0.id == item.id }) {
                deleteItem(at: idx, hardDelete: true)
            }
        }
    }
    
    func pruneStorageIfNeeded() {
        cleanupTrashItems()
        
        var currentSizeMB = LocalImageStore.shared.getTotalSizeMB()
        let activeSizeMB = currentSizeMB // Since Trash doesn't count towards the limit, we evaluate on all active items. Actually, let's keep it simple: just consider all images, but we'll prioritize hard-deleting trash images first.
        
        // Hard-delete trash items first if we are over limit
        var trashImages = history.filter { ($0.isDeleted ?? false) && $0.itemType == .image }.sorted { $0.timestamp < $1.timestamp }
        for img in trashImages {
            if currentSizeMB <= Double(maxTotalStorageMB) { break }
            let size = LocalImageStore.shared.getFileSizeMB(id: img.id)
            if let idx = history.firstIndex(where: { $0.id == img.id }) {
                deleteItem(at: idx, hardDelete: true)
                currentSizeMB -= size
            }
        }
        
        if currentSizeMB <= Double(maxTotalStorageMB) { return }
        
        var idsToRemove = Set<UUID>()
        let unpinnedImages = history.filter { !($0.isDeleted ?? false) && !$0.isPinned && $0.folderId == nil && $0.itemType == .image }.sorted { $0.timestamp < $1.timestamp }
        
        for img in unpinnedImages {
            if currentSizeMB <= Double(maxTotalStorageMB) { break }
            let size = LocalImageStore.shared.getFileSizeMB(id: img.id)
            LocalImageStore.shared.deleteImage(id: img.id)
            idsToRemove.insert(img.id)
            currentSizeMB -= size
        }
        
        if !idsToRemove.isEmpty {
            deleteItems(where: { idsToRemove.contains($0.id) }, hardDelete: true)
        }
    }
    private func formatSize(_ bytes: Int64) -> String {
        let dBytes = Double(bytes)
        let kb = dBytes / 1000.0
        let mb = kb / 1000.0
        let gb = mb / 1000.0
        
        if gb >= 1.0 {
            return gb > 10.0 ? String(format: "%.0f GB", round(gb)) : String(format: "%.1f GB", gb)
        } else if mb >= 1.0 {
            return mb > 10.0 ? String(format: "%.0f MB", round(mb)) : String(format: "%.1f MB", mb)
        } else if kb >= 1.0 {
            return kb > 10.0 ? String(format: "%.0f KB", round(kb)) : String(format: "%.1f KB", kb)
        } else {
            return "\(bytes) bytes"
        }
    }
    
    private func createFileClipboardItem(urls: [URL], appName: String?, isImage: Bool) -> ClipboardItem? {
        guard let firstUrl = urls.first, !urls.isEmpty else { return nil }
        
        let paths = urls.map { $0.path }
        
        var totalSize: Int64 = 0
        for path in paths {
            if let attr = try? FileManager.default.attributesOfItem(atPath: path),
               let size = attr[.size] as? Int64 {
                totalSize += size
            }
        }
        let sizeStr = formatSize(totalSize)
        
        let displayName = firstUrl.lastPathComponent
        let ext = firstUrl.pathExtension
        
        let text = paths.count == 1 ? "\(displayName) (\(sizeStr))" : "\(displayName) + \(paths.count - 1) more (\(sizeStr))"
        
        let parentFolder = firstUrl.deletingLastPathComponent().lastPathComponent
        let finalAppName = "\(parentFolder) • \(appName ?? "Finder")"
        
        let imageExts = ["png", "jpg", "jpeg", "gif", "tiff", "webp", "heic"]
        let type: ItemType = imageExts.contains(ext.lowercased()) ? .image : .file
        
        return ClipboardItem(text: text, timestamp: Date(), sourceApp: finalAppName, hasRTF: false, hasHTML: false, hasRTFD: false, hasWebArchive: false, hasPDF: false, isPinned: false, itemType: type, fileURLs: paths)
    }

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
    
    func purgeRemoteDevice(_ deviceName: String) {
        guard let folderPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !folderPath.isEmpty else { return }
        let fileURL = URL(fileURLWithPath: folderPath).appendingPathComponent("\(deviceName)_entries.json")
        let foldersURL = URL(fileURLWithPath: folderPath).appendingPathComponent("\(deviceName)_folders.json")
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: foldersURL)
        DispatchQueue.main.async {
            self.availableDevices.removeAll { $0 == deviceName }
            if self.selectedDevice == deviceName {
                self.selectedDevice = "Local (This Mac)"
            }
            
            // Clean up memory: remove imported folders for this device
            let foldersToRemove = self.folders.filter { $0.name.hasPrefix("\(deviceName) - ") }.map { $0.id }
            self.history.removeAll { foldersToRemove.contains($0.folderId ?? UUID()) }
            self.folders.removeAll { foldersToRemove.contains($0.id) }
        }
    }
    
    func disableSync() {
        DispatchQueue.main.async {
            // Remove the main Cloud Copy folder and its items
            self.history.removeAll { $0.folderId == cloudFolderId }
            self.folders.removeAll { $0.id == cloudFolderId }
            let remoteFolderIds = self.folders.filter { folder in
                return folder.id == cloudFolderId || folder.name.contains(" - ")
            }.map { $0.id }
            
            self.history.removeAll { remoteFolderIds.contains($0.folderId ?? UUID()) }
            self.folders.removeAll { remoteFolderIds.contains($0.id) }
            
            self.availableDevices = ["Local (This Mac)"]
            self.selectedDevice = "Local (This Mac)"
            UserDefaults.standard.set("", forKey: "syncFolderPath")
        }
    }
    
    func enableSync() {
        DispatchQueue.main.async {
            if let syncPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !syncPath.isEmpty {
                if !self.folders.contains(where: { $0.id == cloudFolderId }) {
                    let cloudFolder = ClipboardFolder(id: cloudFolderId, name: "Cloud Copy", orderIndex: -1)
                    self.folders.insert(cloudFolder, at: 0)
                    self.saveFolders()
                }
                // Trigger an initial save to populate the cloud
                self.saveHistory()
            }
        }
    }
    
    func renameDeviceFiles(from oldName: String, to newName: String) {
        guard let folderPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !folderPath.isEmpty else { return }
        
        let fm = FileManager.default
        let oldEntriesURL = URL(fileURLWithPath: folderPath).appendingPathComponent("\(oldName)_entries.json")
        let oldFoldersURL = URL(fileURLWithPath: folderPath).appendingPathComponent("\(oldName)_folders.json")
        
        let newEntriesURL = URL(fileURLWithPath: folderPath).appendingPathComponent("\(newName)_entries.json")
        let newFoldersURL = URL(fileURLWithPath: folderPath).appendingPathComponent("\(newName)_folders.json")
        
        if fm.fileExists(atPath: oldEntriesURL.path) {
            try? fm.moveItem(at: oldEntriesURL, to: newEntriesURL)
        }
        
        if fm.fileExists(atPath: oldFoldersURL.path) {
            try? fm.moveItem(at: oldFoldersURL, to: newFoldersURL)
        }
    }
    
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
