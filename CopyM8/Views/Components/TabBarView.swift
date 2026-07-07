import SwiftUI

struct TabBarView: View {
    @Binding var activeTab: String
    @Binding var selectedIndex: Int
    @AppStorage("activeColorName") var activeColorName: String = "Glacier"
    
    var activeColor: Color
    
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(["All", "Pinned", "Text", "Links", "Images", "Files"], id: \.self) { tab in
                    if shouldShowTab(tab) {
                        Button(action: {
                            withAnimation {
                                activeTab = tab
                                selectedIndex = 0
                            }
                        }) {
                            let isBlack = activeColorName == "Black"
                            let isActive = activeTab == tab
                            
                            Text(tab)
                                .font(.system(size: 11, weight: isActive ? .bold : .regular))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .foregroundColor(isActive ? .primary : .primary.opacity(0.6))
                                .background(
                                    isActive 
                                    ? (isBlack ? Color.primary.opacity(0.2) : activeColor.opacity(0.15)) 
                                    : Color.primary.opacity(0.05)
                                )
                                .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hover in if hover { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                    }
                }
            }
            .padding(.horizontal, 12).padding(.bottom, 8)
        }
    }
    
    private func shouldShowTab(_ tab: String) -> Bool {
        switch tab {
        case "All", "Pinned": return true
        case "Text": return UserDefaults.standard.object(forKey: "saveText") as? Bool ?? true
        case "Links": return UserDefaults.standard.object(forKey: "saveLinks") as? Bool ?? true
        case "Images": return UserDefaults.standard.object(forKey: "saveImages") as? Bool ?? true
        case "Files": return UserDefaults.standard.object(forKey: "saveFiles") as? Bool ?? true
        default: return false
        }
    }
}
