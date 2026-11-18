# Compare Azure blob and SharePoint files

These PowerShell scripts create a JSON Lines (`.jsonl`) blob manifest and compare it with a SharePoint document library folder. Each line is a separate JSON object, making the files suitable for streaming and processing with tools such as `jq`. This is a practical format for approximately 22,000 files: it preserves path characters safely and does not require loading the entire result into a spreadsheet.

## Requirements and access

- Windows PowerShell 5.1 or PowerShell 7+, and Azure CLI (`az`). No Bash or `jq` installation is required by the scripts.
- Run `az login` with an identity that can read the storage container and call Microsoft Graph for the SharePoint site and drive. The identity needs appropriate SharePoint/Graph read permissions; Azure CLI login alone does not grant those permissions.
- Supply the SharePoint site ID, drive ID, and ID of the folder to compare. The comparison recursively enumerates the folder and uses Microsoft Graph pagination.

## Create the manifest

```powershell
powershell.exe -NoProfile -File .\scripts\compare-blob\export-blob-manifest.ps1 `
  -StorageAccount <storage-account> `
  -Container <container> `
  -ManifestPath .\manifest.jsonl
```

The script uses Azure CLI login (`--auth-mode login`) to list every blob, then atomically writes JSONL records with:

- `storage_account`, `container`, `blob_name`, and `full_path` (account/container/blob name).
- `size_bytes`.
- `content_md5` (the stored Base64 value) and `hash_algorithm` (`MD5`) when the blob's Content-MD5 property is set; otherwise both are `null`.

The script records existing Content-MD5 metadata only. It does not download blobs to calculate missing hashes.

## Compare with SharePoint

```powershell
powershell.exe -NoProfile -File .\scripts\compare-blob\compare-sharepoint-folder.ps1 `
  -ManifestPath .\manifest.jsonl `
  -SiteId <site-id> `
  -DriveId <drive-id> `
  -FolderItemId <folder-item-id> `
  -ReportPath .\report.jsonl
```

Blob names are matched exactly against paths relative to the supplied SharePoint folder. Nested folder structure is preserved; for example, blob `reports/2025/file.csv` matches SharePoint path `reports/2025/file.csv`. The output contains one record per manifest entry with these fields:

- `blob_name`, `full_path`, and `azure_size_bytes` identify the manifest entry and its Azure size.
- `azure_content_md5` and `azure_hash_algorithm` preserve the Azure Content-MD5 metadata; both are `null` when unavailable.
- `exists` indicates whether a matching SharePoint file was found.
- `sharepoint_relative_path` is the matched path relative to the supplied folder, or `null` when absent.
- `sharepoint_size_bytes` is the SharePoint file size, or `null` when absent.
- `size_match` compares the sizes independently of existence; it is `null` when absent.
- `sharepoint_hashes` contains available Graph hash metadata, or `null`. Hashes are informational and are not compared because Graph may return a different algorithm than Azure's Content-MD5.

Both scripts fail on command/API errors instead of writing a successful-looking partial output. The comparison report is replaced only after SharePoint enumeration and comparison succeed.
