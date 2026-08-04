import SwiftUI
import AppKit
import KeyboardShortcuts

struct DevicePurgeItem: Identifiable {
    let id: String
}

struct AntiPasteTextField: View {
    let title: String
    @Binding var text: String
    
    var body: some View {
        TextField(title, text: Binding(
            get: { text },
            set: { newValue in
                if newValue.count - text.count > 1 { return } // reject paste
                text = newValue
            }
        ))
    }
}


enum CloudProvider: String, CaseIterable {
    case icloud = "iCloud Drive"
    case dropbox = "Dropbox"
    case googleDrive = "Google Drive"
    case oneDrive = "OneDrive"
    
    var icon: String {
        switch self {
        case .icloud: return "☁️"
        case .dropbox: return "📦"
        case .googleDrive: return "🔺"
        case .oneDrive: return "☁️"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var clipboard: ClipboardManager
    @EnvironmentObject var shortcut: ShortcutManager
    @Binding var draftHistoryCount: Int
    @Binding var maxHistoryCount: Int
    
    @State var showingClearAlert = false
    @State var showDisableSyncAlert = false
    
    @State var draftDeviceName: String = ""
    @FocusState var isDeviceNameFocused: Bool
    
    @State var deviceToPurge: DevicePurgeItem? = nil
    @State var purgeConfirmationText: String = ""
    
    @AppStorage("maxItemSizeMB") var maxItemSizeMB: Int = 10
    @AppStorage("maxTotalStorageMB") var maxTotalStorageMB: Int = 50
    @AppStorage("deleteAfterDays") var deleteAfterDays: Int = 7
    
    @AppStorage("cloudCopyMaxItemSizeMB") var cloudCopyMaxItemSizeMB: Int = 10
    @AppStorage("cloudCopyMaxTotalStorageMB") var cloudCopyMaxTotalStorageMB: Int = 50
    
    @AppStorage("saveText") var saveText: Bool = true
    @AppStorage("saveLinks") var saveLinks: Bool = true
    @AppStorage("saveImages") var saveImages: Bool = true
    @AppStorage("saveFiles") var saveFiles: Bool = true
    
    @AppStorage("themePreference") var themePreference: String = "System"
    @AppStorage("activeColorName") var activeColorName: String = "Glacier"
    
    @State var blacklistedApps: [String] = []
    
    @AppStorage("ignorePasswords") var ignorePasswords: Bool = true
    @AppStorage("ignoreTransient") var ignoreTransient: Bool = true
    @AppStorage("ignoreUniversalClipboard") var ignoreUniversalClipboard: Bool = false
    
    @AppStorage("syncFolderPath") var syncFolderPath: String = ""
    @State var detectedProviders: [(CloudProvider, URL)] = []
    @State var showVisibilityAlert = false
    @State var isRenaming = false
    @State var showRenameSuccess = false
    @AppStorage("syncDeviceName") var syncDeviceName: String = Host.current().localizedName ?? "My Mac"
    
    @State var selectedTab = "General"
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("General").tag("General")
                Text("Types").tag("Types")
                Text("Sync").tag("Sync")
                Text("Privacy").tag("Privacy")
                Text("Shortcuts").tag("Shortcuts")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            Divider()
            
            ScrollView {
                Group {
                    switch selectedTab {
                    case "General":
                        generalTab
                    case "Types":
                        typesTab
                    case "Sync":
                        syncTab
                    case "Privacy":
                        privacyTab
                    case "Shortcuts":
                        shortcutsTab
                    default:
                        EmptyView()
                    }
                }
                .padding()
                .padding(.trailing, 12)
            }
            .frame(height: 380)
        }
        .frame(width: 400)
        .onAppear {
            setupKeyboardMonitor()
            draftHistoryCount = maxHistoryCount
            
            if let saved = UserDefaults.standard.stringArray(forKey: "blacklistedApps") {
                blacklistedApps = saved
            } else {
                blacklistedApps = ["1Password", "Bitwarden", "Keychain Access"]
                UserDefaults.standard.set(blacklistedApps, forKey: "blacklistedApps")
            }
        }
        .onDisappear {
            teardownKeyboardMonitor()
            maxHistoryCount = max(5, draftHistoryCount)
        }
    }
    
    @State var eventMonitor: Any?
    
