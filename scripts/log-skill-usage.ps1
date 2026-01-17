param(
  [Parameter(Mandatory = $true)]
  [string]$SkillName,

  [Parameter(Mandatory = $true)]
  [ValidateSet('success', 'failure', 'retries')]
  [string]$Status,

  [string]$Notes = '',
  [string]$SkillVersion = 'unknown',
  [string]$ProjectRepoRoot = '',
  [string]$ProjectCwd = '',
  [string]$TimestampUtc = ''
)

function Get-RepoRoot([string]$StartPath) {
  $dir = Get-Item -LiteralPath $StartPath -ErrorAction SilentlyContinue
  while ($dir) {
    if (Test-Path -LiteralPath (Join-Path $dir.FullName '.git')) {
      return $dir.FullName
    }
    if (-not $dir.Parent) {
      break
    }
    $dir = $dir.Parent
  }
  return $null
}

if (-not $ProjectCwd) {
  $ProjectCwd = (Get-Location).Path
}

if (-not $ProjectRepoRoot) {
  $ProjectRepoRoot = Get-RepoRoot $ProjectCwd
}

if (-not $TimestampUtc) {
  $TimestampUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
}

$notesSafe = $Notes -replace "[\r\n]+", " "
if ($notesSafe.Length -gt 200) {
  $notesSafe = $notesSafe.Substring(0, 200)
}

$entry = [ordered]@{
  timestamp = $TimestampUtc
  skill_name = $SkillName
  skill_version = $SkillVersion
  status = $Status
  notes = $notesSafe
  project_repo_root = $ProjectRepoRoot
  project_cwd = $ProjectCwd
}

$month = (Get-Date).ToUniversalTime().ToString('yyyy-MM')
$day = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
$logDir = [IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath "..\\logs\\skills\\$month"))

New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$logFile = Join-Path -Path $logDir -ChildPath "skill-usage-$day.jsonl"
$entryJson = $entry | ConvertTo-Json -Compress

Add-Content -Path $logFile -Value $entryJson -Encoding utf8
