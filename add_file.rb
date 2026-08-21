require 'xcodeproj'
project_path = 'CopyM8.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first
group = project.main_group.find_subpath(File.join('CopyM8'), true)
file_ref = group.new_reference('BackupManager.swift')
target.add_file_references([file_ref])
project.save
