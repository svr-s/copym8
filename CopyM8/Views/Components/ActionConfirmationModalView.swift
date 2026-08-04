import SwiftUI

struct ModalOption: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let isDestructive: Bool
    let action: () -> Void
}

struct ActionConfirmationModalView: View {
    let title: String
    let message: String
    let options: [ModalOption]
    let onCancel: () -> Void
    var fixedWidth: CGFloat = 320
    
    @State private var selectedIndex: Int = 0
    @State private var localEventMonitor: Any?
    
    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .padding(.top, 4)
            
            Text(message)
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundColor(.primary.opacity(0.8))
                .padding(.horizontal, 8)
            
            VStack(spacing: 8) {
                ForEach(0..<options.count, id: \.self) { index in
                    Button(action: {
                        handleSelection(index)
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
                        .background(backgroundColor(for: index))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: fixedWidth)
        .onAppear {
            setupKeyboardMonitor()
        }
        .onDisappear {
            teardownKeyboardMonitor()
        }
    }
    
    private func backgroundColor(for index: Int) -> Color {
        if index == selectedIndex {
            if options[index].title == "Cancel" {
                return Color.primary.opacity(0.4)
            } else if options[index].isDestructive {
                return Color.red.opacity(0.8)
            } else {
                return Color.accentColor
            }
        }
        return Color.primary.opacity(0.05)
    }
    
    private func handleSelection(_ index: Int) {
        options[index].action()
    }
    
    private func setupKeyboardMonitor() {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 126: // Up
                if selectedIndex > 0 { selectedIndex -= 1 }
                else { selectedIndex = options.count - 1 }
                return nil
            case 125: // Down
                if selectedIndex < options.count - 1 { selectedIndex += 1 }
                else { selectedIndex = 0 }
                return nil
            case 36, 76: // Enter / Return
                handleSelection(selectedIndex)
                return nil
            case 53: // Esc
                onCancel()
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
