import Foundation

let cloudItems: [String] = ["test"]
let syncPath = "/Users/dodos/Library/Mobile Documents/com~apple~CloudDocs/CopyM8_Data"
let cloudURL = URL(fileURLWithPath: syncPath).appendingPathComponent("cloud_copy_entries.json")
do {
    let encoded = try JSONEncoder().encode(cloudItems)
    try encoded.write(to: cloudURL, options: .atomic)
    print("Success")
} catch {
    print("Error: \(error)")
}
