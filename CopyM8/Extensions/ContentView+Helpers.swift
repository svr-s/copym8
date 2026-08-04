import SwiftUI
import AppKit

extension ContentView {
    func applyTheme(_ theme: String) {
        if theme == "Light" { NSApp.appearance = NSAppearance(named: .aqua) }
        else if theme == "Dark" { NSApp.appearance = NSAppearance(named: .darkAqua) }
        else { NSApp.appearance = nil }
        
        for window in NSApp.windows {
            window.appearance = NSApp.appearance
            window.viewsNeedDisplay = true
        }
    }

    func cycleColor() {
        if let idx = colors.firstIndex(where: { $0.name == activeColorName }) {
            activeColorName = colors[(idx + 1) % colors.count].name
        }
    }

    func getVisibleTabs() -> [String] {
        let tabs = ["All", "Pinned", "Groups", "Text", "Links", "Images", "Files"]
        return tabs.filter { t in
            switch t {
            case "All", "Pinned", "Groups": return true
            case "Text": return UserDefaults.standard.object(forKey: "saveText") as? Bool ?? true
            case "Links": return UserDefaults.standard.object(forKey: "saveLinks") as? Bool ?? true
            case "Images": return UserDefaults.standard.object(forKey: "saveImages") as? Bool ?? true
            case "Files": return UserDefaults.standard.object(forKey: "saveFiles") as? Bool ?? true
            default: return false
            }
        }
    }

}
