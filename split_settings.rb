file_path = "CopyM8/Views/Settings/SettingsView.swift"
content = File.read(file_path)

# Extract generalTab
if content =~ /    var generalTab: some View \{.*?\n    \}/m
  # This regex won't work well because of nested braces.
end
