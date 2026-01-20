param(
  [string]$LogsRoot = "$PSScriptRoot\\..\\logs\\skills",
  [int]$SinceDays = 30,
  [string]$RepoRootDefault = ''
)

function Add-IfMissing($obj, $name, $value) {
  if (-not ($obj.PSObject.Properties.Name -contains $name)) {
    $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value -Force
  }
}

$cutoff = (Get-Date).ToUniversalTime().AddDays(-$SinceDays)
$files = Get-ChildItem -Path $LogsRoot -Recurse -Filter "skill-usage-*.jsonl" -File -ErrorAction SilentlyContinue |
  Where-Object { $_.LastWriteTimeUtc -ge $cutoff }

foreach ($file in $files) {
  $updated = @()
  foreach ($line in Get-Content -Path $file.FullName) {
    $obj = $null
    try { $obj = $line | ConvertFrom-Json } catch { continue }

    Add-IfMissing $obj "session_id" ""
    Add-IfMissing $obj "event_index" -1
    Add-IfMissing $obj "source" "manual"
    Add-IfMissing $obj "event_type" "manual"
    Add-IfMissing $obj "cli_originator" ""
    Add-IfMissing $obj "cli_version" ""

    if ($RepoRootDefault -and [string]::IsNullOrEmpty($obj.project_repo_root)) {
      $obj.project_repo_root = $RepoRootDefault
    }

    $updated += ($obj | ConvertTo-Json -Compress)
  }
  Set-Content -Path $file.FullName -Value $updated -Encoding utf8
}
