import Foundation
import AppKit

protocol CloudSyncDelegate: AnyObject {
    var selectedDevice: String { get set }
    var availableDevices: [String] { get set }
    var history: [ClipboardItem] { get set }
    var remoteHistory: [ClipboardItem] { get set }
    var remoteFolders: [ClipboardFolder] { get set }
}

class CloudSyncService {
    static let shared = CloudSyncService()
    weak var delegate: CloudSyncDelegate?
    private var syncTimer: Timer?
    private let cloudFolderId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    func startPolling() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.pollSyncFolder()
        }
    }

    func stopPolling() {
        syncTimer?.invalidate()
        syncTimer = nil
    }

    func pollSyncFolder() {
        guard let delegate = delegate else { return }
        guard let syncPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !syncPath.isEmpty else {
            DispatchQueue.main.async {
                if !delegate.availableDevices.isEmpty { delegate.availableDevices = [] }
                if delegate.selectedDevice != "Local (This Mac)" { delegate.selectedDevice = "Local (This Mac)" }
            }
            return
        }
        
        let localDeviceName = UserDefaults.standard.string(forKey: "syncDeviceName") ?? (Host.current().localizedName ?? "My Mac")
        let url = URL(fileURLWithPath: syncPath)
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { return }
        
        let devices = files
            .filter { $0.lastPathComponent.hasSuffix("_entries.json") && !$0.lastPathComponent.hasPrefix("cloud_copy") }
            .map { $0.lastPathComponent.replacingOccurrences(of: "_entries.json", with: "") }
            .filter { $0 != localDeviceName }
            .sorted()
            
        let cloudURL = url.appendingPathComponent("cloud_copy_entries.json")
        var cloudItems: [ClipboardItem]? = nil
        
        if !FileManager.default.fileExists(atPath: cloudURL.path) {
            try? FileManager.default.startDownloadingUbiquitousItem(at: cloudURL)
        }
        
        if let data = try? Data(contentsOf: cloudURL) {
            cloudItems = try? JSONDecoder().decode([ClipboardItem].self, from: data)
        }
            
        DispatchQueue.main.async {
            if delegate.availableDevices != devices {
                delegate.availableDevices = devices
            }
            if delegate.selectedDevice != "Local (This Mac)" {
                self.fetchRemoteHistory(for: delegate.selectedDevice)
            }
            
            if let items = cloudItems {
                let currentCloudItems = delegate.history.filter { $0.folderId == self.cloudFolderId }
                if currentCloudItems != items {
                    delegate.history.removeAll { $0.folderId == self.cloudFolderId }
                    delegate.history.append(contentsOf: items)
                    delegate.history.sort { $0.timestamp > $1.timestamp }
                }
            }
        }
    }
    
    func fetchRemoteHistory(for deviceName: String) {
        guard let delegate = delegate else { return }
        guard let syncPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !syncPath.isEmpty else { return }
        let url = URL(fileURLWithPath: syncPath).appendingPathComponent("\(deviceName)_entries.json")
        
        guard let data = try? Data(contentsOf: url) else { return }
        
        if let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            var filtered = decoded.filter { $0.itemType != .file && $0.itemType != .image }
            filtered.removeAll { $0.folderId == self.cloudFolderId }
            
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
            
            fetchedFolders.removeAll { $0.id == self.cloudFolderId }
            let cloudFolder = ClipboardFolder(id: self.cloudFolderId, name: "Cloud Copy", orderIndex: -1)
            fetchedFolders.insert(cloudFolder, at: 0)
            
            let currentCloudItems = delegate.history.filter { $0.folderId == self.cloudFolderId }
            filtered.append(contentsOf: currentCloudItems)
            
            DispatchQueue.main.async {
                delegate.remoteHistory = filtered
                delegate.remoteFolders = fetchedFolders
            }
        }
    }
    
    func purgeRemoteDevice(_ deviceName: String) {
        guard let syncPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !syncPath.isEmpty else { return }
        let url = URL(fileURLWithPath: syncPath)
        
        let entriesURL = url.appendingPathComponent("\(deviceName)_entries.json")
        let foldersURL = url.appendingPathComponent("\(deviceName)_folders.json")
        let trashURL = url.appendingPathComponent("\(deviceName)_trash.json")
        
        try? FileManager.default.removeItem(at: entriesURL)
        try? FileManager.default.removeItem(at: foldersURL)
        try? FileManager.default.removeItem(at: trashURL)
        
        pollSyncFolder()
    }
    
    func disableSync() {
        guard let syncPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !syncPath.isEmpty else { return }
        let localDeviceName = UserDefaults.standard.string(forKey: "syncDeviceName") ?? (Host.current().localizedName ?? "My Mac")
        let url = URL(fileURLWithPath: syncPath)
        
        let entriesURL = url.appendingPathComponent("\(localDeviceName)_entries.json")
        let foldersURL = url.appendingPathComponent("\(localDeviceName)_folders.json")
        let trashURL = url.appendingPathComponent("\(localDeviceName)_trash.json")
        
        try? FileManager.default.removeItem(at: entriesURL)
        try? FileManager.default.removeItem(at: foldersURL)
        try? FileManager.default.removeItem(at: trashURL)
        
        UserDefaults.standard.removeObject(forKey: "syncFolderPath")
        UserDefaults.standard.removeObject(forKey: "syncDeviceName")
        stopPolling()
        
        guard let delegate = delegate else { return }
        DispatchQueue.main.async {
            delegate.availableDevices = []
            delegate.selectedDevice = "Local (This Mac)"
        }
    }
    
    func renameDeviceFiles(from oldName: String, to newName: String) {
        guard let syncPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !syncPath.isEmpty else { return }
        let url = URL(fileURLWithPath: syncPath)
        
        let oldEntries = url.appendingPathComponent("\(oldName)_entries.json")
        let newEntries = url.appendingPathComponent("\(newName)_entries.json")
        try? FileManager.default.moveItem(at: oldEntries, to: newEntries)
        
        let oldFolders = url.appendingPathComponent("\(oldName)_folders.json")
        let newFolders = url.appendingPathComponent("\(newName)_folders.json")
        try? FileManager.default.moveItem(at: oldFolders, to: newFolders)
        
        let oldTrash = url.appendingPathComponent("\(oldName)_trash.json")
        let newTrash = url.appendingPathComponent("\(newName)_trash.json")
        try? FileManager.default.moveItem(at: oldTrash, to: newTrash)
        
        UserDefaults.standard.set(newName, forKey: "syncDeviceName")
    }
}
