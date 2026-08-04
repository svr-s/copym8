import SwiftUI

import AppKit



enum DockEdge {
    case left, right, top
}

let colors: [(name: String, color: Color)] = [
    ("Ocean", Color(red: 0.2, green: 0.6, blue: 0.8)),
    ("Peach", Color(red: 0.9, green: 0.6, blue: 0.5)),
    ("Lavender", Color(red: 0.7, green: 0.5, blue: 0.8)),
    ("Mint", Color(red: 0.4, green: 0.8, blue: 0.6)),
    ("Lemon", Color(red: 0.9, green: 0.8, blue: 0.4)),
    ("Bubblegum", Color(red: 0.9, green: 0.4, blue: 0.6)),
    ("White", Color.primary),
    ("Grey", Color.gray),
    ("Black", Color.black)
]



struct DisplayNode: Identifiable {
    let id: String
    let isFolder: Bool
    let folder: ClipboardFolder?
    let item: ClipboardItem?
    let parentFolderId: UUID?
    var isDivider: Bool = false
}

enum ReorderTarget: Equatable {
    case pinned
    case folders
    case items(folderId: UUID)
}

struct ContentView: View {
    @StateObject var viewModel = ContentViewModel()
    @StateObject var clipboard = ClipboardManager()
    @StateObject var shortcut = ShortcutManager()
    @FocusState var isSearchFocused: Bool
    
    
    @FocusState var isFreezeFieldFocused: Bool
    
    
    @AppStorage("activeColorName") var activeColorName: String = "Glacier"
    @AppStorage("themePreference") var themePreference: String = "System"
    @AppStorage("isDense") var isDense: Bool = true
    @AppStorage("dockEdgeRaw") var dockEdgeRaw: String = "right"
    @AppStorage("windowWidth") var windowWidth: Double = 320
    @AppStorage("windowHeight") var windowHeight: Double = 420
    @AppStorage("maxHistoryCount") var maxHistoryCount: Int = 25
    
    var dockEdge: DockEdge {
        switch dockEdgeRaw {
        case "left": return .left
        case "top": return .top
        default: return .right
        }
    }
    
    var activeColor: Color {
        colors.first(where: { $0.name == activeColorName })?.color ?? .cyan
    }
    
    
    // private var displayNodes: [DisplayNode] { extracted to ContentView+DisplayNodes.swift
    
    @State var dragOffset: CGSize = .zero
    @State var initialWindowPosition: NSPoint? = nil
    
    @State var isResizing = false
    @State var resizeStartMouse: NSPoint?
    @State var resizeStartSize: NSSize?
    
    @State var isHoveringClose = false
    
    // private func cycleColor extracted to ContentView+Helpers.swift
    
