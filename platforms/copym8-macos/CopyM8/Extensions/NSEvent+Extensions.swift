import AppKit

extension NSEvent {
    /// Determines if the event is a standard macOS system command shortcut
    /// (e.g., Cmd+Q, Cmd+W, Cmd+M, Cmd+,) that should be allowed to pass through to the system.
    /// This prevents unhandled command shortcuts from triggering the macOS error beep.
    func isAllowedSystemCommand(additionalAllowedKeys: Set<UInt16> = []) -> Bool {
        guard self.modifierFlags.contains(.command) || self.modifierFlags.contains(.control) else {
            return false
        }
        
        var allowedKeys: Set<UInt16> = [
            12, // Q (Quit)
            13, // W (Close Window)
            46, // M (Minimize)
            43  // , (Settings)
        ]
        
        allowedKeys.formUnion(additionalAllowedKeys)
        
        return allowedKeys.contains(self.keyCode)
    }
}
