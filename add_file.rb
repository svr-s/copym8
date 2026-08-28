require 'xcodeproj'
project = Xcodeproj::Project.open('CopyM8.xcodeproj')
target = project.targets.first

# Add the file reference
group = project.main_group.find_subpath(File.join('CopyM8', 'Views', 'HUD'), true)
group.set_source_tree('<group>')
file_ref = group.new_reference('QueueHUDView.swift')

# Add to compile sources phase
target.source_build_phase.add_file_reference(file_ref)

project.save
