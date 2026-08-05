import SwiftUI
import AppKit

extension ContentView {
    /// Applies a specific visual theme (Light, Dark, or System) to the application.
    /// Overrides the `NSApp.appearance` globally and forces all windows to redraw.
    /// - Parameter theme: A string representing the desired theme ("Light", "Dark", or anything else for System default).
    func applyTheme(_ theme: String) {
        if theme == "Light" { NSApp.appearance = NSAppearance(named: .aqua) }
        else if theme == "Dark" { NSApp.appearance = NSAppearance(named: .darkAqua) }
        else { NSApp.appearance = nil }
        
        for window in NSApp.windows {
            window.appearance = NSApp.appearance
            window.viewsNeedDisplay = true
        }
    }

    /// Cycles the active accent color to the next available color in the predefined `colors` list.
    /// Wraps around to the beginning if the current color is the last one.
    func cycleColor() {
        if let idx = colors.firstIndex(where: { $0.name == activeColorName }) {
            activeColorName = colors[(idx + 1) % colors.count].name
        }
    }

    /// Determines which navigation tabs should be visible based on user preferences.
    /// Core tabs (All, Pinned, Groups) are always visible. Content-specific tabs are toggled based on Settings.
    /// - Returns: An array of strings representing the visible tab names.
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
