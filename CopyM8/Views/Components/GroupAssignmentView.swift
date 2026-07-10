import SwiftUI

struct GroupAssignmentView: View {
    @EnvironmentObject var clipboard: ClipboardManager
    @Environment(\.dismiss) var dismiss
    let itemId: UUID
    
    @State private var newFolderName: String = ""
    @State private var isCreatingNew = false
    @FocusState private var isTextFieldFocused: Bool
    
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
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(.primary.opacity(0.6))
                                    Text(folder.name)
                                    Spacer()
                                }
                                .padding(8)
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
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
    }
    
    private func assignToFolder(_ folderId: UUID) {
        if let idx = clipboard.history.firstIndex(where: { $0.id == itemId }) {
            clipboard.history[idx].folderId = folderId
        }
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

