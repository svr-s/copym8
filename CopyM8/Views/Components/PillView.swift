import SwiftUI

/// `PillView` is the collapsed, minimalistic state of CopyM8 that docks to the edge of the screen.
/// It uses a NativeDragView overlay to allow repositioning along the edges and expands the app when clicked.
struct PillView: View {
    var dockEdge: DockEdge
    var activeColorName: String
    var activeColor: Color
    @Binding var isHovering: Bool
    var onExpanded: () -> Void
    var snapToEdge: () -> Void
    
    var body: some View {
        let isTop = dockEdge == .top
        let width: CGFloat = isTop ? 40 : 28
        let height: CGFloat = isTop ? 28 : 40
        let hoverLogoColor = activeColorName == "Black" ? Color.primary : activeColor
        let logoColor = isHovering ? hoverLogoColor : Color.primary.opacity(0.4)
        
        return RoundedRectangle(cornerRadius: 24)
            .fill(Color.clear)
            .background(VisualEffectView(material: .windowBackground, blendingMode: .behindWindow))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .frame(width: width, height: height)
            .overlay(
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(logoColor, lineWidth: 2.5)
                        .shadow(color: isHovering ? logoColor.opacity(0.5) : .clear, radius: 3, x: 0, y: 0)
                    
                    Image(systemName: "infinity")
                        .resizable().scaledToFit().font(Font.system(size: 10, weight: .medium))
                        .foregroundColor(logoColor).shadow(color: isHovering ? logoColor : .clear, radius: 4, x: 0, y: 0)
                        .opacity(isHovering ? 1.0 : 0.8)
                        .frame(width: 36, height: 16)
                        .rotationEffect(.degrees(isTop ? 0 : (dockEdge == .left ? -90 : 90)))
                }
            )
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            .overlay(
                NativeDragView(
                    onDragEnded: { snapToEdge() },
                    onTap: { onExpanded() }
                )
            )
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isHovering = hovering }
            }
            .contentShape(Rectangle())
    }
}
