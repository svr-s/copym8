import SwiftUI

struct TabBarView: View {
    @Binding var activeTab: String
    @Binding var selectedIndex: Int
    @AppStorage("activeColorName") var activeColorName: String = "Glacier"
    
    var activeColor: Color
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { proxy in
                HStack(spacing: 6) {
                    ForEach(["All", "Pinned", "Groups", "Text", "Links", "Images", "Files"], id: \.self) { tab in
                        if shouldShowTab(tab) {
                            Button(action: {
                                withAnimation {
                                    activeTab = tab
                                    selectedIndex = 0
                                }
                            }) {
                                let isActive = activeTab == tab
                                
                                Text(tab)
                                    .font(.system(size: 11, weight: isActive ? .bold : .regular))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .foregroundColor(isActive ? .primary : .primary.opacity(0.6))
                                    .background(
                                        isActive 
                                        ? Color.primary.opacity(0.15) 
                                        : Color.primary.opacity(0.05)
                                    )
                                    .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .id(tab)
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 8)
                .onChange(of: activeTab) { _, newTab in
                    withAnimation {
                        proxy.scrollTo(newTab, anchor: .center)
                    }
                }
            }
        }
    }
    
    private func shouldShowTab(_ tab: String) -> Bool {
        switch tab {
        case "All", "Pinned", "Groups": return true
        case "Text": return UserDefaults.standard.object(forKey: "saveText") as? Bool ?? true
        case "Links": return UserDefaults.standard.object(forKey: "saveLinks") as? Bool ?? true
        case "Images": return UserDefaults.standard.object(forKey: "saveImages") as? Bool ?? true
        case "Files": return UserDefaults.standard.object(forKey: "saveFiles") as? Bool ?? true
        default: return false
        }
    }
}
