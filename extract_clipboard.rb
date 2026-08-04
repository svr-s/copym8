require 'fileutils'
require 'xcodeproj'

content = File.read('CopyM8/ClipboardManager.swift')

groups = {
  "Folders" => [
    "func getFilteredFolders",
    "func setFolderId",
    "func saveFolders()"
  ],
  "Reordering" => [
    "func reorderFolders",
    "func reorderGroupItems",
    "func reorderPinnedItems",
    "func moveItem",
    "func moveItems",
    "func moveFolder",
    "func moveFolders",
    "func applyReorder"
  ],
  "Sync" => [
    "func disableSync()",
    "func enableSync()",
    "func renameDeviceFiles",
    "func purgeRemoteDevice",
    "func fetchRemoteHistory",
    "func removeFromCloudCopyFile",
    "func moveToCloud"
  ],
  "Polling" => [
    "private func startPolling()",
    "private func stopPolling()",
    "private func pollPasteboard()",
    "private func processPasteboardItem"
  ],
  "Items" => [
    "func deleteItem",
    "func deleteItems",
    "func clearAll()",
    "func restoreItems",
    "func togglePin",
    "func pruneStorageIfNeeded",
    "func truncateHistory",
    "func isItemAvailable",
    "func prepareForPaste",
    "func triggerPasteKeystroke",
    "func importItems"
  ]
}

FileUtils.mkdir_p('CopyM8/Extensions')

project = Xcodeproj::Project.open('CopyM8.xcodeproj')
target = project.targets.first
group = project.main_group.find_subpath(File.join('CopyM8', 'Extensions'), true)

groups.each do |ext_name, func_names|
  extracted_funcs = []
  
  func_names.each do |func_name|
    lines = content.lines
    start_idx = lines.index { |l| l.include?(func_name) }
    next unless start_idx

    brace_count = 0
    extracted = []
    
    lines[start_idx..-1].each do |line|
      extracted << line
      brace_count += line.count('{') - line.count('}')
      break if brace_count == 0 && line.include?('}')
    end

    func_content = extracted.join
    
    # Strip private keyword if it was private
    func_content.gsub!(/private\s+func\s+/, "func ")
    
    extracted_funcs << func_content
    content.sub!(extracted.join, "    // #{func_name.split('(').first} extracted to ClipboardManager+#{ext_name}.swift\n")
  end

  next if extracted_funcs.empty?

  file_name = "ClipboardManager+#{ext_name}.swift"
  file_path = "CopyM8/Extensions/#{file_name}"
  
  File.write(file_path, <<~SWIFT
    import Foundation
    import AppKit

    extension ClipboardManager {
    #{extracted_funcs.join("\n")}
    }
  SWIFT
  )
  
  # Add to Xcode project
  file_ref = group.new_reference("Extensions/#{file_name}")
  unless target.source_build_phase.files.map(&:file_ref).include?(file_ref)
    target.source_build_phase.add_file_reference(file_ref)
  end
end

File.write('CopyM8/ClipboardManager.swift', content)
project.save
puts "Extraction complete!"
