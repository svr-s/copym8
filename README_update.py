with open('/Users/dodos/Documents/repositories/vatsa_codes/CopyM8/README.md', 'r') as f:
    content = f.read()

old_accordion = "- **Accordion Folder Groups**: Use `Right Arrow` to expand folders and view their items. Use `Left Arrow` to collapse or jump to the parent folder. Use `Option + Left Arrow` for a quick \"Super Collapse\" to instantly shut a folder and return to its header."

new_accordion = "- **Accordion Folder Groups**: Use `Right Arrow` to expand folders and view their items. Use `Left Arrow` to collapse or jump to the parent folder. Use `Option + Left Arrow` for a quick \"Super Collapse\" to instantly shut a folder and return to its header. You can also use `Cmd + Shift + Down` to instantly expand all folders, and `Cmd + Shift + Up` to collapse them all."

if old_accordion in content:
    content = content.replace(old_accordion, new_accordion)
    
old_bulk = "- **Advanced Bulk Edit Mode**: Press `Cmd + E` to enter a Finder-style selection mode. Use `Shift + Up/Down` to highlight a range of items, and hit `Space` to bulk toggle checkboxes! Features context-aware \"Select All\" (`Cmd + A`) that perfectly respects your active filters, allowing you to bulk group or bulk delete with ease."

new_bulk = """- **Advanced Bulk Edit Mode**: Press `Cmd + E` to enter a Finder-style selection mode. Use `Shift + Up/Down` to highlight a range of items, and hit `Space` to bulk toggle checkboxes! Features context-aware "Select All" (`Cmd + A`) that perfectly respects your active filters, allowing you to bulk group or bulk delete with ease.
- **Keyboard Reordering System**: In Edit Mode, use `Cmd + Up/Down` to seamlessly reorder items (or whole folders!). Reordering intelligently scopes to your active search filters or specific folder contents. You can also freeze specific items at the top while sorting!"""

if old_bulk in content:
    content = content.replace(old_bulk, new_bulk)

with open('/Users/dodos/Documents/repositories/vatsa_codes/CopyM8/README.md', 'w') as f:
    f.write(content)

print("README updated")
