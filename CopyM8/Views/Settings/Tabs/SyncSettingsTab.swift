import SwiftUI
import AppKit
import KeyboardShortcuts

extension SettingsView {
    var syncTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cloud Sync")
                .font(.system(size: 13, weight: .semibold))
            
            Text("Keep your clipboard in sync across devices using your own iCloud, Dropbox, or Google Drive folder.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            Divider()
            
            Text("Device Name:")
                .font(.system(size: 12))
            HStack(spacing: 8) {
                TextField("e.g. MacBook Pro", text: $draftDeviceName)
                    .focused($isDeviceNameFocused)
                    .onSubmit {
                        executeDeviceRename()
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 12))
                
                Button(action: {
                    executeDeviceRename()
                }) {
                    if isRenaming {
                        ProgressView().controlSize(.small).scaleEffect(0.5).frame(width: 16, height: 16)
                    } else if showRenameSuccess {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Text("Update")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(draftDeviceName == syncDeviceName || draftDeviceName.isEmpty || isRenaming)
            }
            
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
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sync Folder Location")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        
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
                            
                            Button(action: {
                                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: syncFolderPath)
                            }) {
                                Image(systemName: "folder")
                            }
                            .buttonStyle(.plain)
                            .help("Open in Finder")
                        }
                    }
                    
                    let isVisible = syncFolderPath.hasSuffix("CopyM8_Data")
                    HStack {
                        Text("Status:")
                            .font(.system(size: 11))
                        Text(isVisible ? "🟢 Visible in Finder" : "🔴 Hidden in Finder")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isVisible ? .green : .secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            if isVisible {
                                toggleVisibility(toVisible: false)
                            } else {
                                showVisibilityAlert = true
                            }
                        }) {
                            Text(isVisible ? "Hide Folder" : "Make Visible")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
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
                    
                    Divider().padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cloud Copy Storage Limits")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Max Item Size (MB):")
                                .font(.system(size: 13))
                            Spacer()
                            TextField("", value: $cloudCopyMaxItemSizeMB, format: .number)
                                .frame(width: 50)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: cloudCopyMaxItemSizeMB) { _, newValue in
                                    if newValue > 50 { cloudCopyMaxItemSizeMB = 50 }
                                    else if newValue < 1 { cloudCopyMaxItemSizeMB = 1 }
                                }
                            Stepper("", value: $cloudCopyMaxItemSizeMB, in: 1...50)
                                .labelsHidden()
                        }
                        
                        HStack {
                            Text("Total Storage Cap (MB):")
                                .font(.system(size: 13))
                            Spacer()
                            TextField("", value: $cloudCopyMaxTotalStorageMB, format: .number)
                                .frame(width: 50)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: cloudCopyMaxTotalStorageMB) { _, newValue in
                                    if newValue > 200 { cloudCopyMaxTotalStorageMB = 200 }
                                    else if newValue < 1 { cloudCopyMaxTotalStorageMB = 1 }
                                }
                            Stepper("", value: $cloudCopyMaxTotalStorageMB, in: 1...200)
                                .labelsHidden()
                        }
                    }
                    
                    Divider().padding(.vertical, 4)
                    
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
}
