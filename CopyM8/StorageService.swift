import Foundation
import AppKit

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
            return fileURLs
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
