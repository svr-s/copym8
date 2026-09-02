# CopyM8 Cloud Sync Schema

In order for CopyM8 to sync seamlessly across different platforms (macOS, Android, etc.) via cloud folders (like iCloud or Google Drive), all platforms MUST adhere to this exact JSON schema for serialization.

## 1. Clipboard Item (`ClipboardItem`)
Used to represent a single copied entry in `history.json`.

```json
{
  "id": "UUID-STRING",
  "text": "The copied text or filename",
  "timestamp": "ISO8601 Date String",
  "sourceApp": "App Name (optional)",
  "hasRTF": false,
  "hasHTML": false,
  "hasRTFD": false,
  "hasWebArchive": false,
  "hasPDF": false,
  "isPinned": false,
  "itemType": "text | link | image | file",
  "fileURLs": ["/path/to/file1", "/path/to/file2"],
  "folderId": "UUID-STRING (optional)",
  "orderIndex": 0,
  "isDeleted": false,
  "deletedAt": "ISO8601 Date String (optional)"
}
```

## 2. Clipboard Folder (`ClipboardFolder`)
Used to represent custom user groups/folders in `folders.json`.

```json
{
  "id": "UUID-STRING",
  "name": "Folder Display Name",
  "orderIndex": 0
}
```

## 3. Queue State (`QueueState`)
Used for maintaining the global sequence state across devices.

```json
{
  "queueIDs": ["UUID-1", "UUID-2"],
  "queuePlayheadIndex": 0
}
```

## Platform-Specific Payloads
The JSON files only hold metadata. Rich payloads (images, RTF) are stored as raw binary files on disk using the item's `id` as the filename. 
- Example: If an item has `hasHTML: true`, there must be an `{id}.html` file in the payload directory.
- Android apps reading a macOS-generated item can safely ignore formats they don't support (like `hasRTFD` or `hasWebArchive`).
