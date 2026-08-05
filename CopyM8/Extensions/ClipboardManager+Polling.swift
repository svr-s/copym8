import Foundation
import AppKit

extension ClipboardManager {
    /// Starts the pasteboard polling timer.
    /// Fires every 0.5 seconds to check if the `NSPasteboard` change count has incremented.
    func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }
}
