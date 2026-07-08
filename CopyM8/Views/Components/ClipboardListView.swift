import SwiftUI

struct ClipboardListView: View {
    @EnvironmentObject var clipboard: ClipboardManager
    var filteredHistory: [ClipboardItem]
    var isDense: Bool
    @Binding var selectedIndex: Int
    @Binding var expandedItemIndex: Int?
    var activeColorName: String
    var activeColor: Color
    var isEditMode: Bool
    @Binding var selectedItemsForDeletion: Set<UUID>
    var pasteItem: (Int, Bool) -> Void
    
    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                LazyVStack(spacing: isDense ? 2 : 12) {
                    ForEach(Array(filteredHistory.enumerated()), id: \.element.id) { index, item in
                        ClipboardItemView(
                            index: index,
                            item: item,
                            isSelected: index == selectedIndex,
                            isExpanded: index == expandedItemIndex,
                            isDense: isDense,
                            activeColor: activeColorName == "Black" ? .primary : activeColor,
                            isEditMode: isEditMode,
                            isChecked: selectedItemsForDeletion.contains(item.id),
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
                        .contextMenu {
                            Button(item.isPinned ? "Unpin" : "Pin") { clipboard.togglePin(for: item.id) }
                            Button("Delete") { clipboard.history.removeAll { $0.id == item.id } }
                        }
                        .id(index)
                    }
                    .onMove { source, destination in
                        var items = clipboard.history
                        let sourceIndices = source.compactMap { idx -> Int? in
                            let id = filteredHistory[idx].id
                            return items.firstIndex(where: { $0.id == id })
                        }
                        
                        let destId: UUID? = destination < filteredHistory.count ? filteredHistory[destination].id : nil
                        let globalDestIndex = destId != nil ? items.firstIndex(where: { $0.id == destId! }) ?? items.endIndex : items.endIndex
                        
                        items.move(fromOffsets: IndexSet(sourceIndices), toOffset: globalDestIndex)
                        clipboard.history = items
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
