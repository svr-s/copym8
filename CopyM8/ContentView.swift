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

struct ContentView: View {
    @StateObject private var clipboard = ClipboardManager()
    @StateObject private var shortcut = ShortcutManager()
    @State private var isHovering = false
    @State private var showingClearAlert = false
    @State private var showingDeleteSelectedAlert = false
    @State private var showingEmptyToast = false
    @State private var expandedItemIndex: Int? = nil
    @State private var showingSettings = false
    @State private var draftHistoryCount: Int = 25
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    
    @State private var isEditMode: Bool = false
    @State private var selectedItemsForDeletion: Set<UUID> = []
    
    @State private var activeTab: String = "All"
    
    @AppStorage("activeColorName") private var activeColorName: String = "Glacier"
    @AppStorage("themePreference") private var themePreference: String = "System"
    @AppStorage("isDense") private var isDense: Bool = true
    @AppStorage("dockEdgeRaw") private var dockEdgeRaw: String = "right"
    @AppStorage("windowWidth") private var windowWidth: Double = 320
    @AppStorage("windowHeight") private var windowHeight: Double = 420
    @AppStorage("maxHistoryCount") private var maxHistoryCount: Int = 25
    
    private var dockEdge: DockEdge {
        switch dockEdgeRaw {
        case "left": return .left
        case "top": return .top
        default: return .right
        }
    }
    
    private var activeColor: Color {
        colors.first(where: { $0.name == activeColorName })?.color ?? .cyan
    }
    
    private var filteredHistory: [ClipboardItem] {
        var results = clipboard.history
        
        switch activeTab {
        case "Pinned": results = results.filter { $0.isPinned }
        case "Text": results = results.filter { $0.itemType == .text }
        case "Links": results = results.filter { $0.itemType == .link }
        case "Images": results = results.filter { $0.itemType == .image }
        case "Files": results = results.filter { $0.itemType == .file }
        default: break
        }
        
        if !searchText.isEmpty {
            results = results.filter { item in
                item.text.localizedCaseInsensitiveContains(searchText) ||
                (item.sourceApp?.localizedCaseInsensitiveContains(searchText) == true)
            }
        }
        return results
    }
    
    @State private var dragOffset: CGSize = .zero
    @State private var initialWindowPosition: NSPoint? = nil
    
    @State private var selectedIndex: Int = 0
    @State private var isResizing = false
    @State private var resizeStartMouse: NSPoint?
    @State private var resizeStartSize: NSSize?
    
    @State private var isHoveringClose = false
    
    private func cycleColor() {
        if let idx = colors.firstIndex(where: { $0.name == activeColorName }) {
            activeColorName = colors[(idx + 1) % colors.count].name
        }
    }
    
    var body: some View {
        ZStack {
            if shortcut.isExpanded {
                ExpandedView(
                    isHoveringClose: $isHoveringClose,
                    isEditMode: $isEditMode,
                    selectedItemsForDeletion: $selectedItemsForDeletion,
                    showingEmptyToast: $showingEmptyToast,
                    showingClearAlert: $showingClearAlert,
                    isDense: $isDense,
                    windowWidth: $windowWidth,
                    windowHeight: $windowHeight,
                    showingSettings: $showingSettings,
                    draftHistoryCount: $draftHistoryCount,
                    maxHistoryCount: $maxHistoryCount,
                    activeTab: $activeTab,
                    selectedIndex: $selectedIndex,
                    activeColor: activeColor,
                    searchText: $searchText,
                    isSearchFocused: $isSearchFocused,
                    filteredHistory: filteredHistory,
                    expandedItemIndex: $expandedItemIndex,
                    activeColorName: activeColorName,
                    showingDeleteSelectedAlert: $showingDeleteSelectedAlert,
                    isResizing: $isResizing,
                    resizeStartMouse: $resizeStartMouse,
                    resizeStartSize: $resizeStartSize,
                    adjustWindowFrame: { adjustWindowFrame(expanded: true, animate: false) },
                    snapToEdge: snapToEdge,
                    pasteItem: pasteItem
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                PillView(
                    dockEdge: dockEdge,
                    activeColorName: activeColorName,
                    activeColor: activeColor,
                    isHovering: $isHovering,
                    onExpanded: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            shortcut.isExpanded = true
                        }
                    },
                    snapToEdge: snapToEdge
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .background(Color.clear)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: shortcut.isExpanded)
        .onChange(of: shortcut.isExpanded) { _, expanded in
            adjustWindowFrame(expanded: expanded, animate: true)
            if expanded {
                previousApp = NSWorkspace.shared.frontmostApplication
                NSApp.activate()
                NSApp.windows.first?.makeKeyAndOrderFront(nil)
                searchText = ""
                setupKeyboardMonitor()
            } else {
                teardownKeyboardMonitor()
            }
        }
        .onChange(of: maxHistoryCount) { _, newValue in clipboard.truncateHistory(to: newValue) }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
            expandedItemIndex = nil
        }
        .onChange(of: themePreference) { _, newTheme in applyTheme(newTheme) }
        .onAppear { applyTheme(themePreference) }
        .environmentObject(clipboard)
    }
    
