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
    @Binding var draftHistoryCount: Int
    @Binding var maxHistoryCount: Int
    
    @State private var showingClearAlert = false
    @State private var showDisableSyncAlert = false
    
    @State private var draftDeviceName: String = ""
    @FocusState private var isDeviceNameFocused: Bool
    
    @State private var deviceToPurge: DevicePurgeItem? = nil
    @State private var purgeConfirmationText: String = ""
    
    @AppStorage("maxItemSizeMB") private var maxItemSizeMB: Int = 10
    @AppStorage("maxTotalStorageMB") private var maxTotalStorageMB: Int = 50
    
    @AppStorage("saveText") private var saveText: Bool = true
    @AppStorage("saveLinks") private var saveLinks: Bool = true
    @AppStorage("saveImages") private var saveImages: Bool = true
    @AppStorage("saveFiles") private var saveFiles: Bool = true
    
    @AppStorage("themePreference") private var themePreference: String = "System"
    @AppStorage("activeColorName") private var activeColorName: String = "Glacier"
    
    @State private var blacklistedApps: [String] = []
    
    @AppStorage("syncFolderPath") private var syncFolderPath: String = ""
    @State private var detectedProviders: [(CloudProvider, URL)] = []
    @State private var showVisibilityAlert = false
    @AppStorage("syncDeviceName") private var syncDeviceName: String = Host.current().localizedName ?? "My Mac"
    
    @State private var selectedTab = "General"
    
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
    }
    
    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Theme:")
                    .font(.system(size: 13))
                Spacer()
                Picker("", selection: $themePreference) {
                    Text("System").tag("System")
                    Text("Light").tag("Light")
                    Text("Dark").tag("Dark")
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 150)
                .padding(.trailing, 12)
            }
            
            Divider()
            
            Text("Accent Color:")
                .font(.system(size: 13))
            
            HStack(spacing: 8) {
                ForEach(colors, id: \.name) { c in
                    Circle()
                        .fill(c.name == "Clear" ? Color.primary.opacity(0.1) : c.color)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Color.primary, lineWidth: activeColorName == c.name ? 2 : 0)
                        )
                        .onTapGesture { 
                            activeColorName = c.name
                        }
                }
            }
            
            Divider()
            
            HStack {
                Text("History Limit:")
                    .font(.system(size: 13))
                Spacer()
                TextField("", value: $draftHistoryCount, format: .number)
                    .frame(width: 50)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        maxHistoryCount = max(5, draftHistoryCount)
                    }
                Stepper("", value: $draftHistoryCount, in: 5...500)
                    .labelsHidden()
            }
            Text("Maximum number of unpinned items to keep in history.")
                .font(.system(size: 11))
                .foregroundColor(.primary.opacity(0.5))
            
            HStack {
                Text("Max Item Size (MB):")
                    .font(.system(size: 13))
                Spacer()
                TextField("", value: $maxItemSizeMB, format: .number)
                    .frame(width: 50)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: maxItemSizeMB) { _, newValue in
                        if newValue > 20 { maxItemSizeMB = 20 }
                        else if newValue < 1 { maxItemSizeMB = 1 }
                    }
                Stepper("", value: $maxItemSizeMB, in: 1...20)
                    .labelsHidden()
            }
            
            HStack {
                Text("Total Storage Cap (MB):")
                    .font(.system(size: 13))
                Spacer()
                TextField("", value: $maxTotalStorageMB, format: .number)
                    .frame(width: 50)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: maxTotalStorageMB) { _, newValue in
                        if newValue > 100 { maxTotalStorageMB = 100 }
                        else if newValue < 1 { maxTotalStorageMB = 1 }
                    }
                Stepper("", value: $maxTotalStorageMB, in: 1...100)
                    .labelsHidden()
            }
            
            Spacer()
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                Text("📊 Storage Statistics")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.bottom, 2)
                
                HStack {
                    Text("Total Items:")
                        .font(.system(size: 12))
                    Spacer()
                    Text("\(clipboard.history.count)")
                        .font(.system(size: 12, weight: .medium))
                }
                
                HStack {
                    Text("Pinned Items:")
                        .font(.system(size: 12))
                    Spacer()
                    Text("\(clipboard.history.filter { $0.isPinned }.count)")
                        .font(.system(size: 12, weight: .medium))
                }
                
                HStack {
                    Text("Image Storage:")
                        .font(.system(size: 12))
                    Spacer()
                    Text(String(format: "%.1f MB", LocalImageStore.shared.getTotalSizeMB()))
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(8)
            
            Divider()
            
            Button(action: { showingClearAlert = true }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear All History")
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
            .alert("Clear all copied items?", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) { clipboard.clearAll() }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
    
    private var typesTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select which types of content to save.")
                .font(.system(size: 11))
                .foregroundColor(.primary.opacity(0.6))
            
            Toggle("Save Text", isOn: $saveText)
            Toggle("Save Links", isOn: $saveLinks)
            Toggle("Save Images", isOn: $saveImages)
            Toggle("Save Files", isOn: $saveFiles)
            
            Spacer()
        }
    }
    
    private var syncTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cloud Sync")
                .font(.system(size: 13, weight: .semibold))
            
            Text("Keep your clipboard in sync across devices using your own iCloud, Dropbox, or Google Drive folder.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            Divider()
            
            Text("Device Name:")
                .font(.system(size: 12))
            TextField("e.g. MacBook Pro", text: $draftDeviceName)
                .focused($isDeviceNameFocused)
                .onChange(of: isDeviceNameFocused) { focused in
                    if !focused {
                        commitDeviceNameChange()
                    }
                }
                .onSubmit {
                    commitDeviceNameChange()
                }
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .font(.system(size: 12))
            
            Text("Sync Setup")
                .font(.system(size: 12))
                .padding(.top, 4)
            
            if syncFolderPath.isEmpty {
                VStack(spacing: 8) {
                    ForEach(detectedProviders, id: \.0.rawValue) { provider, url in
                        Button(action: {
                            setupSync(with: url)
                        }) {
                            HStack {
                                Text(provider.icon)
                                Text("Sync with \(provider.rawValue)")
                                Spacer()
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button(action: { selectSyncFolder() }) {
                        HStack {
                            Image(systemName: "folder")
                            Text("Choose Custom Folder...")
                            Spacer()
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(syncFolderPath)
                            .font(.system(size: 11))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(4)
                    }
                    
                    Toggle("Make raw sync files visible in Finder", isOn: Binding(
                        get: { syncFolderPath.hasSuffix("CopyM8_Data") },
                        set: { newValue in
                            if newValue {
                                showVisibilityAlert = true
                            } else {
                                toggleVisibility(toVisible: false)
                            }
                        }
                    ))
                    .font(.system(size: 11))
                    .alert(isPresented: $showVisibilityAlert) {
                        Alert(
                            title: Text("Warning"),
                            message: Text("Exposing raw sync files allows you to view them in Finder. However, manually modifying, renaming, or deleting these files will corrupt your CopyM8 history. Are you sure you want to proceed?"),
                            primaryButton: .destructive(Text("Make Visible")) {
                                toggleVisibility(toVisible: true)
                            },
                            secondaryButton: .cancel()
                        )
                    }
                    
                    Button("Disable Sync") {
                        showDisableSyncAlert = true
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                    .buttonStyle(.plain)
                    .alert(isPresented: $showDisableSyncAlert) {
                        Alert(
                            title: Text("Disable Sync"),
                            message: Text("Are you sure you want to disable sync? This will permanently remove the Cloud Copy folder and all items imported from remote devices from this Mac's memory."),
                            primaryButton: .destructive(Text("Disable")) {
                                clipboard.disableSync()
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
            }
                
                Divider().padding(.vertical, 4)
                
                Text("Manage Devices")
                    .font(.system(size: 12, weight: .semibold))
                
                List {
                    ForEach(clipboard.availableDevices, id: \.self) { device in
                        HStack {
                            Text(device).font(.system(size: 12))
                            Spacer()
                            Button(action: {
                                // First fetch the remote history to make sure it's loaded
                                clipboard.fetchRemoteHistory(for: device)
                                // Then import everything from that device
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    if !clipboard.remoteHistory.isEmpty {
                                        clipboard.importItems(clipboard.remoteHistory)
                                    }
                                }
                                dismiss()
                            }) {
                                Image(systemName: "square.and.arrow.down").foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                            .help("Import all items from this device")
                            
                            Button(action: {
                                deviceToPurge = DevicePurgeItem(id: device)
                                purgeConfirmationText = ""
                            }) {
                                Image(systemName: "trash").foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Purge this device data")
                        }
                    }
                }
                .frame(height: 100)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1), lineWidth: 1))
            Spacer()
        }
        .sheet(item: $deviceToPurge) { deviceItem in
            VStack(spacing: 16) {
                Text("Purge Device Data")
                    .font(.system(size: 14, weight: .bold))
                
                Text("Are you sure you want to permanently delete the synced data for **\(deviceItem.id)**? This will delete the JSON file from your Sync Folder.")
                    .font(.system(size: 12))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("Please type **permanently delete** to confirm:")
                    .font(.system(size: 11, weight: .semibold))
                
                AntiPasteTextField(title: "permanently delete", text: $purgeConfirmationText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 200)
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        deviceToPurge = nil
                    }
                    
                    Button("Purge") {
                        if purgeConfirmationText == "permanently delete" {
                            clipboard.purgeRemoteDevice(deviceItem.id)
                            deviceToPurge = nil
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(purgeConfirmationText != "permanently delete")
                }
            }
            .padding(24)
            .frame(width: 300)
        }
        .onAppear {
            draftDeviceName = syncDeviceName
            
            // Re-detect on appear just in case
            scanForProviders()
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
    
    private func scanForProviders() {
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
    
    private func setupSync(with baseURL: URL) {
        let fm = FileManager.default
        let visibleURL = baseURL.appendingPathComponent("CopyM8_Data")
        let hiddenURL = baseURL.appendingPathComponent(".copym8_data")
        
        let finalURL = fm.fileExists(atPath: visibleURL.path) ? visibleURL : hiddenURL
        
        do {
            try fm.createDirectory(at: finalURL, withIntermediateDirectories: true, attributes: nil)
            DispatchQueue.main.async {
                self.syncFolderPath = finalURL.path
                self.clipboard.enableSync()
            }
        } catch {
            print("Failed to create sync directory: \(error)")
        }
    }
    
    private func toggleVisibility(toVisible: Bool) {
        let fm = FileManager.default
        let currentURL = URL(fileURLWithPath: syncFolderPath)
        let parentURL = currentURL.deletingLastPathComponent()
        
        let newFolderName = toVisible ? "CopyM8_Data" : ".copym8_data"
        let newURL = parentURL.appendingPathComponent(newFolderName)
        
        if fm.fileExists(atPath: currentURL.path) {
            if fm.fileExists(atPath: newURL.path) {
                // If destination already exists (e.g. leftover folder), just switch to it
                DispatchQueue.main.async {
                    self.syncFolderPath = newURL.path
                }
            } else {
                do {
                    try fm.moveItem(at: currentURL, to: newURL)
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
    
    private func selectSyncFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window) { response in
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
        }
    }
    
    private var privacyTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("App Blacklist")
                .font(.system(size: 13, weight: .semibold))
            
            Text("Items copied from these apps will NOT be saved to CopyM8.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            List {
                ForEach(blacklistedApps, id: \.self) { app in
                    HStack {
                        Text(app)
                            .font(.system(size: 12))
                        Spacer()
                        Button(action: {
                            removeBlacklistedApp(app)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
            .frame(height: 150)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1), lineWidth: 1))
            
            HStack {
                Button("Add App via Finder...") {
                    addAppViaFinder()
                }
                .font(.system(size: 11))
                
                Spacer()
            }
            
            Spacer()
        }
        .onAppear {
            if let saved = UserDefaults.standard.stringArray(forKey: "blacklistedApps") {
                blacklistedApps = saved
            } else {
                blacklistedApps = ["1Password", "Bitwarden", "Keychain Access"]
                UserDefaults.standard.set(blacklistedApps, forKey: "blacklistedApps")
            }
        }
    }
    
    private func addAppViaFinder() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        
        if panel.runModal() == .OK, let url = panel.url {
            let appName = url.deletingPathExtension().lastPathComponent
            if !blacklistedApps.contains(appName) {
                blacklistedApps.append(appName)
                UserDefaults.standard.set(blacklistedApps, forKey: "blacklistedApps")
            }
        }
    }
    
    private func removeBlacklistedApp(_ app: String) {
        blacklistedApps.removeAll { $0 == app }
        UserDefaults.standard.set(blacklistedApps, forKey: "blacklistedApps")
    }
    
    private var shortcutsTab: some View {
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Global Launch Shortcuts")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                    
                KeyboardShortcuts.Recorder("Open CopyM8:", name: .toggleApp)
                KeyboardShortcuts.Recorder("Open Pinned Tab:", name: .openPinned)
                KeyboardShortcuts.Recorder("Open Groups Tab:", name: .openGroups)
                
                Text("Tip: Use Cmd+Opt+P and Cmd+Opt+G for tabs!")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
            }
            .padding(10)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(8)
            
            Text("In-App Shortcuts")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)

            Group {
                shortcutCategory("General & Navigation")
                shortcutRow(action: "Open Search", key: "Cmd + F")
                shortcutRow(action: "Toggle Layout", key: "Cmd + D")
                shortcutRow(action: "Cycle Colors", key: "Cmd + K")
                shortcutRow(action: "Settings", key: "Cmd + ,")
                shortcutRow(action: "Close Window", key: "Esc")
            }
            
            Group {
                shortcutCategory("Tabs")
                shortcutRow(action: "Next Tab", key: "Opt + Tab")
                shortcutRow(action: "Previous Tab", key: "Opt + Shift + Tab")
                shortcutRow(action: "Quick Switch Tabs", key: "Opt + 1-7")
            }
            
            Group {
                shortcutCategory("Clipboard Items")
                shortcutRow(action: "Navigate Items", key: "Up / Down")
                shortcutRow(action: "Expand / Collapse Item", key: "Right / Left")
                shortcutRow(action: "Paste Plain Text", key: "Enter")
                shortcutRow(action: "Paste Rich Text", key: "Cmd + Enter")
                shortcutRow(action: "Paste Rich (No Links)", key: "Cmd + Ctrl + Enter")
                shortcutRow(action: "Quick Paste (1st-10th)", key: "1 - 0")
                shortcutRow(action: "Quick Paste Rich (1st-10th)", key: "Cmd + 1 - 0")
                shortcutRow(action: "Quick Paste Rich (No Links)", key: "Cmd + Ctrl + 1 - 0")
                shortcutRow(action: "Pin Item", key: "Cmd + P")
                shortcutRow(action: "Delete Item", key: "⌫ Delete")
            }
            
            Group {
                shortcutCategory("Groups & Folders")
                shortcutRow(action: "Expand / Collapse Folder", key: "Right / Left")
                shortcutRow(action: "Super Collapse to Parent", key: "Opt + Left")
                shortcutRow(action: "Expand All Folders", key: "Cmd + Shift + Down")
                shortcutRow(action: "Collapse All Folders", key: "Cmd + Shift + Up")
                shortcutRow(action: "Assign Group Modal", key: "Cmd + G")
                shortcutRow(action: "Quick Assign (in Modal)", key: "A - Z")
                shortcutRow(action: "Create New Group", key: "Cmd + N")
                shortcutRow(action: "Rename Folder", key: "Opt + R")
            }
            
            Group {
                shortcutCategory("Edit Mode (Bulk Actions)")
                shortcutRow(action: "Toggle Edit Mode", key: "Cmd + E")
                shortcutRow(action: "Reorder Item/Group", key: "Cmd + Up/Down")
                shortcutRow(action: "Multi-Select Range", key: "Shift + Up/Down")
                shortcutRow(action: "Toggle Selection", key: "Space")
                shortcutRow(action: "Select All in Tab", key: "Cmd + A")
                shortcutRow(action: "Unpin / Ungroup", key: "Cmd + U")
            }
            
            Group {
                shortcutCategory("Mouse Interactions")
                shortcutRow(action: "Paste Plain Text", key: "Left Click")
                shortcutRow(action: "Paste Rich Text", key: "Cmd + Click")
                shortcutRow(action: "Paste Rich (No Links)", key: "Opt + Click")
            }
        }
    }
    
    private func shortcutCategory(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .heavy, design: .default))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
            .padding(.bottom, 4)
    }
    
    private func shortcutRow(action: String, key: String) -> some View {
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
