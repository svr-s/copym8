import SwiftUI

struct DeviceSwitcherView: View {
    let devices: [String]
    let currentDevice: String
    let onSelect: (String) -> Void
    let onCancel: () -> Void
    
    @State private var selectedIndex: Int = 0
    @Environment(\.controlActiveState) private var controlActiveState
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Select Device Source")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.primary.opacity(0.05))
            
            Divider()
            
            VStack(spacing: 4) {
                ForEach(Array(devices.enumerated()), id: \.element) { index, device in
                    HStack {
                        Text(device)
                            .font(.system(size: 13, weight: index == selectedIndex ? .semibold : .regular))
                            .foregroundColor(index == selectedIndex ? .white : .primary)
                        Spacer()
                        if device == currentDevice {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(index == selectedIndex ? .white : .primary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        index == selectedIndex 
                        ? (controlActiveState == .key ? Color(nsColor: .selectedContentBackgroundColor) : Color(nsColor: .unemphasizedSelectedContentBackgroundColor)) 
                        : Color.clear
                    )
                    .cornerRadius(6)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect(device)
                    }
                }
            }
            .padding(8)
        }
        .onCustomKeyPress { event in
            switch event.keyCode {
            case 125: // Down arrow
                if selectedIndex < devices.count - 1 {
                    selectedIndex += 1
                } else { selectedIndex = 0 }
                return nil
            case 126: // Up arrow
                if selectedIndex > 0 {
                    selectedIndex -= 1
                } else { selectedIndex = devices.count - 1 }
                return nil
            case 36: // Enter
                onSelect(devices[selectedIndex])
                return nil
            case 53: // Esc
                onCancel()
                return nil
            default:
                if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) { return event }
                return nil
            }
        }
        .onAppear {
            if let idx = devices.firstIndex(of: currentDevice) {
                selectedIndex = idx
            }
        }
    }
}