    private func applyTheme(_ theme: String) {
        if theme == "Light" { NSApp.appearance = NSAppearance(named: .aqua) }
        else if theme == "Dark" { NSApp.appearance = NSAppearance(named: .darkAqua) }
        else { NSApp.appearance = nil }
        
        for window in NSApp.windows {
            window.appearance = NSApp.appearance
            window.viewsNeedDisplay = true
        }
    }
    
    private func getDynamicWindowSize() -> CGSize {
        let calculatedHeight = windowHeight
        var finalWidth = max(340, windowWidth)
        var finalHeight = calculatedHeight
        if let screenRect = NSApp.windows.first?.screen?.visibleFrame {
            finalWidth = min(finalWidth, screenRect.width)
            finalHeight = min(finalHeight, screenRect.height)
        }
        return CGSize(width: finalWidth, height: finalHeight)
    }
    
    private func snapToEdge() {
        guard let window = NSApp.windows.first, let screen = window.screen else { return }
        let screenRect = screen.visibleFrame
        let windowRect = window.frame
        let center = NSPoint(x: windowRect.midX, y: windowRect.midY)
        
        let distLeft = center.x - screenRect.minX
        let distRight = screenRect.maxX - center.x
        let distTop = screenRect.maxY - center.y
        let minEdge = min(distLeft, distRight, distTop)
        
        var targetX = windowRect.origin.x
        var targetY = windowRect.origin.y
        
        if minEdge == distLeft { dockEdgeRaw = "left"; targetX = screenRect.minX }
        else if minEdge == distRight { dockEdgeRaw = "right"; targetX = screenRect.maxX - windowRect.width }
        else { dockEdgeRaw = "top"; targetY = screenRect.maxY - windowRect.height }
        
        if !shortcut.isExpanded {
            let isTop = dockEdgeRaw == "top"
            let width: CGFloat = isTop ? 40 : 28
            let height: CGFloat = isTop ? 28 : 40
            window.setContentSize(NSSize(width: width, height: height))
            if dockEdgeRaw == "left" { targetX = screenRect.minX }
            if dockEdgeRaw == "right" { targetX = screenRect.maxX - width }
            if dockEdgeRaw == "top" { targetY = screenRect.maxY - height }
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrameOrigin(NSPoint(x: targetX, y: targetY))
        }
    }
    
    private func adjustWindowFrame(expanded: Bool, animate: Bool = true) {
        guard let window = NSApp.windows.first else { return }
        let isTop = dockEdge == .top
        let pillWidth: CGFloat = isTop ? 40 : 28
        let pillHeight: CGFloat = isTop ? 28 : 40
        let newSize = expanded ? getDynamicWindowSize() : NSSize(width: pillWidth, height: pillHeight)
        var frame = window.frame
        let oldWidth = frame.width
        let oldHeight = frame.height
        
        switch dockEdge {
        case .right:
            frame.origin.x -= (newSize.width - oldWidth)
            frame.origin.y -= (newSize.height - oldHeight) / 2
        case .left:
            frame.origin.y -= (newSize.height - oldHeight) / 2
        case .top:
            frame.origin.x -= (newSize.width - oldWidth) / 2
            frame.origin.y -= (newSize.height - oldHeight)
        }
        frame.size = newSize
        
        if let screenRect = window.screen?.visibleFrame {
            frame.origin.x = max(screenRect.minX, min(frame.origin.x, screenRect.maxX - frame.width))
            frame.origin.y = max(screenRect.minY, min(frame.origin.y, screenRect.maxY - frame.height))
        }
        window.setFrame(frame, display: true, animate: animate)
    }
    
