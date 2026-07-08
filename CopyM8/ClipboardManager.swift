import Foundation
import AppKit

enum ItemType: String, Codable {
    case text
    case link
    case image
    case file
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
    var rtfData: Data?
    var isPinned: Bool = false
    var itemType: ItemType = .text
    var fileURL: String?
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
    
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    private let storageKey = "copym8_clipboard_history"
    private let foldersKey = "copym8_clipboard_folders"
    
    init() {
        loadHistory()
        lastChangeCount = pasteboard.changeCount
        startPolling()
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            
            var updated = decoded
            for i in 0..<updated.count {
                if updated[i].itemType == .text {
                    let str = updated[i].text.lowercased()
                    if str.hasPrefix("http://") || str.hasPrefix("https://") {
                        updated[i].itemType = .link
                    }
                }
            }
            self.history = updated
        }
        
        if let folderData = UserDefaults.standard.data(forKey: foldersKey),
           let decodedFolders = try? JSONDecoder().decode([ClipboardFolder].self, from: folderData) {
            self.folders = decodedFolders
        }
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func saveFolders() {
        if let encoded = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(encoded, forKey: foldersKey)
        }
    }
    
    func clearAll() {
        history.removeAll()
    }
    
    func togglePin(for id: UUID) {
        if let index = history.firstIndex(where: { $0.id == id }) {
            history[index].isPinned.toggle()
            if history[index].isPinned {
                history[index].folderId = nil // Pin directly to unassigned
            } else {
                history[index].folderId = nil // Clear folder if unpinned
            }
        }
    }
    
    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
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
            var newItem: ClipboardItem? = nil
            
            if isFile {
                if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let url = urls.first {
                    let path = url.path
                    let text = url.lastPathComponent
                    newItem = ClipboardItem(text: text, timestamp: Date(), sourceApp: appName, rtfData: nil, isPinned: false, itemType: .file, fileURL: path)
                } else if let str = pasteboard.string(forType: vsCodeFileType) {
                    let lines = str.components(separatedBy: .newlines).filter { !$0.isEmpty }
                    if let first = lines.first, let url = URL(string: first) {
                        let path = url.path
                        let text = url.lastPathComponent
                        newItem = ClipboardItem(text: text, timestamp: Date(), sourceApp: appName, rtfData: nil, isPinned: false, itemType: .file, fileURL: path)
                    }
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
                            newItem = ClipboardItem(id: id, text: name, timestamp: Date(), sourceApp: appName, rtfData: nil, isPinned: false, itemType: .image, fileURL: nil)
                        }
                    }
                }
            }
            
            if newItem == nil, let newString = pasteboard.string(forType: .string) {
                var rtfData: Data? = nil
                if let rtf = pasteboard.data(forType: .rtf) {
                    if rtf.count <= maxItemSizeMB * 1024 * 1024 {
                        rtfData = rtf
                    }
                }
                
                var type: ItemType = .text
                let lowerStr = newString.lowercased()
                if isURL || lowerStr.hasPrefix("http://") || lowerStr.hasPrefix("https://") { type = .link }
                
                newItem = ClipboardItem(text: newString, timestamp: Date(), sourceApp: appName, rtfData: rtfData, isPinned: false, itemType: type, fileURL: nil)
            }
            
            guard let itemToSave = newItem else { return }
            
            // Deduplication
            if let existingIndex = history.firstIndex(where: { $0.text == itemToSave.text && $0.itemType == itemToSave.itemType }) {
                DispatchQueue.main.async {
                    var item = self.history.remove(at: existingIndex)
                    if item.itemType == .text, let rtf = itemToSave.rtfData {
                        item.rtfData = rtf
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
        let unpinnedImages = history.filter { !$0.isPinned && $0.itemType == .image }.sorted { $0.timestamp < $1.timestamp }
        
        for img in unpinnedImages {
            if currentSizeMB <= Double(maxTotalStorageMB) { break }
            let size = LocalImageStore.shared.getFileSizeMB(id: img.id)
            LocalImageStore.shared.deleteImage(id: img.id)
            idsToRemove.insert(img.id)
            currentSizeMB -= size
        }
        
        if !idsToRemove.isEmpty {
            history.removeAll { idsToRemove.contains($0.id) }
        }
    }
    
    func truncateHistory(to limit: Int) {
        let unpinnedCount = history.filter { !$0.isPinned }.count
        if unpinnedCount > limit {
            let elementsToRemove = unpinnedCount - limit
            var removed = 0
            for i in stride(from: history.count - 1, through: 0, by: -1) {
                if !history[i].isPinned {
                    history.remove(at: i)
                    removed += 1
                    if removed >= elementsToRemove {
                        break
                    }
                }
            }
        }
    }
    
    func prepareForPaste(_ item: ClipboardItem, isFormatted: Bool = false) {
        ignoreNextChange = true
        pasteboard.clearContents()
        
        if isFormatted, let rtfData = item.rtfData {
            pasteboard.setData(rtfData, forType: .rtf)
            // also set plain text as fallback
            pasteboard.setString(item.text, forType: .string)
        } else {
            pasteboard.setString(item.text, forType: .string)
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
}
