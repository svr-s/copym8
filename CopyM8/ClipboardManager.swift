import Foundation
import AppKit

struct ClipboardItem: Identifiable, Equatable, Codable {
    var id = UUID()
    let text: String
    let timestamp: Date
}

class ClipboardManager: ObservableObject {
    @Published var history: [ClipboardItem] = [] {
        didSet {
            saveHistory()
        }
    }
    
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    private let storageKey = "copym8_clipboard_history"
    
    init() {
        loadHistory()
        lastChangeCount = pasteboard.changeCount
        startPolling()
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            self.history = decoded
        }
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    func clearAll() {
        history.removeAll()
    }
    
    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }
    
    private var ignoreNextChange = false
    
    private func checkForChanges() {
        let currentCount = pasteboard.changeCount
        if currentCount != lastChangeCount {
            lastChangeCount = currentCount
            if ignoreNextChange {
                ignoreNextChange = false
                return
            }
            if let newString = pasteboard.string(forType: .string) {
                // If it exists in history, move it to the top
                if let existingIndex = history.firstIndex(where: { $0.text == newString }) {
                    DispatchQueue.main.async {
                        let item = self.history.remove(at: existingIndex)
                        self.history.insert(item, at: 0)
                    }
                    return
                }
                
                let item = ClipboardItem(text: newString, timestamp: Date())
                
                DispatchQueue.main.async {
                    self.history.insert(item, at: 0)
                    if self.history.count > 50 {
                        self.history.removeLast()
                    }
                }
            }
        }
    }
    
    func pasteItem(_ item: ClipboardItem) {
        ignoreNextChange = true
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        
        // Use AppleScript to simulate Cmd+V in the previously active app
        let scriptSource = """
        tell application "System Events"
            keystroke "v" using command down
        end tell
        """
        if let script = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
        }
    }
}