    @State private var eventMonitor: Any?
    @State private var previousApp: NSRunningApplication?
    
    private func setupKeyboardMonitor() {
        selectedIndex = 0
        expandedItemIndex = nil
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if showingSettings { return event }
            switch event.keyCode {
            case 53: // Esc
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { shortcut.isExpanded = false }
                return nil
            case 125: // Down arrow
                let maxIndex = max(0, self.filteredHistory.count - 1)
                self.selectedIndex = min(self.selectedIndex + 1, maxIndex)
                self.expandedItemIndex = nil
                return nil
            case 35: // P
                if self.isEditMode {
                    if !self.selectedItemsForDeletion.isEmpty {
                        for id in self.selectedItemsForDeletion { self.clipboard.togglePin(for: id) }
                        self.selectedItemsForDeletion.removeAll()
                        withAnimation { self.isEditMode = false }
                    }
                } else if self.selectedIndex >= 0 && self.selectedIndex < self.filteredHistory.count {
                    let id = self.filteredHistory[self.selectedIndex].id
                    self.clipboard.togglePin(for: id)
                }
                return nil
            case 126: // Up arrow
                self.selectedIndex = max(self.selectedIndex - 1, 0)
                self.expandedItemIndex = nil
                return nil
            case 36: // Enter
                let isCmd = event.modifierFlags.contains(.command)
                self.pasteItem(index: self.selectedIndex, isFormatted: isCmd)
                return nil
            case 124: // Right arrow
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    self.expandedItemIndex = (self.expandedItemIndex == self.selectedIndex) ? nil : self.selectedIndex
                }
                return nil
            case 123: // Left arrow
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    self.expandedItemIndex = (self.expandedItemIndex == self.selectedIndex) ? nil : self.selectedIndex
                }
                return nil
            case 49: // Space
                if self.isEditMode {
                    if self.selectedIndex >= 0 && self.selectedIndex < self.filteredHistory.count {
                        let id = self.filteredHistory[self.selectedIndex].id
                        if self.selectedItemsForDeletion.contains(id) { self.selectedItemsForDeletion.remove(id) }
                        else { self.selectedItemsForDeletion.insert(id) }
                    }
                    return nil
                }
                return event
            case 0: // A
                if event.modifierFlags.contains(.command) && self.isEditMode {
                    if self.selectedItemsForDeletion.count == self.filteredHistory.count {
                        self.selectedItemsForDeletion.removeAll()
                    } else {
                        self.selectedItemsForDeletion = Set(self.filteredHistory.map { $0.id })
                    }
                    return nil
                }
                return event
            default:
                if let chars = event.charactersIgnoringModifiers, let number = Int(chars) {
                    if event.modifierFlags.contains(.option) {
                        let tabs = ["All", "Pinned", "Text", "Links", "Images", "Files"]
                        let visibleTabs = tabs.filter { t in
                            switch t {
                            case "All", "Pinned": return true
                            case "Text": return UserDefaults.standard.object(forKey: "saveText") as? Bool ?? true
                            case "Links": return UserDefaults.standard.object(forKey: "saveLinks") as? Bool ?? true
                            case "Images": return UserDefaults.standard.object(forKey: "saveImages") as? Bool ?? true
                            case "Files": return UserDefaults.standard.object(forKey: "saveFiles") as? Bool ?? true
                            default: return false
                            }
                        }
                        if number >= 1 && number <= visibleTabs.count {
                            withAnimation {
                                self.activeTab = visibleTabs[number - 1]
                                self.selectedIndex = 0
                            }
                        }
                        return nil
                    }
                    
                    let isCmd = event.modifierFlags.contains(.command)
                    let targetIndex = number == 0 ? 9 : number - 1
                    self.pasteItem(index: targetIndex, isFormatted: isCmd)
                    return nil
                }
                return event
            }
        }
    }
    
    private func teardownKeyboardMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func pasteItem(index: Int, isFormatted: Bool = false) {
        if isEditMode { return }
        let history = self.filteredHistory
        guard index >= 0 && index < history.count else { return }
        let item = history[index]
        clipboard.prepareForPaste(item, isFormatted: isFormatted)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { shortcut.isExpanded = false }
        previousApp?.activate(options: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { clipboard.triggerPasteKeystroke() }
    }
}
