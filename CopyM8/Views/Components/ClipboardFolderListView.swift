import SwiftUI

struct ClipboardFolderListView: View {
    @EnvironmentObject var clipboard: ClipboardManager
    var folders: [ClipboardFolder]
    var isDense: Bool
    @Binding var selectedIndex: Int
    var activeColor: Color
    var isEditMode: Bool
    @Binding var selectedItemsForDeletion: Set<UUID>
    @Binding var selectedFolderId: UUID?
    @Binding var editingFolderId: UUID?
    
    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                LazyVStack(spacing: isDense ? 2 : 12) {
                    let standardFolders = clipboard.folders.filter { $0.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }
                    ForEach(Array(folders.enumerated()), id: \.element.id) { index, folder in
                        ClipboardFolderView(
                            folder: folder,
                            shortcutIndex: standardFolders.firstIndex(where: { $0.id == folder.id }),
                            isSelected: index == selectedIndex,
                            isDense: isDense,
                            activeColor: activeColor,
                            isEditMode: isEditMode,
                            isChecked: selectedItemsForDeletion.contains(folder.id),
                            editingFolderId: $editingFolderId,
                            onTap: {
                                if !isEditMode {
                                    withAnimation {
                                        selectedFolderId = folder.id
                                        selectedIndex = 0
                                    }
                                }
                            }
                        )
                        .id(index)
                    }

                }
                .padding(8)
                .onChange(of: selectedIndex) { _, newIndex in
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(newIndex, anchor: nil)
                    }
                }
            }
        }
    }
}
