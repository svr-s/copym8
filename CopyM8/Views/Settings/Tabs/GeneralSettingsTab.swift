import SwiftUI
import AppKit
import KeyboardShortcuts

extension SettingsView {
    var generalTab: some View {
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Accent Color:")
                    .font(.system(size: 13))
                Text("Changes the color of the infinity glow in the CopyM8 pill.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
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
                Stepper("", value: $draftHistoryCount, in: 5...1000)
                    .labelsHidden()
                    .onChange(of: draftHistoryCount) { _, newValue in
                        maxHistoryCount = max(5, newValue)
                    }
            }
            Text("Maximum number of unpinned items to keep in history.")
                .font(.system(size: 11))
                .foregroundColor(.primary.opacity(0.5))
            
            HStack {
                Text("Max Queue Size:")
                    .font(.system(size: 13))
                Spacer()
                TextField("", value: $maxQueueSize, format: .number)
                    .frame(width: 50)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: maxQueueSize) { _, newValue in
                        if newValue > 10 { maxQueueSize = 10 }
                        else if newValue < 1 { maxQueueSize = 1 }
                    }
                Stepper("", value: $maxQueueSize, in: 1...10)
                    .labelsHidden()
            }
            Text("Maximum number of items you can enqueue for sequential pasting.")
                .font(.system(size: 11))
                .foregroundColor(.primary.opacity(0.5))
            
            Divider().padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Local Storage Limits")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                
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
                
                HStack {
                    Text("Trash Retention (Days):")
                        .font(.system(size: 13))
                    Spacer()
                    TextField("", value: $deleteAfterDays, format: .number)
                        .frame(width: 50)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: deleteAfterDays) { _, newValue in
                            if newValue > 30 { deleteAfterDays = 30 }
                            else if newValue < 1 { deleteAfterDays = 1 }
                        }
                    Stepper("", value: $deleteAfterDays, in: 1...30)
                        .labelsHidden()
                }
                
                Text("Items in the Trash do not count towards the storage limits, but consume physical space until expired.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Divider().padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Rolling Backups")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Number of Backups (Max 3):")
                        .font(.system(size: 13))
                    Spacer()
                    TextField("", value: $draftMaxBackupsCount, format: .number)
                        .frame(width: 50)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: draftMaxBackupsCount) { _, newValue in
                            let clamped = max(0, min(3, newValue))
                            if clamped == maxBackupsCount { return }
                            
                            if clamped < maxBackupsCount {
                                pendingBackupLimit = clamped
                                DispatchQueue.main.async {
                                    draftMaxBackupsCount = maxBackupsCount
                                    showDecreaseAlert = true
                                }
                            } else if clamped > maxBackupsCount {
                                maxBackupsCount = clamped
                                NotificationCenter.default.post(name: Notification.Name("ShowSettingsToast"), object: "Backup limit increased to \(clamped)")
                            }
                        }
                    Stepper("", value: $draftMaxBackupsCount, in: 0...3)
                        .labelsHidden()
                }
                .alert("Reduce backup limit?", isPresented: $showDecreaseAlert) {
                    Button("Cancel", role: .cancel) {
                        draftMaxBackupsCount = maxBackupsCount
                    }
                    Button("Delete Old Backups", role: .destructive) {
                        BackupManager.shared.deleteBackups(olderThan: pendingBackupLimit)
                        maxBackupsCount = pendingBackupLimit
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            draftMaxBackupsCount = pendingBackupLimit
                            availableBackups = BackupManager.shared.getAvailableBackups()
                            NotificationCenter.default.post(name: Notification.Name("ShowSettingsToast"), object: "Old backups deleted")
                        }
                    }
                } message: {
                    Text("This will permanently delete your oldest backup(s) immediately.")
                }
                
                Text("CopyM8 creates a backup when you close the app. Set to 0 to disable.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                if !availableBackups.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(availableBackups, id: \.slotIndex) { backup in
                            Button(action: {
                                clipboard.applyRestore(fromSlot: backup.slotIndex)
                                NotificationCenter.default.post(name: Notification.Name("ShowSettingsToast"), object: "Backup restored successfully")
                                // Refresh list
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    availableBackups = BackupManager.shared.getAvailableBackups()
                                }
                            }) {
                                Text("⏪ Restore from \(backupDateFormatter.string(from: backup.date)) \(backup.label)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                            .onHover { isHovered in
                                NSCursor.pointingHand.set()
                            }
                        }
                    }
                    .padding(.top, 4)
                }
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
                
                HStack {
                    Text("Folder Items Size:")
                        .font(.system(size: 12))
                    Spacer()
                    let folderSize = clipboard.history.filter { $0.folderId != nil && !($0.isDeleted ?? false) && $0.folderId != restoredFolderId }.reduce(0.0) { $0 + clipboard.getItemSizeMB(item: $1) }
                    Text(String(format: "%.1f MB", folderSize))
                        .font(.system(size: 12, weight: .medium))
                }
                
                HStack {
                    Text("Deleted Items Size:")
                        .font(.system(size: 12))
                    Spacer()
                    let deletedSize = clipboard.history.filter { $0.isDeleted ?? false }.reduce(0.0) { $0 + clipboard.getItemSizeMB(item: $1) }
                    Text(String(format: "%.1f MB", deletedSize))
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
        .onAppear {
            availableBackups = BackupManager.shared.getAvailableBackups()
        }
    }
}
