content = File.read('CopyM8/ContentView.swift')

# 1. DeviceSwitcherView
setup_ds = ".onAppear {\n            localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in"
new_ds = ".onCustomKeyPress { event in"
content.sub!(setup_ds, new_ds)

teardown_ds = /\.onDisappear \{\n\s*if let monitor = localEventMonitor \{\n\s*NSEvent\.removeMonitor\(monitor\)\n\s*localEventMonitor = nil\n\s*\}\n\s*\}/
content.sub!(teardown_ds, "")
content.gsub!(/^\s*@State private var localEventMonitor: Any\?\n/, "")

# 2. ContentView Event Monitor
content.gsub!(/^\s*@State private var eventMonitor: Any\?\n/, "")
content.gsub!(/^\s*teardownKeyboardMonitor\(\)\n/, "")
content.gsub!(/^\s*setupKeyboardMonitor\(\)\n/, "")
content.gsub!(/^\s*restartKeyboardMonitor\(\)\s*\n/, "")
content.gsub!(/\.onChange\(of: viewModel\.expandedFolderIds\) \{ _, _ in restartKeyboardMonitor\(\) \}\n/, "")
content.gsub!(/\.onChange\(of: clipboard\.history\) \{ _, _ in restartKeyboardMonitor\(\) \}\n/, "")
content.gsub!(/restartKeyboardMonitor\(\)/, "")

# Remove teardown and restart methods carefully
td_method = "    private func teardownKeyboardMonitor() {\n        if let monitor = eventMonitor {\n            NSEvent.removeMonitor(monitor)\n            eventMonitor = nil\n        }\n    }\n    \n    private func restartKeyboardMonitor() {\n        teardownKeyboardMonitor()\n        setupKeyboardMonitor()\n    }"
content.sub!(td_method, "")

# Replace setupKeyboardMonitor with handleKeyPress
setup_method = "    private func setupKeyboardMonitor() {\n        let _isSearchFocused = self._isSearchFocused\n        \n        let clipboard = self.clipboard\n        let pasteItem = self.pasteItem\n        let _isDense = self._isDense\n        \n        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in"
new_setup_method = "    private func handleKeyPress(_ event: NSEvent) -> NSEvent? {\n        guard NSApplication.shared.windows.first?.isVisible == true else { return event }"
content.sub!(setup_method, new_setup_method)

# Now we must insert .onCustomKeyPress(handleKeyPress) at the end of the ContentView body
content.sub!(".onChange(of: viewModel.activeTab) { _, _ in", ".onCustomKeyPress(handleKeyPress)\n        .onChange(of: viewModel.activeTab) { _, _ in")

File.write('CopyM8/ContentView.swift', content)
