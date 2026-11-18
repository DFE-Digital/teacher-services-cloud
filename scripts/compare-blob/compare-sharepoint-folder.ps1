param(
  [string]$ManifestPath,
  [string]$SiteId,
  [string]$DriveId,
  [string]$FolderItemId,
  [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
$temporaryReport = $null
$writer = $null

function Get-ObjectProperty {
  param(
    [object]$Object,
    [string]$Name
  )

  if ($null -eq $Object) {
    return $null
  }

  $property = $Object.PSObject.Properties[$Name]
  if ($null -ne $property) {
    return ,$property.Value
  }

  return $null
}

function Invoke-AzJson {
  param(
    [string[]]$Arguments,
    [string]$Operation
  )

  $stderrPath = [System.IO.Path]::GetTempFileName()
  try {
    $output = & az @Arguments 2> $stderrPath
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
      $details = [System.IO.File]::ReadAllText($stderrPath).Trim()
      throw "Azure CLI failed to $Operation (exit code $exitCode). $details"
    }

    $json = ($output | ForEach-Object { [string]$_ }) -join [System.Environment]::NewLine
    try {
      $result = ConvertFrom-Json -InputObject $json -ErrorAction Stop
    }
    catch {
      throw "Azure CLI returned invalid JSON while attempting to $Operation. $($_.Exception.Message)"
    }

    return ,$result
  }
  finally {
    Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
  }
}

function Test-NonNegativeNumber {
  param([object]$Value)

  return ($Value -is [System.ValueType] -and $Value -isnot [bool] -and $Value -ge 0)
}

function Add-SharePointFolderFiles {
  param(
    [string]$CurrentFolderId,
    [string]$RelativePath,
    [System.Collections.Generic.List[object]]$Inventory
  )

  $encodedSiteId = [System.Uri]::EscapeDataString($SiteId)
  $encodedDriveId = [System.Uri]::EscapeDataString($DriveId)
  $encodedFolderId = [System.Uri]::EscapeDataString($CurrentFolderId)
  $nextUrl = "https://graph.microsoft.com/v1.0/sites/$encodedSiteId/drives/$encodedDriveId/items/$encodedFolderId/children?%24select=id%2Cname%2Cfile%2Cfolder%2Csize"

  while (-not [string]::IsNullOrEmpty($nextUrl)) {
    $page = Invoke-AzJson -Arguments @(
      'rest', '--method', 'GET', '--url', $nextUrl,
      '--only-show-errors', '--output', 'json'
    ) -Operation "list SharePoint folder '$RelativePath'"
    $items = Get-ObjectProperty -Object $page -Name 'value'
    if ($items -isnot [System.Array]) {
      throw "Unexpected Graph response while listing SharePoint folder '$RelativePath'; expected a value array."
    }

    foreach ($item in $items) {
      $itemId = Get-ObjectProperty -Object $item -Name 'id'
      $itemName = Get-ObjectProperty -Object $item -Name 'name'
      if ($itemId -isnot [string] -or [string]::IsNullOrEmpty($itemId) -or
          $itemName -isnot [string] -or [string]::IsNullOrEmpty($itemName)) {
        throw "Graph returned an item without a valid ID or name in '$RelativePath'."
      }

      if ([string]::IsNullOrEmpty($RelativePath)) {
        $childRelativePath = $itemName
      }
      else {
        $childRelativePath = "$RelativePath/$itemName"
      }

      $folderFacet = Get-ObjectProperty -Object $item -Name 'folder'
      $fileFacet = Get-ObjectProperty -Object $item -Name 'file'
      if ($null -ne $folderFacet) {
        Add-SharePointFolderFiles -CurrentFolderId $itemId `
          -RelativePath $childRelativePath -Inventory $Inventory
      }
      elseif ($null -ne $fileFacet) {
        $size = Get-ObjectProperty -Object $item -Name 'size'
        if (-not (Test-NonNegativeNumber -Value $size)) {
          throw "Graph returned an invalid size for SharePoint file '$childRelativePath'."
        }

        $hashes = Get-ObjectProperty -Object $fileFacet -Name 'hashes'
        $Inventory.Add([pscustomobject]@{
          sharepoint_relative_path = $childRelativePath
          size_bytes = $size
          sharepoint_hashes = $hashes
        })
      }
    }

    $nextUrl = Get-ObjectProperty -Object $page -Name '@odata.nextLink'
    if ($null -ne $nextUrl -and $nextUrl -isnot [string]) {
      throw "Graph returned an invalid pagination link while listing '$RelativePath'."
    }
  }
}

try {
  if ([string]::IsNullOrWhiteSpace($ManifestPath) -or
      [string]::IsNullOrWhiteSpace($SiteId) -or
      [string]::IsNullOrWhiteSpace($DriveId) -or
      [string]::IsNullOrWhiteSpace($FolderItemId) -or
      [string]::IsNullOrWhiteSpace($ReportPath)) {
    throw 'Usage: compare-sharepoint-folder.ps1 -ManifestPath <manifest.jsonl> -SiteId <site-id> -DriveId <drive-id> -FolderItemId <folder-item-id> -ReportPath <report.jsonl>'
  }

  if ($null -eq (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Required command not found: az'
  }

  $manifestFullPath = [System.IO.Path]::GetFullPath($ManifestPath)
  $reportFullPath = [System.IO.Path]::GetFullPath($ReportPath)
  if (-not [System.IO.File]::Exists($manifestFullPath)) {
    throw "Manifest does not exist or is not readable: $manifestFullPath"
  }
  if ([string]::Equals($manifestFullPath, $reportFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Report path must not refer to the manifest: $reportFullPath"
  }

  $reportDirectory = [System.IO.Path]::GetDirectoryName($reportFullPath)
  if (-not [System.IO.Directory]::Exists($reportDirectory)) {
    throw "Output directory does not exist: $reportDirectory"
  }

  $manifestRecords = [System.Collections.Generic.List[object]]::new()
  $lineNumber = 0
  foreach ($line in [System.IO.File]::ReadLines($manifestFullPath)) {
    $lineNumber++
    if ([string]::IsNullOrWhiteSpace($line)) {
      throw "Manifest is invalid: line $lineNumber is empty."
    }

    try {
      $record = ConvertFrom-Json -InputObject $line -ErrorAction Stop
    }
    catch {
      throw "Manifest is invalid: line $lineNumber is not valid JSON. $($_.Exception.Message)"
    }

    $blobName = Get-ObjectProperty -Object $record -Name 'blob_name'
    $size = Get-ObjectProperty -Object $record -Name 'size_bytes'
    if ($record -is [System.Array] -or $blobName -isnot [string] -or
        [string]::IsNullOrEmpty($blobName) -or -not (Test-NonNegativeNumber -Value $size)) {
      throw "Manifest is invalid: line $lineNumber must have a string blob_name and non-negative numeric size_bytes."
    }
    $manifestRecords.Add($record)
  }

  $sharePointInventory = [System.Collections.Generic.List[object]]::new()
  Add-SharePointFolderFiles -CurrentFolderId $FolderItemId -RelativePath '' `
    -Inventory $sharePointInventory

  $sharePointByPath = [System.Collections.Generic.Dictionary[string,object]]::new(
    [System.StringComparer]::Ordinal)
  foreach ($file in $sharePointInventory) {
    if ($sharePointByPath.ContainsKey($file.sharepoint_relative_path)) {
      throw "SharePoint returned duplicate file path '$($file.sharepoint_relative_path)'."
    }
    $sharePointByPath.Add($file.sharepoint_relative_path, $file)
  }

  $temporaryReport = Join-Path $reportDirectory (".{0}.tmp.{1}" -f
    [System.IO.Path]::GetFileName($reportFullPath),
    [guid]::NewGuid().ToString('N'))
  $writer = [System.IO.StreamWriter]::new(
    $temporaryReport,
    $false,
    [System.Text.UTF8Encoding]::new($false))

  foreach ($blob in $manifestRecords) {
    $blobName = Get-ObjectProperty -Object $blob -Name 'blob_name'
    $match = $null
    $exists = $sharePointByPath.ContainsKey($blobName)
    if ($exists) {
      $match = $sharePointByPath[$blobName]
    }

    $result = [ordered]@{
      blob_name = $blobName
      full_path = Get-ObjectProperty -Object $blob -Name 'full_path'
      azure_size_bytes = Get-ObjectProperty -Object $blob -Name 'size_bytes'
      azure_content_md5 = Get-ObjectProperty -Object $blob -Name 'content_md5'
      azure_hash_algorithm = Get-ObjectProperty -Object $blob -Name 'hash_algorithm'
      exists = $exists
      sharepoint_relative_path = if ($exists) { $match.sharepoint_relative_path } else { $null }
      sharepoint_size_bytes = if ($exists) { $match.size_bytes } else { $null }
      size_match = if ($exists) {
        $match.size_bytes -eq (Get-ObjectProperty -Object $blob -Name 'size_bytes')
      }
      else {
        $null
      }
      sharepoint_hashes = if ($exists) { $match.sharepoint_hashes } else { $null }
    }
    $writer.WriteLine((ConvertTo-Json -InputObject $result -Compress -Depth 20))
  }

  $writer.Dispose()
  $writer = $null
  Move-Item -LiteralPath $temporaryReport -Destination $reportFullPath -Force
  $temporaryReport = $null

  Write-Host "Wrote SharePoint comparison report to $reportFullPath"
}
catch {
  [System.Console]::Error.WriteLine($_.Exception.Message)
  exit 1
}
finally {
  if ($null -ne $writer) {
    $writer.Dispose()
  }
  if ($null -ne $temporaryReport -and
      [System.IO.File]::Exists($temporaryReport)) {
    Remove-Item -LiteralPath $temporaryReport -Force -ErrorAction SilentlyContinue
  }
}
