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
    let timestamp: Date
    var sourceApp: String?
    var hasRTF: Bool = false
    var hasHTML: Bool = false
    var isPinned: Bool = false
    var itemType: ItemType = .text
    var fileURLs: [String]?
    var folderId: UUID? = nil
    var orderIndex: Int = 0
}


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
    
    func saveImage(_ data: Data, id: UUID) -> Bool {
        guard let dir = imagesDirectory else { return false }
        let fileURL = dir.appendingPathComponent("\(id.uuidString).png")
        do {
            try data.write(to: fileURL)
            return true
        } catch {
            print("Failed to save image: \(error)")
            return false
        }
    }
    
    func loadImage(id: UUID) -> NSImage? {
        guard let dir = imagesDirectory else { return nil }
        let fileURL = dir.appendingPathComponent("\(id.uuidString).png")
        return NSImage(contentsOf: fileURL)
    }
    
    func deleteImage(id: UUID) {
        guard let dir = imagesDirectory else { return }
        let fileURL = dir.appendingPathComponent("\(id.uuidString).png")
        try? fileManager.removeItem(at: fileURL)
    }
    
    func getFileSizeMB(id: UUID) -> Double {
        guard let dir = imagesDirectory else { return 0 }
        let fileURL = dir.appendingPathComponent("\(id.uuidString).png")
        if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path), let size = attrs[.size] as? UInt64 {
            return Double(size) / (1024.0 * 1024.0)
        }
        return 0
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
    
    func savePayload(_ data: Data, id: UUID, type: PayloadType) -> Bool {
        guard let dir = payloadsDirectory else { return false }
        let fileURL = dir.appendingPathComponent("\(id.uuidString).\(type.rawValue)")
        do {
            try data.write(to: fileURL)
            return true
        } catch {
            print("Failed to save payload: \(error)")
            return false
        }
    }
    
    func loadPayload(id: UUID, type: PayloadType) -> Data? {
        guard let dir = payloadsDirectory else { return nil }
        let fileURL = dir.appendingPathComponent("\(id.uuidString).\(type.rawValue)")
        return try? Data(contentsOf: fileURL)
    }
    
    func deletePayloads(for id: UUID) {
        guard let dir = payloadsDirectory else { return }
        let rtfURL = dir.appendingPathComponent("\(id.uuidString).rtf")
        let htmlURL = dir.appendingPathComponent("\(id.uuidString).html")
        try? fileManager.removeItem(at: rtfURL)
        try? fileManager.removeItem(at: htmlURL)
    }
    
    func getFileSizeMB(id: UUID, type: PayloadType) -> Double {
        guard let dir = payloadsDirectory else { return 0 }
        let fileURL = dir.appendingPathComponent("\(id.uuidString).\(type.rawValue)")
        if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path), let size = attrs[.size] as? UInt64 {
            return Double(size) / (1024.0 * 1024.0)
        }
        return 0
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
                let syncURL = URL(fileURLWithPath: syncPath).appendingPathComponent("\(safeName).json")
                try? encoded.write(to: syncURL, options: .atomic)
            }
        }
    }
    
    func saveFolders() {
        if isReordering { return }
        if let encoded = try? JSONEncoder().encode(folders) {
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
        if searchText.isEmpty { return folders }
        return folders.filter { folder in
            if folder.name.localizedCaseInsensitiveContains(searchText) { return true }
            return history.contains(where: { $0.folderId == folder.id && $0.text.localizedCaseInsensitiveContains(searchText) })
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
        guard !ids.isEmpty else { return }
        let indices = ids.compactMap { id in folders.firstIndex(where: { $0.id == id }) }.sorted()
        guard !indices.isEmpty else { return }
        
        var source = IndexSet()
        for idx in indices { source.insert(idx) }
        
        if up {
            guard indices.first! > 0 else { return }
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

    func deleteItem(at index: Int) {
        let item = history[index]
        LocalPayloadStore.shared.deletePayloads(for: item.id)
        if item.itemType == .image {
            LocalImageStore.shared.deleteImage(id: item.id)
        }
        history.remove(at: index)
        saveHistory()
    }
    
    func deleteItems(where predicate: (ClipboardItem) -> Bool) {
        let itemsToDelete = history.filter(predicate)
        for item in itemsToDelete {
            LocalPayloadStore.shared.deletePayloads(for: item.id)
            if item.itemType == .image {
                LocalImageStore.shared.deleteImage(id: item.id)
            }
        }
        history.removeAll(where: predicate)
    }

    func clearAll() {
        deleteItems(where: { _ in true })
    }
    
    func togglePin(for id: UUID) {
        if let index = history.firstIndex(where: { $0.id == id }) {
            history[index].isPinned.toggle()
            if history[index].isPinned {
                history[index].folderId = nil // Pin directly to unassigned
            } else {
                history[index].folderId = nil // Clear folder if unpinned
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
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .filter { $0 != localDeviceName }
            .sorted()
            
        DispatchQueue.main.async {
            if self.availableDevices != devices {
                self.availableDevices = devices
            }
            // Auto-refresh remote history if currently viewing one
            if self.selectedDevice != "Local (This Mac)" {
                self.fetchRemoteHistory(for: self.selectedDevice)
            }
        }
    }
    
    func fetchRemoteHistory(for deviceName: String) {
        guard let syncPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !syncPath.isEmpty else { return }
        let url = URL(fileURLWithPath: syncPath).appendingPathComponent("\(deviceName).json")
        
        guard let data = try? Data(contentsOf: url) else { return }
        
        if let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            // Filter out files/images since they rely on local UUIDs or paths
            var filtered = decoded.filter { $0.itemType != .file && $0.itemType != .image }
            
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
            
            // Check for passwords or transient data
            let types = pasteboard.types ?? []
            let concealedTypes = [
                NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
                NSPasteboard.PasteboardType("org.nspasteboard.TransientType"),
                NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType"),
                NSPasteboard.PasteboardType("com.agilebits.onepassword"),
                NSPasteboard.PasteboardType("com.apple.webinspector.password")
            ]
            
            for type in concealedTypes {
                if types.contains(type) {
                    return
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
                    
                    var type: ItemType = .text
                    let trimmedStr = newString.trimmingCharacters(in: .whitespacesAndNewlines)
                    let lowerStr = trimmedStr.lowercased()
                    
                    // Browsers often attach a .URL type to regular text copies.
                    // We should only classify it as a link if the text itself is actually a URL.
                    let isActuallyURL = lowerStr.hasPrefix("http://") || lowerStr.hasPrefix("https://") || 
                                        (isURL && !trimmedStr.contains(" ") && URL(string: trimmedStr) != nil)
                                        
                    if isActuallyURL { type = .link }
                    
                    newItem = ClipboardItem(id: newItemId, text: newString, timestamp: Date(), sourceApp: appName, hasRTF: hasRTF, hasHTML: hasHTML, isPinned: false, itemType: type, fileURLs: nil)
                }
            }
            
            guard let itemToSave = newItem else { return }
            
            // Deduplication
            if let existingIndex = history.firstIndex(where: { $0.text == itemToSave.text && $0.itemType == itemToSave.itemType }) {
                DispatchQueue.main.async {
                    var item = self.history.remove(at: existingIndex)
                    if item.itemType == .text {
                        if itemToSave.hasRTF {
                            item.hasRTF = true
                        }
                        if itemToSave.hasHTML {
                            item.hasHTML = true
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
    
    func pruneStorageIfNeeded() {
        var currentSizeMB = LocalImageStore.shared.getTotalSizeMB()
        if currentSizeMB <= Double(maxTotalStorageMB) { return }
        
        var idsToRemove = Set<UUID>()
        let unpinnedImages = history.filter { !$0.isPinned && $0.folderId == nil && $0.itemType == .image }.sorted { $0.timestamp < $1.timestamp }
        
        for img in unpinnedImages {
            if currentSizeMB <= Double(maxTotalStorageMB) { break }
            let size = LocalImageStore.shared.getFileSizeMB(id: img.id)
            LocalImageStore.shared.deleteImage(id: img.id)
            idsToRemove.insert(img.id)
            currentSizeMB -= size
        }
        
        if !idsToRemove.isEmpty {
            deleteItems(where: { idsToRemove.contains($0.id) })
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
        let type: ItemType = (isImage || imageExts.contains(ext.lowercased())) ? .image : .file
        
        return ClipboardItem(text: text, timestamp: Date(), sourceApp: finalAppName, hasRTF: false, hasHTML: false, isPinned: false, itemType: type, fileURLs: paths)
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
                    history.remove(at: i)
                    removed += 1
                    if removed >= elementsToRemove { break }
                }
            }
        }
    }
    
    func prepareForPaste(_ item: ClipboardItem, formatType: PasteFormatType = .plain) {
        ignoreNextChange = true
        pasteboard.clearContents()
        
        let hasFiles = item.fileURLs != nil && !item.fileURLs!.isEmpty
        
        switch formatType {
        case .plain:
            if hasFiles {
                let nsUrls = item.fileURLs!.map { NSURL(fileURLWithPath: $0) }
                pasteboard.writeObjects(nsUrls)
            } else {
                pasteboard.setString(item.text, forType: .string)
            }
            
        case .rich:
            if item.hasRTF, let rtfData = LocalPayloadStore.shared.loadPayload(id: item.id, type: .rtf) { pasteboard.setData(rtfData, forType: .rtf) }
            if item.hasHTML, let htmlData = LocalPayloadStore.shared.loadPayload(id: item.id, type: .html) { pasteboard.setData(htmlData, forType: .html) }
            if hasFiles {
                let nsUrls = item.fileURLs!.map { NSURL(fileURLWithPath: $0) }
                pasteboard.writeObjects(nsUrls)
            } else {
                pasteboard.setString(item.text, forType: .string)
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
            
            if hasFiles {
                let nsUrls = item.fileURLs!.map { NSURL(fileURLWithPath: $0) }
                pasteboard.writeObjects(nsUrls)
            } else {
                pasteboard.setString(item.text, forType: .string)
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
        let fileURL = URL(fileURLWithPath: folderPath).appendingPathComponent("\(deviceName).json")
        let foldersURL = URL(fileURLWithPath: folderPath).appendingPathComponent("\(deviceName)_folders.json")
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: foldersURL)
        DispatchQueue.main.async {
            self.availableDevices.removeAll { $0 == deviceName }
            if self.selectedDevice == deviceName {
                self.selectedDevice = "Local (This Mac)"
            }
        }
    }
    
    func importItems(_ items: [ClipboardItem]) {
        let remoteDevice = self.selectedDevice != "Local (This Mac)" ? self.selectedDevice : "Remote"
        
        for var item in items {
            item.id = UUID()
            
            if let remoteFolderId = item.folderId {
                if let remoteFolder = self.remoteFolders.first(where: { $0.id == remoteFolderId }) {
                    let localFolderName = "\(remoteDevice) - \(remoteFolder.name)"
                    
                    if let existingLocalFolder = self.folders.first(where: { $0.name == localFolderName }) {
                        item.folderId = existingLocalFolder.id
                    } else {
                        var newFolder = ClipboardFolder(name: localFolderName)
                        newFolder.orderIndex = self.folders.count + 1
                        self.folders.append(newFolder)
                        item.folderId = newFolder.id
                    }
                } else {
                    item.folderId = nil // Fallback
                }
            }
            
            self.history.insert(item, at: 0)
        }
        
        if self.history.count > maxHistoryCount {
            let removedItems = Array(self.history[maxHistoryCount...])
            self.history = Array(self.history.prefix(maxHistoryCount))
            for item in removedItems {
                if item.itemType == .image {
                    LocalImageStore.shared.deleteImage(id: item.id)
                }
            }
        }
        
        self.selectedDevice = "Local (This Mac)"
    }
}
