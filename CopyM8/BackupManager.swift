import Foundation

struct BackupInfo {
    let slotIndex: Int
    let date: Date
    let label: String // "(Most Recent)", "(Previous)", or "(Oldest)"
}

class BackupManager {
    static let shared = BackupManager()
    
    private let backupsDir: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("CopyM8")
        let dataDir = appDir.appendingPathComponent("Data")
        backupsDir = dataDir.appendingPathComponent("Backups")
        
        try? FileManager.default.createDirectory(at: backupsDir, withIntermediateDirectories: true, attributes: nil)
    }
    
    // Returns available backups sorted from most recent (slot 1) to oldest (slot 3).
    func getAvailableBackups() -> [BackupInfo] {
        var backups: [BackupInfo] = []
        let labels = [1: "(Most Recent)", 2: "(Previous)", 3: "(Oldest)"]
        
        for slotIndex in 1...3 {
            let slotDir = backupsDir.appendingPathComponent("\(slotIndex)")
            let historyFile = slotDir.appendingPathComponent("history.json")
            
            if FileManager.default.fileExists(atPath: historyFile.path),
               let attrs = try? FileManager.default.attributesOfItem(atPath: historyFile.path),
               let modificationDate = attrs[.modificationDate] as? Date {
                backups.append(BackupInfo(slotIndex: slotIndex, date: modificationDate, label: labels[slotIndex] ?? ""))
            }
        }
        return backups
    }
    
    /// Rotates backups and saves the current live session to slot 1.
    /// Limits the maximum number of backups according to user preferences.
    func rotateAndSave(maxBackupsCount: Int, history: [ClipboardItem], folders: [ClipboardFolder], queueIDs: [UUID]) {
        guard maxBackupsCount > 0 else {
            // If backup is disabled, optionally clear existing backups
            try? FileManager.default.removeItem(at: backupsDir)
            try? FileManager.default.createDirectory(at: backupsDir, withIntermediateDirectories: true, attributes: nil)
            return
        }
        
        let fm = FileManager.default
        
        // 1. Delete backups beyond maxBackupsCount
        for slot in (maxBackupsCount + 1)...5 {
            let extraSlotDir = backupsDir.appendingPathComponent("\(slot)")
            try? fm.removeItem(at: extraSlotDir)
        }
        
        // 2. Rotate existing valid backups down
        if maxBackupsCount > 1 {
            for slot in stride(from: maxBackupsCount - 1, through: 1, by: -1) {
                let currentSlotDir = backupsDir.appendingPathComponent("\(slot)")
                let nextSlotDir = backupsDir.appendingPathComponent("\(slot + 1)")
                
                if fm.fileExists(atPath: currentSlotDir.path) {
                    try? fm.removeItem(at: nextSlotDir)
                    try? fm.moveItem(at: currentSlotDir, to: nextSlotDir)
                }
            }
        } else {
            // If max is exactly 1, just delete slot 1 before overwriting
            let slot1Dir = backupsDir.appendingPathComponent("1")
            try? fm.removeItem(at: slot1Dir)
        }
        
        // 3. Save new state to Slot 1
        let slot1Dir = backupsDir.appendingPathComponent("1")
        try? fm.createDirectory(at: slot1Dir, withIntermediateDirectories: true, attributes: nil)
        
        // Atomic JSON Writes
        let historyURL = slot1Dir.appendingPathComponent("history.json")
        let foldersURL = slot1Dir.appendingPathComponent("folders.json")
        let queueURL = slot1Dir.appendingPathComponent("queue.json")
        
        if let hData = try? JSONEncoder().encode(history) {
            try? hData.write(to: historyURL, options: .atomic)
        }
        if let fData = try? JSONEncoder().encode(folders) {
            try? fData.write(to: foldersURL, options: .atomic)
        }
        if let qData = try? JSONEncoder().encode(queueIDs) {
            try? qData.write(to: queueURL, options: .atomic)
        }
        
        // Copy Payloads & Images
        let liveDataDir = backupsDir.deletingLastPathComponent() // `Data`
        let livePayloads = liveDataDir.appendingPathComponent("Payloads")
        let liveImages = liveDataDir.appendingPathComponent("Images") // Wait, Images was mostly stored parallel to Data or inside Data? Let's check LocalImageStore.
        // Actually, LocalImageStore places it at appDir/Images.
        // Let's resolve the actual paths properly based on the stores.
        
        let appDir = liveDataDir.deletingLastPathComponent()
        let trueLivePayloads = appDir.appendingPathComponent("Payloads")
        let trueLiveImages = appDir.appendingPathComponent("Images")
        
        let backupPayloads = slot1Dir.appendingPathComponent("Payloads")
        let backupImages = slot1Dir.appendingPathComponent("Images")
        
        if fm.fileExists(atPath: trueLivePayloads.path) {
            try? fm.copyItem(at: trueLivePayloads, to: backupPayloads)
        } else {
            try? fm.createDirectory(at: backupPayloads, withIntermediateDirectories: true, attributes: nil)
        }
        
        if fm.fileExists(atPath: trueLiveImages.path) {
            try? fm.copyItem(at: trueLiveImages, to: backupImages)
        } else {
            try? fm.createDirectory(at: backupImages, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    /// Fetches the backup data and overwrites the live environment with it.
    /// Safely backs up the current session first before applying the restore.
    func restoreBackup(slotIndex: Int, currentHistory: [ClipboardItem], currentFolders: [ClipboardFolder], currentQueue: [UUID], maxBackupsCount: Int) -> (history: [ClipboardItem], folders: [ClipboardFolder], queue: [UUID])? {
        let slotDir = backupsDir.appendingPathComponent("\(slotIndex)")
        let historyURL = slotDir.appendingPathComponent("history.json")
        let foldersURL = slotDir.appendingPathComponent("folders.json")
        let queueURL = slotDir.appendingPathComponent("queue.json")
        let backupPayloads = slotDir.appendingPathComponent("Payloads")
        let backupImages = slotDir.appendingPathComponent("Images")
        
        let fm = FileManager.default
        
        // 1. Decode the backup data FIRST (before rotating, which shifts the slots)
        guard let hData = try? Data(contentsOf: historyURL), let history = try? JSONDecoder().decode([ClipboardItem].self, from: hData) else {
            return nil
        }
        
        let folders: [ClipboardFolder] = {
            if let fData = try? Data(contentsOf: foldersURL), let f = try? JSONDecoder().decode([ClipboardFolder].self, from: fData) { return f }
            return []
        }()
        
        let queue: [UUID] = {
            if let qData = try? Data(contentsOf: queueURL), let q = try? JSONDecoder().decode([UUID].self, from: qData) { return q }
            return []
        }()
        
        // 2. Copy the backup payloads to a temp directory before we rotate (since rotation shifts the folders)
        let liveDataDir = backupsDir.deletingLastPathComponent() // `Data`
        let appDir = liveDataDir.deletingLastPathComponent()
        let tempPayloads = appDir.appendingPathComponent("TempPayloads")
        let tempImages = appDir.appendingPathComponent("TempImages")
        try? fm.removeItem(at: tempPayloads)
        try? fm.removeItem(at: tempImages)
        
        if fm.fileExists(atPath: backupPayloads.path) { try? fm.copyItem(at: backupPayloads, to: tempPayloads) }
        if fm.fileExists(atPath: backupImages.path) { try? fm.copyItem(at: backupImages, to: tempImages) }
        
        // 3. Perform safety parachute: backup current state (this shifts existing backups down)
        rotateAndSave(maxBackupsCount: maxBackupsCount, history: currentHistory, folders: currentFolders, queueIDs: currentQueue)
        
        // 4. Wipe live payloads & images, and move temp to live
        let trueLivePayloads = appDir.appendingPathComponent("Payloads")
        let trueLiveImages = appDir.appendingPathComponent("Images")
        
        try? fm.removeItem(at: trueLivePayloads)
        try? fm.removeItem(at: trueLiveImages)
        
        if fm.fileExists(atPath: tempPayloads.path) { try? fm.moveItem(at: tempPayloads, to: trueLivePayloads) }
        else { try? fm.createDirectory(at: trueLivePayloads, withIntermediateDirectories: true, attributes: nil) }
        
        if fm.fileExists(atPath: tempImages.path) { try? fm.moveItem(at: tempImages, to: trueLiveImages) }
        else { try? fm.createDirectory(at: trueLiveImages, withIntermediateDirectories: true, attributes: nil) }
        
        return (history, folders, queue)
    }
}
