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
    var itemType: String = "text" // just a string for testing
    var fileURLs: [String]? = nil
    var hasRTF: Bool = false
    var hasHTML: Bool = false
}

let cloudFolderId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

// Mock
var history: [ClipboardItem] = []

let item = ClipboardItem(text: "Test", timestamp: Date(), folderId: cloudFolderId)
history.append(item)

var cloudItems = [item]

let currentCloudItems = history.filter { $0.folderId == cloudFolderId }
if currentCloudItems != cloudItems {
    print("Different!")
} else {
    print("Same!")
}
