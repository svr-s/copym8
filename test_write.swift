import Foundation

let syncPath = "/Users/dodos/Library/Mobile Documents/com~apple~CloudDocs/CopyM8_Data"
let cloudURL = URL(fileURLWithPath: syncPath).appendingPathComponent("cloud_copy_entries.json")
let testData = "test".data(using: .utf8)!

do {
    try testData.write(to: cloudURL, options: .atomic)
    print("Write successful to \(cloudURL.path)")
} catch {
    print("Write failed: \(error)")
}
