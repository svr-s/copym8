import Foundation
import AppKit

/// A delegate protocol for synchronizing cloud state with the main application state.
protocol CloudSyncDelegate: AnyObject {
    /// The currently selected device tab (e.g., "Local (This Mac)" or a remote device name).
    var selectedDevice: String { get set }
    /// A list of available remote devices detected in the sync folder.
    var availableDevices: [String] { get set }
    /// The local clipboard history array.
    var history: [ClipboardItem] { get set }
    /// The clipboard history array loaded from a selected remote device.
    var remoteHistory: [ClipboardItem] { get set }
    /// The folders loaded from a selected remote device.
    var remoteFolders: [ClipboardFolder] { get set }
    /// The queue IDs loaded from a selected remote device.
    var remoteQueueIDs: [UUID] { get set }
    /// The queue playhead index loaded from a selected remote device.
    var remoteQueuePlayheadIndex: Int { get set }
}

/// A lightweight struct to sync queue state across devices.
struct QueueState: Codable {
    let queueIDs: [UUID]
    let queuePlayheadIndex: Int
}

/// `CloudSyncService` orchestrates the iCloud syncing mechanism.
/// It polls the designated sync folder for changes, discovers remote devices, 
/// fetches their clipboard histories, and manages the shared "Cloud Copy" folder state.
class CloudSyncService {
    /// Shared singleton instance.
    static let shared = CloudSyncService()
    
    /// The delegate responsible for updating the UI with synced cloud data.
    weak var delegate: CloudSyncDelegate?
    
    private var syncTimer: Timer?
    
    /// The hardcoded universal UUID for the shared "Cloud Copy" folder.
    private let cloudFolderId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    /// Starts a repeating timer that polls the sync folder for remote device changes and Cloud Copy updates.
    func startPolling() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.pollSyncFolder()
        }
    }

    /// Stops the sync polling timer.
    func stopPolling() {
        syncTimer?.invalidate()
        syncTimer = nil
    }

    /// Checks the user-defined iCloud sync folder for active devices and updates the "Cloud Copy" folder.
    /// If changes are detected, it instructs the delegate to update the UI.
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
        
        // Identify remote devices by finding files ending in _entries.json
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
            
            // Synchronize the local representation of the "Cloud Copy" folder
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
    
    /// Reads the clipboard history and folders for a specific remote device from the sync directory.
    /// - Parameter deviceName: The name of the remote device to fetch.
    func fetchRemoteHistory(for deviceName: String) {
        guard let delegate = delegate else { return }
        guard let syncPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !syncPath.isEmpty else { return }
        let url = URL(fileURLWithPath: syncPath).appendingPathComponent("\(deviceName)_entries.json")
        
        guard let data = try? Data(contentsOf: url) else { return }
        
        if let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            // Filter out files and images from remote view due to payload size constraints
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
            
            let queueUrl = URL(fileURLWithPath: syncPath).appendingPathComponent("\(deviceName)_queue.json")
            var fetchedQueueIDs: [UUID] = []
            var fetchedQueuePlayhead: Int = 0
            if let queueData = try? Data(contentsOf: queueUrl),
               let queueState = try? JSONDecoder().decode(QueueState.self, from: queueData) {
                fetchedQueueIDs = queueState.queueIDs
                fetchedQueuePlayhead = queueState.queuePlayheadIndex
            }
            
            DispatchQueue.main.async {
                delegate.remoteHistory = filtered
                delegate.remoteFolders = fetchedFolders
                delegate.remoteQueueIDs = fetchedQueueIDs
                delegate.remoteQueuePlayheadIndex = fetchedQueuePlayhead
            }
        }
    }
    
    /// Forcibly deletes a remote device's sync files from the iCloud directory.
    /// - Parameter deviceName: The name of the device to remove.
    func purgeRemoteDevice(_ deviceName: String) {
        guard let syncPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !syncPath.isEmpty else { return }
        let url = URL(fileURLWithPath: syncPath)
        
        let entriesURL = url.appendingPathComponent("\(deviceName)_entries.json")
        let foldersURL = url.appendingPathComponent("\(deviceName)_folders.json")
        let trashURL = url.appendingPathComponent("\(deviceName)_trash.json")
        let queueURL = url.appendingPathComponent("\(deviceName)_queue.json")
        
        try? FileManager.default.removeItem(at: entriesURL)
        try? FileManager.default.removeItem(at: foldersURL)
        try? FileManager.default.removeItem(at: trashURL)
        try? FileManager.default.removeItem(at: queueURL)
        
        pollSyncFolder()
    }
    
    /// Completely disables iCloud sync for this local device, wiping its sync files and stopping the polling timer.
    func disableSync() {
        guard let syncPath = UserDefaults.standard.string(forKey: "syncFolderPath"), !syncPath.isEmpty else { return }
        let localDeviceName = UserDefaults.standard.string(forKey: "syncDeviceName") ?? (Host.current().localizedName ?? "My Mac")
        let url = URL(fileURLWithPath: syncPath)
        
        let entriesURL = url.appendingPathComponent("\(localDeviceName)_entries.json")
        let foldersURL = url.appendingPathComponent("\(localDeviceName)_folders.json")
        let trashURL = url.appendingPathComponent("\(localDeviceName)_trash.json")
        let queueURL = url.appendingPathComponent("\(localDeviceName)_queue.json")
        
        try? FileManager.default.removeItem(at: entriesURL)
        try? FileManager.default.removeItem(at: foldersURL)
        try? FileManager.default.removeItem(at: trashURL)
        try? FileManager.default.removeItem(at: queueURL)
        
        UserDefaults.standard.removeObject(forKey: "syncFolderPath")
        UserDefaults.standard.removeObject(forKey: "syncDeviceName")
        stopPolling()
        
        guard let delegate = delegate else { return }
        DispatchQueue.main.async {
            delegate.availableDevices = []
            delegate.selectedDevice = "Local (This Mac)"
        }
    }
    
    /// Renames the local device's sync files in the iCloud directory to reflect a user-initiated device rename.
    /// - Parameters:
    ///   - oldName: The previous device name.
    ///   - newName: The new device name.
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
