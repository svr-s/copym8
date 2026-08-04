content = File.read('CopyM8/ContentView.swift')

# 1. Remove eventMonitor property
content.gsub!(/@State private var eventMonitor: Any\?/, '')

# 2. Replace setupKeyboardMonitor signature
setup_regex = /private func setupKeyboardMonitor\(\) \{(?:\s*let [^\n]+)*\s*eventMonitor = NSEvent\.addLocalMonitorForEvents\(matching: \.keyDown\) \{ event in/m
new_setup = "private func handleKeyPress(_ event: NSEvent) -> NSEvent? {\n        guard NSApplication.shared.windows.first?.isVisible == true else { return event }"
content.sub!(setup_regex, new_setup)

# 3. Add .onCustomKeyPress(handleKeyPress) to the end of body
# The body ends with a padding followed by modifiers.
# Let's find the closing brace of body and insert it there. We know body has a lot of .onChange
# It's easier to find `.onChange(of: viewModel.activeTab)` and insert before it
content.sub!(/\.onChange\(of: viewModel\.activeTab\)/, ".onCustomKeyPress(handleKeyPress)\n        .onChange(of: viewModel.activeTab)")

# 4. Remove teardownKeyboardMonitor and restartKeyboardMonitor calls
content.gsub!(/^\s*teardownKeyboardMonitor\(\)\n?/, '')
content.gsub!(/^\s*setupKeyboardMonitor\(\)\n?/, '')
content.gsub!(/^\s*restartKeyboardMonitor\(\)\s*\n?/, '')
content.gsub!(/\.onChange\(of: viewModel\.expandedFolderIds\) \{ _, _ in restartKeyboardMonitor\(\) \}\n?/, '')
content.gsub!(/\.onChange\(of: clipboard\.history\) \{ _, _ in restartKeyboardMonitor\(\) \}\n?/, '')
content.gsub!(/restartKeyboardMonitor\(\)/, '')

# 5. Remove teardown and restart method definitions
teardown_def = /private func teardownKeyboardMonitor\(\) \{[\s\S]*?private func restartKeyboardMonitor\(\) \{[\s\S]*?\n    \}/
content.sub!(teardown_def, "")

# 6. DeviceSwitcherView
device_switcher_setup = /\.onAppear \{\s*localEventMonitor = NSEvent\.addLocalMonitorForEvents\(matching: \.keyDown\) \{ event in/
device_switcher_new = ".onCustomKeyPress { event in"
content.sub!(device_switcher_setup, device_switcher_new)

device_switcher_teardown = /\.onDisappear \{\s*if let monitor = localEventMonitor \{\s*NSEvent\.removeMonitor\(monitor\)\s*localEventMonitor = nil\s*\}\s*\}/
content.sub!(device_switcher_teardown, "")
content.gsub!(/@State private var localEventMonitor: Any\?/, '')

File.write('CopyM8/ContentView.swift', content)
