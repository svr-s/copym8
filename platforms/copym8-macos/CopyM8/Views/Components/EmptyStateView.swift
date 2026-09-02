import SwiftUI

struct EmptyStateView: View {
    var searchText: String
    var activeTab: String
    
    private var emptyStateMessage: String {
        if !searchText.isEmpty { return "No results found." }
        else if activeTab == "Pinned" { return "You don't have any pinned items.\nPin important items to keep them here!" }
        else { return "Your clipboard is empty.\nStart copying to see items here!" }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clipboard").font(.system(size: 32)).foregroundColor(.primary.opacity(0.3))
            Text(emptyStateMessage)
                .font(.system(size: 12)).foregroundColor(.primary.opacity(0.5)).multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
