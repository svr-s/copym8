require 'fileutils'
require 'xcodeproj'

content = File.read('CopyM8/ContentView.swift')

groups = {
  "DisplayNodes" => [
    "private var displayNodes: [DisplayNode] {"
  ],
  "Keyboard" => [
    "private func handleKeyPress(_ event: NSEvent) -> NSEvent?"
  ],
  "Window" => [
    "private func getDynamicWindowSize() -> CGSize",
    "private func adjustWindowFrame",
    "private func snapToEdge()"
  ],
  "Actions" => [
    "private func moveSelectedItem",
    "private func moveSelectedFolder",
    "private func deleteSelectedItems",
    "private func deleteFolders",
    "private func ungroupSelectedItems",
    "private func pasteItem"
  ],
  "Helpers" => [
    "private func applyTheme",
    "private func cycleColor",
    "private func getVisibleTabs"
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
    
    # Strip private keyword
    func_content.gsub!(/private\s+func\s+/, "func ")
    func_content.gsub!(/private\s+var\s+displayNodes/, "var displayNodes")
    
    extracted_funcs << func_content
    content.sub!(extracted.join, "    // #{func_name.split('(').first} extracted to ContentView+#{ext_name}.swift\n")
  end

  next if extracted_funcs.empty?

  file_name = "ContentView+#{ext_name}.swift"
  file_path = "CopyM8/Extensions/#{file_name}"
  
  File.write(file_path, <<~SWIFT
    import SwiftUI
    import AppKit

    extension ContentView {
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

File.write('CopyM8/ContentView.swift', content)
project.save
puts "ContentView Extraction complete!"
