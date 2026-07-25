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
    
    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                LazyVStack(spacing: isDense ? 2 : 12) {
                    ForEach(Array(folders.enumerated()), id: \.element.id) { index, folder in
                        ClipboardFolderView(
                            folder: folder,
                            shortcutIndex: index,
                            isSelected: index == selectedIndex,
                            isDense: isDense,
                            activeColor: activeColor,
                            isEditMode: isEditMode,
                            isChecked: selectedItemsForDeletion.contains(folder.id),
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
