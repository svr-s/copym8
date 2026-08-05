import Foundation
import AppKit

/// Manages the disk storage and retrieval of image data copied to the clipboard.
/// Handles both local `Application Support` storage and iCloud sync directory storage.
class LocalImageStore {
    /// Shared singleton instance.
    static let shared = LocalImageStore()
    
    private let fileManager = FileManager.default
    
    /// The default local directory for saving images (Application Support/CopyM8/Images).
    private var imagesDirectory: URL? {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = appSupport.appendingPathComponent("CopyM8/Images")
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    /// The iCloud sync directory for saving images, if Cloud Sync is enabled.
    private var cloudDirectory: URL? {
        guard let syncPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !syncPath.isEmpty else { return nil }
        let dir = URL(fileURLWithPath: syncPath).appendingPathComponent("Images")
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    /// Retrieves the appropriate directory URL based on whether the item is stored in the cloud.
    func getDirectory(inCloud: Bool) -> URL? {
        return inCloud ? cloudDirectory : imagesDirectory
    }
    
    /// Saves raw image data to disk as a PNG file.
    /// - Parameters:
    ///   - data: The raw image data to save.
    ///   - id: The UUID of the clipboard item.
    ///   - inCloud: Whether to save to the iCloud sync folder instead of local storage.
    /// - Returns: `true` if the save succeeded, `false` otherwise.
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
    
    /// Loads an image from disk into memory.
    /// If the image is in iCloud and not downloaded yet, it triggers a background download and returns nil.
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
    
    /// Deletes the image file associated with the given clipboard item ID.
    func deleteImage(id: UUID, inCloud: Bool = false) {
        guard let dir = getDirectory(inCloud: inCloud) else { return }
        let fileURL = dir.appendingPathComponent("\(id.uuidString).png")
        try? fileManager.removeItem(at: fileURL)
    }
    
    /// Calculates the size of the image file on disk in megabytes.
    func getFileSizeMB(id: UUID, inCloud: Bool = false) -> Double {
        guard let dir = getDirectory(inCloud: inCloud) else { return 0 }
        let fileURL = dir.appendingPathComponent("\(id.uuidString).png")
        if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path), let size = attrs[.size] as? UInt64 {
            return Double(size) / (1024.0 * 1024.0)
        }
        return 0
    }
    
    /// Migrates an image file between local storage and the iCloud sync folder.
    func migrateImage(id: UUID, toCloud: Bool) throws {
        guard let sourceDir = getDirectory(inCloud: !toCloud), let destDir = getDirectory(inCloud: toCloud) else { return }
        let sourceURL = sourceDir.appendingPathComponent("\(id.uuidString).png")
        let destURL = destDir.appendingPathComponent("\(id.uuidString).png")
        if fileManager.fileExists(atPath: sourceURL.path) {
            try fileManager.copyItem(at: sourceURL, to: destURL)
        }
    }

    /// Calculates the total size of all images stored in the local directory.
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

/// Represents the supported types of rich payloads stored on disk.
enum PayloadType: String {
    case rtf
    case html
    case rtfd
    case webArchive
    case pdf
}

/// Manages the disk storage and retrieval of rich payloads (RTF, HTML, etc.) copied to the clipboard.
class LocalPayloadStore {
    /// Shared singleton instance.
    static let shared = LocalPayloadStore()
    
    private let fileManager = FileManager.default
    
    /// The default local directory for saving rich payloads.
    private var payloadsDirectory: URL? {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = appSupport.appendingPathComponent("CopyM8/Payloads")
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    /// The iCloud sync directory for saving rich payloads.
    private var cloudDirectory: URL? {
        guard let syncPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !syncPath.isEmpty else { return nil }
        let dir = URL(fileURLWithPath: syncPath).appendingPathComponent("Payloads")
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    /// Retrieves the appropriate directory URL based on whether the item is stored in the cloud.
    func getDirectory(inCloud: Bool) -> URL? {
        return inCloud ? cloudDirectory : payloadsDirectory
    }
    
    /// Saves raw payload data to disk.
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
    
    /// Loads payload data from disk into memory.
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
    
    /// Deletes all payload formats (RTF, HTML, etc.) associated with a given clipboard item ID.
    func deletePayloads(for id: UUID, inCloud: Bool = false) {
        guard let dir = getDirectory(inCloud: inCloud) else { return }
        let types: [PayloadType] = [.rtf, .html, .rtfd, .webArchive, .pdf]
        for type in types {
            let fileURL = dir.appendingPathComponent("\(id.uuidString).\(type.rawValue)")
            try? fileManager.removeItem(at: fileURL)
        }
    }
    
    /// Calculates the size of a specific payload file on disk in megabytes.
    func getFileSizeMB(id: UUID, type: PayloadType, inCloud: Bool = false) -> Double {
        guard let dir = getDirectory(inCloud: inCloud) else { return 0 }
        let fileURL = dir.appendingPathComponent("\(id.uuidString).\(type.rawValue)")
        if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path), let size = attrs[.size] as? UInt64 {
            return Double(size) / (1024.0 * 1024.0)
        }
        return 0
    }
    
    /// Migrates all payload formats for a clipboard item between local storage and iCloud.
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

    /// Calculates the total size of all payloads stored in the local directory.
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

/// Manages the copying of physical files into the Cloud Sync directory for cross-device syncing.
class LocalFileStore {
    /// Shared singleton instance.
    static let shared = LocalFileStore()
    private let fileManager = FileManager.default
    
    /// The iCloud sync directory for saving files.
    private var cloudDirectory: URL? {
        guard let syncPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !syncPath.isEmpty else { return nil }
        let dir = URL(fileURLWithPath: syncPath).appendingPathComponent("Files")
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    /// Migrates physical files to or from the iCloud sync folder.
    /// - Returns: The new file URLs after migration.
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
            return fileURLs
        }
    }
    
    /// Deletes all synced files associated with a given clipboard item ID from the cloud directory.
    func deleteFiles(for id: UUID) {
        guard let dir = cloudDirectory,
              let files = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        
        for file in files {
            if file.lastPathComponent.hasPrefix("\(id.uuidString)_") {
                try? fileManager.removeItem(at: file)
            }
        }
    }
    
    /// Calculates the size of all synced files for a clipboard item in megabytes.
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
