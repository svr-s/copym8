import SwiftUI

struct ClipboardListView: View {
    @EnvironmentObject var clipboard: ClipboardManager
    var displayNodes: [DisplayNode]
    var isDense: Bool
    @Binding var selectedIndex: Int
    @Binding var expandedItemIndex: Int?
    var activeColorName: String
    var activeColor: Color
    var isEditMode: Bool
    @Binding var selectedItemsForDeletion: Set<UUID>
    @Binding var expandedFolderIds: Set<UUID>
    var activeTab: String
    var pasteItem: (Int, Bool) -> Void
    
    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                LazyVStack(spacing: isDense ? 2 : 12) {
                    ForEach(Array(displayNodes.enumerated()), id: \.element.id) { index, node in
                        if node.isFolder, let folder = node.folder {
                            ClipboardFolderView(
                                index: index,
                                folder: folder,
                                isSelected: index == selectedIndex,
                                isDense: isDense,
                                activeColor: activeColor,
                                isEditMode: isEditMode,
                                isChecked: selectedItemsForDeletion.contains(folder.id),
                                onTap: {
                                    if isEditMode {
                                        if selectedItemsForDeletion.contains(folder.id) { selectedItemsForDeletion.remove(folder.id) }
                                        else { selectedItemsForDeletion.insert(folder.id) }
                                    } else {
                                        withAnimation {
                                            if expandedFolderIds.contains(folder.id) {
                                                expandedFolderIds.remove(folder.id)
                                            } else {
                                                expandedFolderIds.insert(folder.id)
                                            }
                                            selectedIndex = index
                                        }
                                    }
                                },
                                isExpanded: expandedFolderIds.contains(folder.id)
                            )
                            .id(node.id)
                        } else if let item = node.item {
                            HStack {
                                if node.parentFolderId != nil {
                                    Spacer().frame(width: 24) // Indent items inside folders
                                }
                                ClipboardItemView(
                                    index: index,
                                    item: item,
                                    isSelected: index == selectedIndex,
                                    isExpanded: index == expandedItemIndex,
                                    isDense: isDense,
                                    activeColor: activeColorName == "Black" ? .primary : activeColor,
                                    isEditMode: isEditMode,
                                    isChecked: selectedItemsForDeletion.contains(item.id),
                                    folderIdentifier: (activeTab != "Groups" && item.folderId != nil) ? clipboard.folders.first(where: { $0.id == item.folderId })?.name.prefix(1).uppercased() : nil,
                                    onPaste: {
                                        if isEditMode {
                                            if selectedItemsForDeletion.contains(item.id) { selectedItemsForDeletion.remove(item.id) }
                                            else { selectedItemsForDeletion.insert(item.id) }
                                        } else {
                                            let isCmd = NSEvent.modifierFlags.contains(.command)
                                            pasteItem(index, isCmd)
                                        }
                                    },
                                    onExpandToggle: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            if expandedItemIndex == index { expandedItemIndex = nil }
                                            else { expandedItemIndex = index }
                                        }
                                    }
                                )
                            }
                            .contextMenu {
                                Button(item.isPinned ? "Unpin" : "Pin") { clipboard.togglePin(for: item.id) }
                                Button("Delete") { clipboard.history.removeAll { $0.id == item.id } }
                            }
                            .id(node.id)
                        }
                    }
                    .onMove { source, destination in
                        // Reordering mixed arrays requires more advanced index mapping, skipping for now
                    }
                }
                .padding(8)
                .onChange(of: selectedIndex) { _, newIndex in
                    if newIndex >= 0 && newIndex < displayNodes.count {
                        let targetId = displayNodes[newIndex].id
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(targetId, anchor: nil)
                        }
                    }
                }
            }
        }
    }
}
