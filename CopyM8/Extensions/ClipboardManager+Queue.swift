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
    
    /// Pastes the next item in the queue.
    func pasteNextInQueue() {
        guard !queueIDs.isEmpty else { return }
        
        // Find the item
        let idToPaste = queueIDs[queuePlayheadIndex]
        if let item = history.first(where: { $0.id == idToPaste }) {
            // Prepare the pasteboard
            prepareForPaste(item, formatType: .plain)
            
            // Trigger paste keystroke
            triggerPasteKeystroke()
            
            // Advance the playhead
            queuePlayheadIndex += 1
            
            // Auto reset and turn off recording if we hit the end
            if queuePlayheadIndex >= queueIDs.count {
                queuePlayheadIndex = 0
                isQueueRecording = false
            }
        } else {
            // Item might have been deleted, just advance
            queuePlayheadIndex += 1
            if queuePlayheadIndex >= queueIDs.count {
                queuePlayheadIndex = 0
                isQueueRecording = false
            }
        }
    }
}
