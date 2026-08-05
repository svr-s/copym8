import Foundation

/// `HistoryEvictionService` manages the business logic for enforcing clipboard retention limits.
/// It calculates which items need to be deleted based on time limits (Trash expiration) 
/// or storage space limits (maxTotalStorageMB, Cloud Sync limits).
class HistoryEvictionService {
    /// Shared singleton instance.
    static let shared = HistoryEvictionService()
    
    /// Identifies items in the Trash that have exceeded the user's retention time limit.
    /// - Parameters:
    ///   - history: The array of all clipboard items.
    ///   - retentionDays: The maximum number of days an item is allowed to stay in the Trash (defaults to 7 if 0).
    /// - Returns: A set of UUIDs representing expired items that should be hard-deleted.
    func getExpiredTrashIDs(from history: [ClipboardItem], retentionDays: Int) -> Set<UUID> {
        let limit = retentionDays == 0 ? 7 : retentionDays
        let thresholdDate = Calendar.current.date(byAdding: .day, value: -limit, to: Date()) ?? Date.distantPast
        
        let expiredTrash = history.filter { ($0.isDeleted ?? false) && ($0.deletedAt ?? Date.distantFuture) < thresholdDate }
        return Set(expiredTrash.map { $0.id })
    }
    
    /// Determines which image items should be hard-deleted to keep the total disk usage under the maximum allowed threshold.
    /// Evicts trash images first, then unpinned loose images (oldest first).
    /// - Parameters:
    ///   - history: The array of all clipboard items.
    ///   - maxTotalStorageMB: The maximum permitted size of the local clipboard storage in megabytes.
    /// - Returns: A set of UUIDs representing items that must be deleted to free up space.
    func getIDsToPrune(from history: [ClipboardItem], maxTotalStorageMB: Int) -> Set<UUID> {
        var currentSizeMB = LocalImageStore.shared.getTotalSizeMB() + LocalPayloadStore.shared.getTotalSizeMB()
        var idsToRemove = Set<UUID>()
        
        let limitMB = Double(maxTotalStorageMB)
        if currentSizeMB <= limitMB { return idsToRemove }
        
        // 1. Hard-delete trash images first
        let trashImages = history.filter { ($0.isDeleted ?? false) && $0.itemType == .image }.sorted { $0.timestamp < $1.timestamp }
        for img in trashImages {
            if currentSizeMB <= limitMB { break }
            let size = LocalImageStore.shared.getFileSizeMB(id: img.id)
            idsToRemove.insert(img.id)
            currentSizeMB -= size
        }
        
        if currentSizeMB <= limitMB { return idsToRemove }
        
        // 2. Hard-delete unpinned images
        let unpinnedImages = history.filter { !($0.isDeleted ?? false) && !$0.isPinned && $0.folderId == nil && $0.itemType == .image }.sorted { $0.timestamp < $1.timestamp }
        for img in unpinnedImages {
            if currentSizeMB <= limitMB { break }
            let size = LocalImageStore.shared.getFileSizeMB(id: img.id)
            idsToRemove.insert(img.id)
            currentSizeMB -= size
        }
        
        return idsToRemove
    }
    
    /// Represents errors that occur during the cloud eviction evaluation process.
    enum EvictionError: Error {
        /// Thrown when there is not enough evictable space to accommodate a new item.
        case insufficientSpace(message: String)
    }
    
    /// Evaluates cloud storage limits when a new item is added, determining if older unpinned items must be evicted.
    /// - Parameters:
    ///   - itemSizeMB: The size of the incoming clipboard item.
    ///   - cloudItems: The array of items currently stored in the cloud clipboard.
    ///   - maxSizeMB: The maximum permitted size of the cloud clipboard folder.
    /// - Throws: `EvictionError.insufficientSpace` if all items are pinned/frozen and space cannot be freed.
    /// - Returns: An array of clipboard items that should be deleted to make room.
    func getCloudItemsToEvict(
        forNewItemSizeMB itemSizeMB: Double,
        cloudItems: [ClipboardItem],
        maxSizeMB: Double
    ) throws -> [ClipboardItem] {
        var currentTotalSize = 0.0
        for cItem in cloudItems {
            if cItem.itemType == .image { currentTotalSize += LocalImageStore.shared.getFileSizeMB(id: cItem.id, inCloud: true) }
            if cItem.hasRTF { currentTotalSize += LocalPayloadStore.shared.getFileSizeMB(id: cItem.id, type: .rtf, inCloud: true) }
            if cItem.hasHTML { currentTotalSize += LocalPayloadStore.shared.getFileSizeMB(id: cItem.id, type: .html, inCloud: true) }
            if cItem.itemType == .file { currentTotalSize += LocalFileStore.shared.getFileSizeMB(for: cItem.id) }
        }
        
        let spaceNeeded = (currentTotalSize + itemSizeMB) - maxSizeMB
        if spaceNeeded <= 0 {
            return [] // No eviction needed
        }
        
        // Only evict unpinned items that aren't manually reordered (orderIndex == 0)
        var evictableItems = cloudItems.filter { $0.orderIndex == 0 && !$0.isPinned }
        evictableItems.sort { $0.timestamp < $1.timestamp }
        
        var spaceAvailable = 0.0
        var itemsToEvict: [ClipboardItem] = []
        for evictable in evictableItems {
            if spaceAvailable >= spaceNeeded { break }
            itemsToEvict.append(evictable)
            
            if evictable.itemType == .image { spaceAvailable += LocalImageStore.shared.getFileSizeMB(id: evictable.id, inCloud: true) }
            if evictable.hasRTF { spaceAvailable += LocalPayloadStore.shared.getFileSizeMB(id: evictable.id, type: .rtf, inCloud: true) }
            if evictable.hasHTML { spaceAvailable += LocalPayloadStore.shared.getFileSizeMB(id: evictable.id, type: .html, inCloud: true) }
            if evictable.itemType == .file { spaceAvailable += LocalFileStore.shared.getFileSizeMB(for: evictable.id) }
        }
        
        if spaceAvailable < spaceNeeded {
            throw EvictionError.insufficientSpace(message: "Error: Cloud Copy full. Unfreeze items to make space.")
        }
        
        return itemsToEvict
    }
}
