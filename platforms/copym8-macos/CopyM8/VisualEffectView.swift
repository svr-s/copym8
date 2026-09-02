import SwiftUI

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    @AppStorage("themePreference") private var themePreference: String = "System"
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active // Force active state for non-activating panel
        
        applyAppearance(to: visualEffectView)
        return visualEffectView
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        applyAppearance(to: nsView)
    }
    
    private func applyAppearance(to nsView: NSVisualEffectView) {
        if themePreference == "Light" {
            nsView.appearance = NSAppearance(named: .aqua)
        } else if themePreference == "Dark" {
            nsView.appearance = NSAppearance(named: .darkAqua)
        } else {
            nsView.appearance = nil
            // Force redraw when returning to system
            nsView.setNeedsDisplay(nsView.bounds)
        }
    }
}
