param(
  [string]$StorageAccount,
  [string]$Container,
  [string]$ManifestPath
)

$ErrorActionPreference = 'Stop'
$temporaryManifest = $null
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

try {
  if ([string]::IsNullOrWhiteSpace($StorageAccount) -or
      [string]::IsNullOrWhiteSpace($Container) -or
      [string]::IsNullOrWhiteSpace($ManifestPath)) {
    throw 'Usage: export-blob-manifest.ps1 -StorageAccount <name> -Container <name> -ManifestPath <manifest.jsonl>'
  }

  if ($null -eq (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Required command not found: az'
  }

  $manifestFullPath = [System.IO.Path]::GetFullPath($ManifestPath)
  $manifestDirectory = [System.IO.Path]::GetDirectoryName($manifestFullPath)
  if (-not [System.IO.Directory]::Exists($manifestDirectory)) {
    throw "Output directory does not exist: $manifestDirectory"
  }

  $blobs = Invoke-AzJson -Arguments @(
    'storage', 'blob', 'list',
    '--account-name', $StorageAccount,
    '--container-name', $Container,
    '--num-results', '*',
    '--only-show-errors',
    '--output', 'json'
  ) -Operation "list blobs in container '$Container'"

  if ($null -eq $blobs) {
    $blobs = @()
  }
  if ($blobs -isnot [System.Array]) {
    throw 'Azure CLI returned an unexpected blob list; expected a JSON array.'
  }

  $temporaryManifest = Join-Path $manifestDirectory (".{0}.tmp.{1}" -f
    [System.IO.Path]::GetFileName($manifestFullPath),
    [guid]::NewGuid().ToString('N'))
  $writer = [System.IO.StreamWriter]::new(
    $temporaryManifest,
    $false,
    [System.Text.UTF8Encoding]::new($false))

  foreach ($blob in $blobs) {
    $blobName = Get-ObjectProperty -Object $blob -Name 'name'
    $properties = Get-ObjectProperty -Object $blob -Name 'properties'
    $size = Get-ObjectProperty -Object $properties -Name 'contentLength'
    $contentSettings = Get-ObjectProperty -Object $properties -Name 'contentSettings'
    $contentMd5 = Get-ObjectProperty -Object $contentSettings -Name 'contentMd5'

    if ($blobName -isnot [string] -or [string]::IsNullOrEmpty($blobName)) {
      throw 'Azure CLI returned a blob without a valid name.'
    }
    if ($size -isnot [System.ValueType] -or $size -is [bool] -or $size -lt 0) {
      throw "Azure CLI returned an invalid size for blob '$blobName'."
    }
    if ($null -ne $contentMd5 -and $contentMd5 -isnot [string]) {
      throw "Azure CLI returned invalid Content-MD5 metadata for blob '$blobName'."
    }

    $record = [ordered]@{
      storage_account = $StorageAccount
      container = $Container
      blob_name = $blobName
      full_path = "$StorageAccount/$Container/$blobName"
      size_bytes = $size
      content_md5 = $contentMd5
      hash_algorithm = if ([string]::IsNullOrEmpty($contentMd5)) { $null } else { 'MD5' }
    }
    $writer.WriteLine((ConvertTo-Json -InputObject $record -Compress -Depth 20))
  }

  $writer.Dispose()
  $writer = $null
  Move-Item -LiteralPath $temporaryManifest -Destination $manifestFullPath -Force
  $temporaryManifest = $null

  Write-Host "Wrote blob manifest to $manifestFullPath"
}
catch {
  [System.Console]::Error.WriteLine($_.Exception.Message)
  exit 1
}
finally {
  if ($null -ne $writer) {
    $writer.Dispose()
  }
  if ($null -ne $temporaryManifest -and
      [System.IO.File]::Exists($temporaryManifest)) {
    Remove-Item -LiteralPath $temporaryManifest -Force -ErrorAction SilentlyContinue
  }
}
