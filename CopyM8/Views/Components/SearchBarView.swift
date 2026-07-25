import SwiftUI

struct SearchBarView: View {
    @EnvironmentObject var clipboard: ClipboardManager
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
            
            if !clipboard.availableDevices.isEmpty {
                Divider().frame(height: 12)
                Picker("", selection: $clipboard.selectedDevice) {
                    Text("Local (This Mac)").tag("Local (This Mac)")
                    ForEach(clipboard.availableDevices, id: \.self) { device in
                        Text(device).tag(device)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .font(.system(size: 11))
                .frame(maxWidth: 120)
            }
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
