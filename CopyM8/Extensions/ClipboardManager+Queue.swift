import Foundation

extension ClipboardManager {
    /// Adds an item to the queue. Respects the user's max queue size limit.
    func enqueueItem(id: UUID) {
        let maxQueueSize = UserDefaults.standard.integer(forKey: "maxQueueSize")
        let limit = maxQueueSize == 0 ? 10 : maxQueueSize // Default to 10 if not set
        
        if queueIDs.count >= limit {
            queueIDs.removeFirst()
            if queuePlayheadIndex > 0 {
                queuePlayheadIndex -= 1
            }
        }
        
        queueIDs.append(id)
    }
    
    /// Clears the queue entirely.
    func clearQueue() {
        queueIDs.removeAll()
        queuePlayheadIndex = 0
    }
    
    /// Resets the playhead to the beginning of the queue.
    func resetPlayhead() {
        queuePlayheadIndex = 0
    }
}
