import SwiftUI

struct DeleteConfirmationView: View {
    @Environment(\.dismiss) var dismiss
    let isFolderDeletion: Bool
    let itemCount: Int
    var onConfirm: (Bool?) -> Void
    
    @State private var selectedIndex: Int = 0
    @State private var localEventMonitor: Any?
    
    var options: [(title: String, icon: String, isDestructive: Bool)] {
        if isFolderDeletion {
            return [
                (title: "Keep Items (Move to Pinned)", icon: "pin.fill", isDestructive: false),
                (title: "Delete All Permanently", icon: "trash.fill", isDestructive: true),
                (title: "Cancel", icon: "xmark", isDestructive: false)
            ]
        } else {
            return [
                (title: "Delete \(itemCount) Item\(itemCount == 1 ? "" : "s")", icon: "trash.fill", isDestructive: true),
                (title: "Cancel", icon: "xmark", isDestructive: false)
            ]
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text(isFolderDeletion ? "Delete selected folders?" : "Delete selected items?")
                .font(.system(size: 14, weight: .bold))
                .padding(.top, 4)
            
            Text(isFolderDeletion ? "Do you want to keep the items inside the folders (move to Pinned) or delete them permanently?" : "Are you sure you want to delete \(itemCount) items? This action cannot be undone.")
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
        .frame(width: 320)
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
        if options[index].title == "Cancel" {
            dismiss()
        } else if isFolderDeletion {
            // Index 0: Keep Items, Index 1: Delete All
            onConfirm(index == 0)
            dismiss()
        } else {
            // Index 0: Delete
            onConfirm(nil) // nil means normal deletion
            dismiss()
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
                handleSelection(selectedIndex)
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
