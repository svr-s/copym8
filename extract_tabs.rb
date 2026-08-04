require 'fileutils'

content = File.read('CopyM8/Views/Settings/SettingsView.swift')

tabs = ["generalTab", "typesTab", "syncTab", "privacyTab", "shortcutsTab"]

FileUtils.mkdir_p('CopyM8/Views/Settings/Tabs')

tabs.each do |tab_name|
  # Find the starting line of the tab
  lines = content.lines
  start_idx = lines.index { |l| l.include?("var #{tab_name}: some View {") }
  next unless start_idx

  # Extract using brace counting
  brace_count = 0
  extracted = []
  
  lines[start_idx..-1].each do |line|
    extracted << line
    brace_count += line.count('{') - line.count('}')
    break if brace_count == 0 && line.include?('}')
  end

  tab_content = extracted.join

  # Write to file
  File.write("CopyM8/Views/Settings/Tabs/#{tab_name.capitalize}.swift", <<~SWIFT
    import SwiftUI
    import AppKit
    import KeyboardShortcuts

    extension SettingsView {
    #{tab_content.chomp}
    }
  SWIFT
  )
  
  # Remove from main file
  content.sub!(tab_content, "    // #{tab_name} extracted to Tabs/#{tab_name.capitalize}.swift\n")
end

File.write('CopyM8/Views/Settings/SettingsView.swift', content)
