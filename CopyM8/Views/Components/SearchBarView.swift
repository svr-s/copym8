import SwiftUI

struct SearchBarView: View {
    @Binding var searchText: String
    var isSearchFocused: FocusState<Bool>.Binding
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.primary.opacity(0.5)).font(.system(size: 12))
            TextField("Search copied items or source apps...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(.primary)
                .focused(isSearchFocused)
                .font(.system(size: 12))
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.primary.opacity(0.5)).font(.system(size: 12))
                }.buttonStyle(PlainButtonStyle())
            }
        }
        .padding(8).background(Color.primary.opacity(0.05)).cornerRadius(8)
        .padding(.horizontal, 10).padding(.bottom, 4)
    }
}
