import SwiftUI

struct UngroupConfirmationView: View {
    @Environment(\.dismiss) var dismiss
    var onConfirm: (Bool) -> Void
    
    @State private var selectedIndex: Int = 0
    @State private var localEventMonitor: Any?
    
    let options = [
        (title: "Move to Pinned", icon: "pin.fill"),
        (title: "Completely Ungroup", icon: "folder.badge.minus")
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Ungroup selected items?")
                .font(.system(size: 14, weight: .bold))
                .padding(.top, 4)
            
            Text("Do you want to keep these items in your Pinned list, or completely ungroup them?")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundColor(.primary.opacity(0.8))
                .padding(.horizontal, 8)
            
            VStack(spacing: 8) {
                ForEach(0..<options.count, id: \.self) { index in
                    Button(action: {
                        onConfirm(index == 0)
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: options[index].icon)
                                .foregroundColor(index == selectedIndex ? .white : .primary.opacity(0.8))
                            Text(options[index].title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(index == selectedIndex ? .white : .primary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(index == selectedIndex ? Color.accentColor : Color.primary.opacity(0.05))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.top, 8)
            
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(PlainButtonStyle())
            .font(.system(size: 12))
            .foregroundColor(.primary.opacity(0.6))
            .padding(.top, 4)
        }
        .padding(20)
        .frame(width: 300)
        .onAppear {
            setupKeyboardMonitor()
        }
        .onDisappear {
            teardownKeyboardMonitor()
        }
    }
    
    private func setupKeyboardMonitor() {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 126: // Up
                if selectedIndex > 0 { selectedIndex -= 1 }
                return nil
            case 125: // Down
                if selectedIndex < options.count - 1 { selectedIndex += 1 }
                return nil
            case 36, 76: // Enter / Return
                onConfirm(selectedIndex == 0)
                dismiss()
                return nil
            case 53: // Esc
                dismiss()
                return nil
            default:
                break
            }
            return event
        }
    }
    
    private func teardownKeyboardMonitor() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }
}
