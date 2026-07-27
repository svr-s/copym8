import SwiftUI

struct GroupAssignmentView: View {
    @EnvironmentObject var clipboard: ClipboardManager
    let itemIds: Set<UUID>
    var onComplete: (() -> Void)? = nil
    var onCancel: () -> Void
    
    
    

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
                    ScrollViewReader { proxy in
                        VStack(spacing: 8) {
                            ForEach(Array(clipboard.folders.enumerated()), id: \.element.id) { index, folder in
                                let isCloud = folder.id == cloudFolderId
                                let letterIndex = isCloud ? 0 : index - (clipboard.folders.first?.id == cloudFolderId ? 1 : 0)
                                let letter = isCloud ? "`" : String(UnicodeScalar(UInt8(65 + letterIndex)))
                            Button(action: {
                                assignToFolder(folder.id)
                            }) {
                                HStack {
                                    Text(letter)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .frame(width: 16, alignment: .leading)
                                    if isCloud {
                                        Image(systemName: "cloud.fill")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 12, height: 12)
                                            .foregroundColor(.blue.opacity(0.8))
                                    } else {
                                        Image(nsImage: NSImage(named: NSImage.folderName)!)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 14, height: 14)
                                    }
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
                                .id(index)
                            }
                        }
                        .onChange(of: selectedIndex) { _, newIndex in
                            proxy.scrollTo(newIndex, anchor: nil)
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
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.automatic)
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
            if chars == "`" {
                if clipboard.folders.first?.id == cloudFolderId {
                    assignToFolder(cloudFolderId)
                    return nil
                }
            }

                let scalar = chars.unicodeScalars.first!.value
                if scalar >= 65 && scalar <= 90 { // A-Z
                    let index = Int(scalar - 65)
                    let standardFolders = clipboard.folders.filter { $0.id != cloudFolderId }
                    if index < standardFolders.count {
                        assignToFolder(standardFolders[index].id)
                        return nil
                    }
                }
            }
            
            switch event.keyCode {
            case 126: // Up
                if clipboard.folders.isEmpty { return nil }
                if selectedIndex > 0 { selectedIndex -= 1 }
                else { selectedIndex = clipboard.folders.count - 1 }
                return nil
            case 125: // Down
                if clipboard.folders.isEmpty { return nil }
                if selectedIndex < clipboard.folders.count - 1 { selectedIndex += 1 }
                else { selectedIndex = 0 }
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
        clipboard.setFolderId(for: Array(itemIds), folderId: folderId)
        onComplete?()
        onCancel()
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

