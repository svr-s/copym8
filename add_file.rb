require 'xcodeproj'
project = Xcodeproj::Project.open('CopyM8.xcodeproj')
group = project.main_group.find_subpath(File.join('CopyM8', 'Views', 'Components'), true)
file = group.new_file('KeyboardMonitorModifier.swift')
target = project.targets.first
target.add_file_references([file])
project.save
