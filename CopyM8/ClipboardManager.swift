import Foundation
import AppKit

/// Represents the basic data type of a copied clipboard item.
enum ItemType: String, Codable {
    case text
    case link
    case image
    case file
}

/// Defines the formatting type requested during a paste operation.
enum PasteFormatType {
    case plain
    case rich
    case richNoLinks
}

/// Represents a user-created folder to organize pinned clipboard items.
struct ClipboardFolder: Identifiable, Equatable, Codable {
    /// Unique identifier for the folder.
    var id = UUID()
    /// The display name of the folder.
    var name: String
    /// The sort index of the folder in the UI.
    var orderIndex: Int = 0
}

/// Represents a single entry in the clipboard history.
struct ClipboardItem: Identifiable, Equatable, Codable {
    /// Unique identifier for the item. Used as the filename for on-disk payloads.
    var id = UUID()
    /// The primary text content or display title of the item.
    let text: String
    /// When the item was copied.
    var timestamp: Date
    /// The name of the application the item was copied from.
    var sourceApp: String?
    
    // Payload flags indicating if rich data exists on disk
    var hasRTF: Bool = false
    var hasHTML: Bool = false
    var hasRTFD: Bool = false
    var hasWebArchive: Bool = false
    var hasPDF: Bool = false
    
    /// Whether the user has pinned the item to prevent eviction.
    var isPinned: Bool = false
    /// The primary classification of the item's content.
    var itemType: ItemType = .text
    /// Absolute paths for copied files (if applicable).
    var fileURLs: [String]?
    /// The ID of the folder this item belongs to, or nil if unfiled.
    var folderId: UUID? = nil
    /// The manual sort order index for pinned items. 0 indicates default sorting by timestamp.
    var orderIndex: Int = 0
    /// Whether the item is in the Trash.
    var isDeleted: Bool? = false
    /// When the item was moved to the Trash. Used for eviction.
    var deletedAt: Date? = nil
}

/// Hardcoded UUID for the "Restored" system folder.
let restoredFolderId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

/// Hardcoded UUID for the shared "Cloud Copy" system folder.
let cloudFolderId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

/// The central state manager for the CopyM8 application.
/// Handles pasteboard polling, item storage, synchronization state, and UI data binding.
class ClipboardManager: ObservableObject, CloudSyncDelegate {
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
                CloudSyncService.shared.fetchRemoteHistory(for: selectedDevice)
            }
        }
    }
    
    let pasteboard = NSPasteboard.general
    var lastChangeCount: Int = 0
    var timer: Timer?
    private let storageKey = "copym8_clipboard_history"
    private let foldersKey = "copym8_clipboard_folders"
    private let queue = DispatchQueue(label: "com.copym8.clipboard", qos: .userInteractive)
    
    var isReordering: Bool = false
    
    init() {
        CloudSyncService.shared.delegate = self
        loadHistory()
        lastChangeCount = pasteboard.changeCount
        startPolling()
        CloudSyncService.shared.startPolling()
    }
    
    // func disableSync extracted to ClipboardManager+Sync.swift
    
    // func enableSync extracted to ClipboardManager+Sync.swift
    
    // func renameDeviceFiles extracted to ClipboardManager+Sync.swift
    
    // func purgeRemoteDevice extracted to ClipboardManager+Sync.swift
    
    // func fetchRemoteHistory extracted to ClipboardManager+Sync.swift
    
    var historyFileURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = appSupport.appendingPathComponent("CopyM8/Data")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("history.json")
    }
    
    var foldersFileURL: URL? {
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
    
    // func saveFolders extracted to ClipboardManager+Folders.swift
    
    // func getFilteredFolders extracted to ClipboardManager+Folders.swift
    
    
    // func reorderFolders extracted to ClipboardManager+Reordering.swift
    
    // func reorderGroupItems extracted to ClipboardManager+Reordering.swift
    
    // func reorderPinnedItems extracted to ClipboardManager+Reordering.swift

    // func moveItem extracted to ClipboardManager+Reordering.swift

    // func moveItems extracted to ClipboardManager+Reordering.swift
    
    // func moveFolder extracted to ClipboardManager+Reordering.swift
    
    // func moveFolders extracted to ClipboardManager+Reordering.swift
    
    // func applyReorder extracted to ClipboardManager+Reordering.swift

    // func deleteItem extracted to ClipboardManager+Items.swift
    
    
    // func removeFromCloudCopyFile extracted to ClipboardManager+Sync.swift
    
    // func moveToCloud extracted to ClipboardManager+Sync.swift

    // func setFolderId extracted to ClipboardManager+Folders.swift

    // func deleteItems extracted to ClipboardManager+Items.swift

    // func clearAll extracted to ClipboardManager+Items.swift
    
    // func restoreItems extracted to ClipboardManager+Items.swift
    
    func getItemSizeMB(item: ClipboardItem) -> Double {
        var size = 0.0
        if item.itemType == .image { size += LocalImageStore.shared.getFileSizeMB(id: item.id) }
        if item.hasRTF { size += LocalPayloadStore.shared.getFileSizeMB(id: item.id, type: .rtf) }
        if item.hasHTML { size += LocalPayloadStore.shared.getFileSizeMB(id: item.id, type: .html) }
        if item.itemType == .file { size += LocalFileStore.shared.getFileSizeMB(for: item.id) }
        return size
    }
    
    // func togglePin extracted to ClipboardManager+Items.swift
    
    // private func startPolling extracted to ClipboardManager+Polling.swift
    
    
    
    
    var ignoreNextChange = false
    
func checkForChanges() {
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
                    item.timestamp = Date()
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
    
    // func pruneStorageIfNeeded extracted to ClipboardManager+Items.swift
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

    // func truncateHistory extracted to ClipboardManager+Items.swift
    
    // func isItemAvailable extracted to ClipboardManager+Items.swift
    
    // func prepareForPaste extracted to ClipboardManager+Items.swift
    
    // func triggerPasteKeystroke extracted to ClipboardManager+Items.swift
    
    
    
    
    
    // func importItems extracted to ClipboardManager+Items.swift
}