    private func setupKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 48 && event.modifierFlags.contains(.option) {
                let tabs = ["General", "Types", "Sync", "Privacy", "Shortcuts"]
                guard let idx = tabs.firstIndex(of: selectedTab) else { return event }
                let isShift = event.modifierFlags.contains(.shift)
                
                var newIdx = isShift ? idx - 1 : idx + 1
                if newIdx < 0 { newIdx = tabs.count - 1 }
                if newIdx >= tabs.count { newIdx = 0 }
                
                selectedTab = tabs[newIdx]
                return nil
            }
            return event
        }
    }
    
    private func teardownKeyboardMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    // generalTab extracted to Tabs/Generaltab.swift
    
    // typesTab extracted to Tabs/Typestab.swift
    
    // syncTab extracted to Tabs/Synctab.swift
    
    func executeDeviceRename() {
        guard draftDeviceName != syncDeviceName, !draftDeviceName.isEmpty else { return }
        isDeviceNameFocused = false
        isRenaming = true
        
        // Let the UI update to show the spinner
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            commitDeviceNameChange()
            isRenaming = false
            showRenameSuccess = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showRenameSuccess = false
            }
        }
    }
    
    private func commitDeviceNameChange() {
        let trimmed = draftDeviceName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != syncDeviceName else {
            draftDeviceName = syncDeviceName
            return
        }
        if !clipboard.availableDevices.contains(trimmed) {
            let oldName = syncDeviceName
            syncDeviceName = trimmed
            clipboard.renameDeviceFiles(from: oldName, to: trimmed)
        } else {
            draftDeviceName = syncDeviceName
        }
    }
    
    func scanForProviders() {
        var providers: [(CloudProvider, URL)] = []
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        
        let paths: [(CloudProvider, [String])] = [
            (.icloud, ["Library/Mobile Documents/com~apple~CloudDocs"]),
            (.dropbox, ["Library/CloudStorage/Dropbox", "Dropbox"]),
            (.googleDrive, ["Library/CloudStorage/GoogleDrive", "Google Drive"]),
            (.oneDrive, ["Library/CloudStorage/OneDrive", "OneDrive"])
        ]
        
        for (provider, relativePaths) in paths {
            for rel in relativePaths {
                let url = home.appendingPathComponent(rel)
                if fm.fileExists(atPath: url.path) {
                    providers.append((provider, url))
                    break // Found this provider
                }
            }
        }
        
        DispatchQueue.main.async {
            self.detectedProviders = providers
        }
    }
    
    func setupSync(with baseURL: URL) {
        let fm = FileManager.default
        let visibleURL = baseURL.appendingPathComponent("CopyM8_Data")
        let hiddenURL = baseURL.appendingPathComponent(".copym8_data")
        
        let finalURL = fm.fileExists(atPath: visibleURL.path) ? visibleURL : hiddenURL
        
        do {
            try fm.createDirectory(at: finalURL, withIntermediateDirectories: true, attributes: nil)
            
            var mutableURL = finalURL
            var resourceValues = URLResourceValues()
            resourceValues.isHidden = (finalURL == hiddenURL)
            try? mutableURL.setResourceValues(resourceValues)
            
            DispatchQueue.main.async {
                self.syncFolderPath = finalURL.path
                self.clipboard.enableSync()
            }
        } catch {
            print("Failed to create sync directory: \(error)")
        }
    }
    
    func toggleVisibility(toVisible: Bool) {
        let fm = FileManager.default
        let currentURL = URL(fileURLWithPath: syncFolderPath)
        let parentURL = currentURL.deletingLastPathComponent()
        
        let newFolderName = toVisible ? "CopyM8_Data" : ".copym8_data"
        let newURL = parentURL.appendingPathComponent(newFolderName)
        
        if fm.fileExists(atPath: currentURL.path) {
            if fm.fileExists(atPath: newURL.path) {
                // If destination already exists (e.g. leftover folder), just switch to it
                var mutableURL = newURL
                var resourceValues = URLResourceValues()
                resourceValues.isHidden = !toVisible
                try? mutableURL.setResourceValues(resourceValues)
                
                DispatchQueue.main.async {
                    self.syncFolderPath = newURL.path
                }
            } else {
                do {
                    try fm.moveItem(at: currentURL, to: newURL)
                    
                    var mutableURL = newURL
                    var resourceValues = URLResourceValues()
                    resourceValues.isHidden = !toVisible
                    try? mutableURL.setResourceValues(resourceValues)
                    
                    DispatchQueue.main.async {
                        self.syncFolderPath = newURL.path
                    }
                } catch {
                    print("Failed to rename sync directory: \(error)")
                }
            }
        } else {
            // Directory didn't exist? Just update the path
            DispatchQueue.main.async {
                self.syncFolderPath = newURL.path
            }
        }
    }
    
    func selectSyncFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        shortcut.isPresentingModal = true
        if let window = NSApp.windows.first(where: { $0.isVisible && $0.isKeyWindow }) {
            panel.beginSheetModal(for: window) { response in
                shortcut.isPresentingModal = false
                if response == .OK, let url = panel.url {
                    DispatchQueue.main.async {
                        setupSync(with: url)
                    }
                }
            }
        } else {
            if panel.runModal() == .OK, let url = panel.url {
                setupSync(with: url)
            }
            shortcut.isPresentingModal = false
        }
    }
    
    // privacyTab extracted to Tabs/Privacytab.swift
    
    func addAppViaFinder() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Add to blacklist"
        
        shortcut.isPresentingModal = true
        if let window = NSApp.windows.first(where: { $0.isVisible && $0.isKeyWindow }) {
            panel.beginSheetModal(for: window) { response in
                shortcut.isPresentingModal = false
                if response == .OK, let url = panel.url {
                    let appName = url.deletingPathExtension().lastPathComponent
                    if !blacklistedApps.contains(appName) {
                        blacklistedApps.append(appName)
                        UserDefaults.standard.set(blacklistedApps, forKey: "blacklistedApps")
                    }
                }
            }
        } else {
            if panel.runModal() == .OK, let url = panel.url {
                let appName = url.deletingPathExtension().lastPathComponent
                if !blacklistedApps.contains(appName) {
                    blacklistedApps.append(appName)
                    UserDefaults.standard.set(blacklistedApps, forKey: "blacklistedApps")
                }
            }
            shortcut.isPresentingModal = false
        }
    }
    
    func removeBlacklistedApp(_ app: String) {
        blacklistedApps.removeAll { $0 == app }
        UserDefaults.standard.set(blacklistedApps, forKey: "blacklistedApps")
    }
    
    // shortcutsTab extracted to Tabs/Shortcutstab.swift
    
    func shortcutCategory(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .heavy, design: .default))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
            .padding(.bottom, 4)
    }
    
    func shortcutRow(action: String, key: String) -> some View {
        HStack {
            Text(action).font(.system(size: 12))
            Spacer()
            Text(key)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.1))
                .cornerRadius(4)
        }
    }
}
