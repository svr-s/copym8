import SwiftUI

struct TrashBinView: View {
    @EnvironmentObject var clipboard: ClipboardManager
    @EnvironmentObject var shortcut: ShortcutManager
    @Binding var isPresented: Bool
    
    @State private var selectedIndex = 0
    @State private var showingEmptyTrashAlert = false
    @State private var showingDeleteSelectedAlert = false
    
    var trashItems: [ClipboardItem] {
        clipboard.history.filter { ($0.isDeleted ?? false) }.sorted { $0.deletedAt ?? Date() > $1.deletedAt ?? Date() }
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
                .onTapGesture { isPresented = false }
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Trash Bin")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Button(action: {
                        if !trashItems.isEmpty {
                            showingEmptyTrashAlert = true
                        }
                    }) {
                        Text("Empty Trash")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(trashItems.isEmpty)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                if trashItems.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "trash")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(.bottom, 10)
                        Text("Trash is empty")
                            .font(.body)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(Array(trashItems.enumerated()), id: \.element.id) { index, item in
                                    TrashItemRow(item: item, isSelected: index == selectedIndex)
                                        .id(index)
                                        .onTapGesture {
                                            selectedIndex = index
                                        }
                                }
                            }
                            .padding()
                        }
                        .onChange(of: selectedIndex) { _, newIndex in
                            withAnimation { proxy.scrollTo(newIndex, anchor: .center) }
                        }
                    }
                }
                
                Divider()
                
                // Footer
                HStack {
                    Text("Esc to close")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("⌘Z to restore • ⌘⌫ to delete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
            }
            .frame(width: 400, height: 500)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: 10)
            
            // Popups overlay
            if showingEmptyTrashAlert {
                ZStack {
                    Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)
                    DeleteConfirmationView(
                        isFolderDeletion: false,
                        itemCount: trashItems.count,
                        onConfirm: { _ in
                            clipboard.deleteItems(where: { ($0.isDeleted ?? false) }, hardDelete: true)
                            showingEmptyTrashAlert = false
                        },
                        onCancel: { showingEmptyTrashAlert = false }
                    )
                    .frame(width: 280)
                    .padding(20)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                    .shadow(radius: 10)
                }
            } else if showingDeleteSelectedAlert {
                ZStack {
                    Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)
                    DeleteConfirmationView(
                        isFolderDeletion: false,
                        itemCount: 1,
                        onConfirm: { _ in
                            if selectedIndex >= 0 && selectedIndex < trashItems.count {
                                let id = trashItems[selectedIndex].id
                                if selectedIndex > 0 && selectedIndex == trashItems.count - 1 {
                                    selectedIndex -= 1
                                }
                                clipboard.deleteItems(where: { $0.id == id }, hardDelete: true)
                            }
                            showingDeleteSelectedAlert = false
                        },
                        onCancel: { showingDeleteSelectedAlert = false }
                    )
                    .frame(width: 280)
                    .padding(20)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                    .shadow(radius: 10)
                }
            }
        }
        .onAppear {
            setupKeyboardMonitor()
        }
        .onDisappear {
            teardownKeyboardMonitor()
        }
    }
    
    // MARK: - Keyboard Handling
    @State private var localEventMonitor: Any?
    
    private func setupKeyboardMonitor() {
        if localEventMonitor == nil {
            localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                return handleKeyDown(event)
            }
        }
    }
    
    private func teardownKeyboardMonitor() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }
    
    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        if showingEmptyTrashAlert || showingDeleteSelectedAlert {
            if event.keyCode == 36 { // Enter
                if showingEmptyTrashAlert {
                    clipboard.deleteItems(where: { ($0.isDeleted ?? false) }, hardDelete: true)
                    showingEmptyTrashAlert = false
                } else if showingDeleteSelectedAlert {
                    if selectedIndex >= 0 && selectedIndex < trashItems.count {
                        let id = trashItems[selectedIndex].id
                        if selectedIndex > 0 && selectedIndex == trashItems.count - 1 { selectedIndex -= 1 }
                        clipboard.deleteItems(where: { $0.id == id }, hardDelete: true)
                    }
                    showingDeleteSelectedAlert = false
                }
                return nil
            } else if event.keyCode == 53 { // Esc
                showingEmptyTrashAlert = false
                showingDeleteSelectedAlert = false
                return nil
            }
            return nil
        }
        
        let isCmd = event.modifierFlags.contains(.command)
        let isShift = event.modifierFlags.contains(.shift)
        
        switch event.keyCode {
        case 53: // Esc
            isPresented = false
            return nil
            
        case 125: // Down Arrow
            if selectedIndex < trashItems.count - 1 {
                selectedIndex += 1
            }
            return nil
            
        case 126: // Up Arrow
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return nil
            
        case 6: // Cmd + Z -> Restore
            if isCmd && !isShift {
                if selectedIndex >= 0 && selectedIndex < trashItems.count {
                    let id = trashItems[selectedIndex].id
                    if selectedIndex > 0 && selectedIndex == trashItems.count - 1 { selectedIndex -= 1 }
                    clipboard.restoreItems(ids: [id])
                }
                return nil
            }
            return event
            
        case 51: // Backspace
            if isCmd {
                if isShift {
                    // Cmd + Shift + Backspace -> Empty Trash
                    if !trashItems.isEmpty {
                        showingEmptyTrashAlert = true
                    }
                } else {
                    // Cmd + Backspace -> Hard Delete
                    if !trashItems.isEmpty {
                        showingDeleteSelectedAlert = true
                    }
                }
                return nil
            }
            // Normal backspace -> soft delete -> in trash bin means hard delete? No, let's keep hard delete strictly to cmd+backspace
            // Actually user said "Delete in the trashbin indicates hard delete and the pop up is perfect"
            // Wait, does "Delete" mean Backspace or Cmd+Delete? Mac users usually mean Backspace.
            // Okay, let's make simple Backspace trigger the popup for hard deletion in the trash bin.
            if !trashItems.isEmpty {
                showingDeleteSelectedAlert = true
            }
            return nil
            
        case 17: // Cmd + Shift + T
            if isCmd && isShift {
                isPresented = false
                return nil
            }
            return event
            
        default:
            return event
        }
    }
}

struct TrashItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    
    var body: some View {
        HStack {
            if item.itemType == .image, let data = LocalImageStore.shared.loadImage(id: item.id), let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else if item.itemType == .link {
                Image(systemName: "link")
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else if item.itemType == .file {
                Image(systemName: "doc")
                    .frame(width: 40, height: 40)
                    .background(Color.orange.opacity(0.1))
                    .foregroundColor(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Text(item.text.prefix(2).uppercased())
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .frame(width: 40, height: 40)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.text)
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundColor(isSelected ? .white : .primary)
                
                HStack {
                    if let app = item.sourceApp {
                        Text(app)
                            .font(.caption2)
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    }
                    Spacer()
                    if let deletedAt = item.deletedAt {
                        Text(formatDate(deletedAt))
                            .font(.caption2)
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    }
                }
            }
            .padding(.leading, 8)
            Spacer()
        }
        .padding(8)
        .background(isSelected ? Color.blue : Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
