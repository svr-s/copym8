require 'xcodeproj'

project_path = 'CopyM8.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group = project.main_group.find_subpath(File.join('CopyM8'), true)

# Add StorageService.swift
file_ref = group.new_reference('StorageService.swift')
target.add_file_references([file_ref])

# Add CloudSyncService.swift
file_ref2 = group.new_reference('CloudSyncService.swift')
target.add_file_references([file_ref2])

project.save
