import SwiftUI

struct GroupAssignmentView: View {
    @EnvironmentObject var clipboard: ClipboardManager
    @Environment(\.dismiss) var dismiss
    let itemIds: Set<UUID>
    var onComplete: (() -> Void)? = nil
    
    @State private var newFolderName: String = ""
    @State private var isCreatingNew = false
    @FocusState private var isTextFieldFocused: Bool
    
    @State private var selectedIndex: Int = 0
    @State private var localEventMonitor: Any?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Assign to Group")
                .font(.headline)
            
            if clipboard.folders.isEmpty && !isCreatingNew {
                Text("No groups available.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(clipboard.folders.enumerated()), id: \.element.id) { index, folder in
                            let letter = String(UnicodeScalar(UInt8(65 + index)))
                            Button(action: {
                                assignToFolder(folder.id)
                            }) {
                                HStack {
                                    Text(letter)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .frame(width: 16, alignment: .leading)
                                    Image(nsImage: NSImage(named: NSImage.folderName)!)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 14, height: 14)
                                    Text(folder.name)
                                        .foregroundColor(index == selectedIndex ? .white : .primary)
                                    Spacer()
                                }
                                .padding(8)
                                .background(index == selectedIndex ? Color.accentColor : Color.primary.opacity(0.05))
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .onHover { hovering in
                                if hovering { selectedIndex = index }
                            }
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
            
            if isCreatingNew {
                HStack {
                    TextField("New Group Name", text: $newFolderName)
                        .focused($isTextFieldFocused)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onAppear { 
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isTextFieldFocused = true 
                            }
                        }
                        .onSubmit {
                            createNewFolder()
                        }
                    Button("Save") {
                        createNewFolder()
                    }
                    .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                Button(action: {
                    withAnimation { isCreatingNew = true }
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Create New Group")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                .keyboardShortcut("n", modifiers: .command)
            }
            
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(width: 300)
        .onAppear {
            setupKeyboardMonitor()
        }
        .onDisappear {
            teardownKeyboardMonitor()
        }
    }
    
    private func setupKeyboardMonitor() {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard !isCreatingNew else { return event }
            
            if let chars = event.charactersIgnoringModifiers?.uppercased(), chars.count == 1 {
                let scalar = chars.unicodeScalars.first!.value
                if scalar >= 65 && scalar <= 90 { // A-Z
                    let index = Int(scalar - 65)
                    if index < clipboard.folders.count {
                        assignToFolder(clipboard.folders[index].id)
                        return nil
                    }
                }
            }
            
            switch event.keyCode {
            case 126: // Up
                if selectedIndex > 0 { selectedIndex -= 1 }
                return nil
            case 125: // Down
                if selectedIndex < clipboard.folders.count - 1 { selectedIndex += 1 }
                return nil
            case 36, 76: // Enter / Return
                if selectedIndex >= 0 && selectedIndex < clipboard.folders.count {
                    assignToFolder(clipboard.folders[selectedIndex].id)
                }
                return nil
            default:
                break
            }
            
            return event
        }
    }
    
    private func teardownKeyboardMonitor() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }
    
    private func assignToFolder(_ folderId: UUID) {
        for itemId in itemIds {
            if let idx = clipboard.history.firstIndex(where: { $0.id == itemId }) {
                clipboard.history[idx].folderId = folderId
                clipboard.history[idx].isPinned = false
            }
        }
        onComplete?()
        dismiss()
    }
    
    private func createNewFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        
        let newFolder = ClipboardFolder(name: name, orderIndex: clipboard.folders.count)
        clipboard.folders.append(newFolder)
        
        assignToFolder(newFolder.id)
    }
}

struct GroupAssignmentPayload: Identifiable {
    let id = UUID()
    let itemIds: Set<UUID>
    var onComplete: (() -> Void)? = nil
}