    @ViewBuilder
    private var modalsOverlay: some View {
        Group {
            if let payload = viewModel.itemToAssignGroup {
                ZStack {
                    Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
                        .onTapGesture { viewModel.itemToAssignGroup = nil }
                    GroupAssignmentView(
                        itemIds: payload.itemIds, 
                        onComplete: payload.onComplete,
                        onCancel: { viewModel.itemToAssignGroup = nil }
                    )
                        .environmentObject(clipboard)
                        .frame(width: 280)
                        .padding(20)
                        .background(Color(NSColor.windowBackgroundColor))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 8)
                }
            } else if viewModel.showingUngroupAlert {
                ZStack {
                    Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
                        .onTapGesture { viewModel.showingUngroupAlert = false }
                    ActionConfirmationModalView(
                        title: "Ungroup selected items?",
                        message: "Do you want to keep these items in your Pinned list, or completely ungroup them?",
                        options: [
                            ModalOption(title: "Move to Pinned", icon: "pin.fill", isDestructive: false, action: { ungroupSelectedItems(pin: true); viewModel.showingUngroupAlert = false }),
                            ModalOption(title: "Completely Ungroup", icon: "folder.badge.minus", isDestructive: false, action: { 
                                ungroupSelectedItems(pin: false)
                                viewModel.showingUngroupAlert = false 
                                if !viewModel.isEditMode { viewModel.selectedItemsForDeletion.removeAll() }
                            }),
                            ModalOption(title: "Cancel", icon: "xmark", isDestructive: false, action: { 
                                viewModel.showingUngroupAlert = false 
                                if !viewModel.isEditMode { viewModel.selectedItemsForDeletion.removeAll() }
                            })
                        ],
                        onCancel: { 
                            viewModel.showingUngroupAlert = false 
                            if !viewModel.isEditMode { viewModel.selectedItemsForDeletion.removeAll() }
                        }
                    )
                        .frame(width: 280)
                        .padding(20)
                        .background(Color(NSColor.windowBackgroundColor))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 8)
                }
            } else if viewModel.showingDeviceSwitcher {
                ZStack {
                    Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
                        .onTapGesture { viewModel.showingDeviceSwitcher = false }
                    
                    let devices = ["Local (This Mac)"] + clipboard.availableDevices.filter { $0 != "Local (This Mac)" }
                    DeviceSwitcherView(
                        devices: devices,
                        currentDevice: clipboard.selectedDevice,
                        onSelect: { selected in
                            clipboard.selectedDevice = selected
                            if selected != "Local (This Mac)" && viewModel.activeTab == "Trash" {
                                viewModel.activeTab = viewModel.previousTab == "Trash" ? "All" : viewModel.previousTab
                            }
                            viewModel.showingDeviceSwitcher = false
                        },
                        onCancel: { viewModel.showingDeviceSwitcher = false }
                    )
                        .frame(width: 280)
                        .background(Color(NSColor.windowBackgroundColor))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 8)
                }
            } else if viewModel.showingEmptyTrashAlert {
                ZStack {
                    Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
                        .onTapGesture { viewModel.showingEmptyTrashAlert = false }
                    let trashCount = clipboard.history.filter { ($0.isDeleted ?? false) }.count
                    ActionConfirmationModalView(
                        title: "Delete selected items?",
                        message: "Are you sure you want to delete \(trashCount) items? This action cannot be undone.",
                        options: [
                            ModalOption(title: "Delete \(trashCount) Item\(trashCount == 1 ? "" : "s")", icon: "trash.fill", isDestructive: true, action: {
                                clipboard.deleteItems(where: { ($0.isDeleted ?? false) }, hardDelete: true)
                                viewModel.showingEmptyTrashAlert = false
                            }),
                            ModalOption(title: "Cancel", icon: "xmark", isDestructive: false, action: { viewModel.showingEmptyTrashAlert = false })
                        ],
                        onCancel: { viewModel.showingEmptyTrashAlert = false }
                    )
                    .frame(width: 280)
                    .padding(20)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 8)
                }
            } else if viewModel.showingDeleteSelectedAlert {
                ZStack {
                    Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
                        .onTapGesture { viewModel.showingDeleteSelectedAlert = false }
                    let count = viewModel.selectedItemsForDeletion.count
                    ActionConfirmationModalView(
                        title: "Delete selected items?",
                        message: "Are you sure you want to delete \(count) items? This action cannot be undone.",
                        options: [
                            ModalOption(title: "Delete \(count) Item\(count == 1 ? "" : "s")", icon: "trash.fill", isDestructive: true, action: { 
                                deleteSelectedItems()
                                viewModel.showingDeleteSelectedAlert = false 
                                if !viewModel.isEditMode { viewModel.selectedItemsForDeletion.removeAll() }
                            }),
                            ModalOption(title: "Cancel", icon: "xmark", isDestructive: false, action: { 
                                viewModel.showingDeleteSelectedAlert = false 
                                if !viewModel.isEditMode { viewModel.selectedItemsForDeletion.removeAll() }
                            })
                        ],
                        onCancel: { 
                            viewModel.showingDeleteSelectedAlert = false 
                            if !viewModel.isEditMode { viewModel.selectedItemsForDeletion.removeAll() }
                        }
                    )
                    .frame(width: 280)
                    .padding(20)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 8)
                }
            } else if viewModel.showingFolderDeleteAlert {
                ZStack {
                    Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
                        .onTapGesture { viewModel.showingFolderDeleteAlert = false }
                    let folderIds = viewModel.selectedItemsForDeletion.filter { id in clipboard.folders.contains(where: { $0.id == id }) }
                    ActionConfirmationModalView(
                        title: "Delete selected folders?",
                        message: "Do you want to keep the items inside the folders (move to Pinned) or delete them permanently?",
                        options: [
                            ModalOption(title: "Keep Items (Move to Pinned)", icon: "pin.fill", isDestructive: false, action: { deleteFolders(keepItems: true); viewModel.showingFolderDeleteAlert = false }),
                            ModalOption(title: "Delete All Permanently", icon: "trash.fill", isDestructive: true, action: { 
                                deleteFolders(keepItems: false)
                                viewModel.showingFolderDeleteAlert = false 
                                if !viewModel.isEditMode { viewModel.selectedItemsForDeletion.removeAll() }
                            }),
                            ModalOption(title: "Cancel", icon: "xmark", isDestructive: false, action: { 
                                viewModel.showingFolderDeleteAlert = false 
                                if !viewModel.isEditMode { viewModel.selectedItemsForDeletion.removeAll() }
                            })
                        ],
                        onCancel: { 
                            viewModel.showingFolderDeleteAlert = false 
                            if !viewModel.isEditMode { viewModel.selectedItemsForDeletion.removeAll() }
                        }
                    )
                    .frame(width: 280)
                    .padding(20)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 8)
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            if shortcut.isExpanded {
                ExpandedView(
                    isHoveringClose: $isHoveringClose,
                    isEditMode: $viewModel.isEditMode,
                    selectedItemsForDeletion: $viewModel.selectedItemsForDeletion,
                    isDense: $isDense,
                    windowWidth: $windowWidth,
                    windowHeight: $windowHeight,
                    draftHistoryCount: $viewModel.draftHistoryCount,
                    maxHistoryCount: $maxHistoryCount,
                    activeTab: $viewModel.activeTab,
                    previousTab: $viewModel.previousTab,
                    showingEmptyTrashAlert: $viewModel.showingEmptyTrashAlert,
                    isReorderMode: $viewModel.isReorderMode,
                    reorderTarget: $viewModel.reorderTarget,
                    reorderFreezeLimit: $viewModel.reorderFreezeLimit,
                    reorderBackupHistory: $viewModel.reorderBackupHistory,
                    reorderBackupFolders: $viewModel.reorderBackupFolders,
                    isFreezeFieldFocused: $isFreezeFieldFocused,
                    selectedIndex: $viewModel.selectedIndex,
                    selectionAnchorIndex: $viewModel.selectionAnchorIndex,
                    activeColor: activeColor,
                    searchText: $viewModel.searchText,
                    isSearchFocused: $isSearchFocused,
                    displayNodes: displayNodes,
                    expandedFolderIds: $viewModel.expandedFolderIds,
                    expandedItemIndex: $viewModel.expandedItemIndex,
                    editingFolderId: $viewModel.editingFolderId,
                    activeColorName: activeColorName,
                    showingDeleteSelectedAlert: $viewModel.showingDeleteSelectedAlert,
                    showingFolderDeleteAlert: $viewModel.showingFolderDeleteAlert,
                    showingUngroupAlert: $viewModel.showingUngroupAlert,
                    itemToAssignGroup: $viewModel.itemToAssignGroup,
                    isResizing: $isResizing,
                    resizeStartMouse: $resizeStartMouse,
                    resizeStartSize: $resizeStartSize,
                    adjustWindowFrame: { adjustWindowFrame(expanded: true, animate: false) },
                    snapToEdge: snapToEdge,
                    pasteItem: pasteItem
                )
                .frame(width: windowWidth, height: windowHeight)
                .transition(.asymmetric(insertion: .opacity, removal: .opacity.animation(.easeOut(duration: 0.1))))
            } else {
                PillView(
                    dockEdge: dockEdge,
                    activeColorName: activeColorName,
                    activeColor: activeColor,
                    isHovering: $viewModel.isHovering,
                    onExpanded: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            shortcut.isExpanded = true
                        }
                    },
                    snapToEdge: snapToEdge
                )
                .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: shortcut.isExpanded ? 12 : 24))
        .background(Color.clear)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: shortcut.isExpanded)
        .onChange(of: shortcut.isExpanded) { _, expanded in
            adjustWindowFrame(expanded: expanded, animate: true)
            if expanded {
                previousApp = NSWorkspace.shared.frontmostApplication
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first(where: { $0 is CopyM8Window })?.makeKeyAndOrderFront(nil)
                viewModel.searchText = ""
                viewModel.activeTab = "All"
                viewModel.selectedIndex = 0
                viewModel.selectionAnchorIndex = nil
                viewModel.expandedItemIndex = nil
                // Keyboard monitor setup removed
            } else {
                // Keyboard monitor teardown removed
                if viewModel.isReorderMode {
                    clipboard.history = viewModel.reorderBackupHistory
                    clipboard.folders = viewModel.reorderBackupFolders
                    clipboard.isReordering = false
                    viewModel.isReorderMode = false
                    viewModel.reorderTarget = .none
                    viewModel.activeTab = "All"
                }
                viewModel.itemToAssignGroup = nil
                viewModel.showingDeviceSwitcher = false
                viewModel.showingDeleteSelectedAlert = false
                viewModel.showingFolderDeleteAlert = false
                viewModel.expandedFolderIds.removeAll()
                viewModel.isEditMode = false
                viewModel.selectedItemsForDeletion.removeAll()
            }
        }
        .onCustomKeyPress(handleKeyPress)
        .onChange(of: viewModel.activeTab) { _, _ in 
            viewModel.selectedItemsForDeletion.removeAll()
            viewModel.selectionAnchorIndex = nil
            viewModel.selectedIndex = 0
            viewModel.expandedItemIndex = nil
        }
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.selectedIndex = 0
            viewModel.selectionAnchorIndex = nil
            viewModel.expandedItemIndex = nil
        }
        .onChange(of: maxHistoryCount) { _, newValue in clipboard.truncateHistory(to: newValue) }
        .onChange(of: themePreference) { _, newTheme in applyTheme(newTheme) }
        .onChange(of: viewModel.isEditMode) { _, editMode in 
            viewModel.selectedItemsForDeletion.removeAll() 
            viewModel.selectionAnchorIndex = nil
            if viewModel.activeTab == "Groups" {
                if editMode {
                    viewModel.expandedFolderIds = Set(clipboard.folders.map { $0.id })
                    viewModel.expandedFolderIds.insert(cloudFolderId)
                    viewModel.expandedFolderIds.insert(restoredFolderId)
                } else {
                    viewModel.expandedFolderIds.removeAll()
                }
            }
        }
        .onChange(of: shortcut.requestedTab) { _, newTab in
            if let newTab = newTab {
                viewModel.activeTab = newTab
                shortcut.requestedTab = nil
            }
        }
        .onAppear { applyTheme(themePreference) }
        .environmentObject(clipboard)
        .environmentObject(shortcut)
        .overlay(modalsOverlay)
        .overlay(
            Group {
                if viewModel.showingReadOnlyToast {
                    VStack {
                        Spacer()
                        Text("Action disabled while viewing a remote source")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                            .padding(.bottom, 24)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                } else if viewModel.showingImportSuccessToast {
                    VStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text(viewModel.importSuccessMessage)
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ImportSuccessful"))) { notif in
            if let msg = notif.object as? String {
                viewModel.importSuccessMessage = msg
            } else {
                viewModel.importSuccessMessage = "Import successful"
            }
            if !viewModel.showingImportSuccessToast {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.showingImportSuccessToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.showingImportSuccessToast = false
                    }
                }
            }
        }
        .onChange(of: clipboard.selectedDevice) { _, _ in
            viewModel.selectedIndex = 0
            viewModel.selectionAnchorIndex = nil
            viewModel.expandedItemIndex = nil
        }
    }
    
    // private func ungroupSelectedItems extracted to ContentView+Actions.swift
    
    // private func applyTheme extracted to ContentView+Helpers.swift
    
    // private func getDynamicWindowSize extracted to ContentView+Window.swift
    
    // private func snapToEdge extracted to ContentView+Window.swift
    
    // private func adjustWindowFrame extracted to ContentView+Window.swift
    
    // Keyboard monitor replaced with onCustomKeyPress modifier
    @State var previousApp: NSRunningApplication?
    

    
    // private func pasteItem extracted to ContentView+Actions.swift
    
    // private func getVisibleTabs extracted to ContentView+Helpers.swift
    
    // private func moveSelectedItem extracted to ContentView+Actions.swift
    
    // private func moveSelectedFolder extracted to ContentView+Actions.swift
    
    // private func deleteSelectedItems extracted to ContentView+Actions.swift
    
    // private func deleteFolders extracted to ContentView+Actions.swift
}



extension ContentView {
    // private func handleKeyPress extracted to ContentView+Keyboard.swift
    }

// DeviceSwitcherView extracted to Views/Components/DeviceSwitcherView.swift
