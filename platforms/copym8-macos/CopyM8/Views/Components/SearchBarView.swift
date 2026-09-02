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
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.primary.opacity(0.5)).font(.system(size: 12))
                }.buttonStyle(PlainButtonStyle())
            }
            
            if !clipboard.availableDevices.isEmpty {
                Divider().frame(height: 12)
                
                let localName = UserDefaults.standard.string(forKey: "syncDeviceName") ?? "Local"
                let displayName = localName.isEmpty ? "Local" : "\(localName) (Local)"
                
                Picker("", selection: $clipboard.selectedDevice) {
                    Text(displayName).tag("Local (This Mac)")
                    ForEach(clipboard.availableDevices, id: \.self) { device in
                        Text(device).tag(device)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .font(.system(size: 11))
                .frame(maxWidth: 140)
            }
        }
        .padding(8).background(Color.primary.opacity(0.05)).cornerRadius(8)
        .padding(.horizontal, 10).padding(.bottom, 4)
    }
}
