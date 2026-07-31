import Foundation

struct ClipboardItem: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var text: String
    var timestamp: Date
    var sourceApp: String?
    var rtfData: Data?
    var folderId: UUID?
    var orderIndex: Int = 0
    var isPinned: Bool = false
    var itemType: String = "text"
    var fileURLs: [String]? = nil
    var hasRTF: Bool = false
    var hasHTML: Bool = false
}

struct ClipboardFolder: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var orderIndex: Int = 0
}

let syncPath = "/Users/dodos/Library/Mobile Documents/com~apple~CloudDocs/CopyM8_Data"
let entriesURL = URL(fileURLWithPath: syncPath).appendingPathComponent("new_source_entries.json")
let foldersURL = URL(fileURLWithPath: syncPath).appendingPathComponent("new_source_folders.json")
let cloudURL = URL(fileURLWithPath: syncPath).appendingPathComponent("cloud_copy_entries.json")
let cloudFolderId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

var fakeCloudFolderId: UUID? = nil

if let folderData = try? Data(contentsOf: foldersURL),
   var folders = try? JSONDecoder().decode([ClipboardFolder].self, from: folderData) {
    
    if let fakeIdx = folders.firstIndex(where: { $0.name == "Cloud Copy" && $0.id != cloudFolderId }) {
        fakeCloudFolderId = folders[fakeIdx].id
        folders.remove(at: fakeIdx)
        let encoded = try! JSONEncoder().encode(folders)
        try! encoded.write(to: foldersURL, options: .atomic)
        print("Removed fake Cloud Copy folder")
    }
}

if let fakeId = fakeCloudFolderId,
   let entriesData = try? Data(contentsOf: entriesURL),
   var entries = try? JSONDecoder().decode([ClipboardItem].self, from: entriesData) {
    
    var itemsToMove: [ClipboardItem] = []
    entries.removeAll { item in
        if item.folderId == fakeId {
            var modified = item
            modified.folderId = cloudFolderId
            itemsToMove.append(modified)
            return true
        }
        return false
    }
    
    if !itemsToMove.isEmpty {
        let encoded = try! JSONEncoder().encode(entries)
        try! encoded.write(to: entriesURL, options: .atomic)
        
        var cloudItems: [ClipboardItem] = []
        if let cloudData = try? Data(contentsOf: cloudURL),
           let decodedCloud = try? JSONDecoder().decode([ClipboardItem].self, from: cloudData) {
            cloudItems = decodedCloud
        }
        cloudItems.append(contentsOf: itemsToMove)
        let cloudEncoded = try! JSONEncoder().encode(cloudItems)
        try! cloudEncoded.write(to: cloudURL, options: .atomic)
        print("Moved \(itemsToMove.count) items to unified Cloud Copy")
    }
}
