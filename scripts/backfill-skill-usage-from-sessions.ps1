param(
  [string]$SessionsRoot = "$env:USERPROFILE\\.codex\\sessions",
  [int]$SinceDays = 7,
  [string]$RepoRootOverride = '',
  [switch]$DryRun
)

# Security: This script must never write prompts, user text, file contents,
# secrets, or PII. It only logs skill names detected from assistant "Using `...`"
# lines plus minimal metadata. If this constraint cannot be satisfied, stop.

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

function Get-LogPath([DateTime]$UtcTime) {
  $month = $UtcTime.ToString('yyyy-MM')
  $day = $UtcTime.ToString('yyyy-MM-dd')
  $logDir = [IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath "..\\logs\\skills\\$month"))
  New-Item -ItemType Directory -Force -Path $logDir | Out-Null
  return Join-Path -Path $logDir -ChildPath "skill-usage-$day.jsonl"
}

function Add-LogEntry($entry, [switch]$DryRun) {
  $entryJson = $entry | ConvertTo-Json -Compress
  $ts = [DateTime]::Parse($entry.timestamp).ToUniversalTime()
  $logFile = Get-LogPath -UtcTime $ts

  if (Test-Path $logFile) {
    $existing = Get-Content -Path $logFile -ErrorAction SilentlyContinue
    $key = "\"timestamp\":\"$($entry.timestamp)\""
    $nameKey = "\"skill_name\":\"$($entry.skill_name)\""
    if ($existing -match [regex]::Escape($key) -and $existing -match [regex]::Escape($nameKey)) {
      return
    }
  }

  if ($DryRun) {
    Write-Host "[dry-run] $($entry.timestamp) $($entry.skill_name)"
    return
  }

  Add-Content -Path $logFile -Value $entryJson -Encoding utf8
}

function Extract-Skills([string]$text) {
  if (-not $text) { return @() }
  $matches = [regex]::Matches($text, 'Using\s+`([^`]+)`', 'IgnoreCase')
  $skills = @()
  foreach ($m in $matches) {
    $skills += $m.Groups[1].Value
  }
  return $skills
}

function Assert-SafeNotes([string]$notes) {
  if (-not $notes) { return }
  $danger = @("api", "token", "secret", "password", "passwd", "key=", "bearer", "oauth", "auth", "session", "cookie")
  foreach ($term in $danger) {
    if ($notes.ToLower().Contains($term)) {
      throw "Unsafe note detected ($term). Refusing to write logs."
    }
  }
}

$cutoff = (Get-Date).ToUniversalTime().AddDays(-$SinceDays)
$files = Get-ChildItem -Path $SessionsRoot -Recurse -Filter "rollout-*.jsonl" -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Length -gt 0 -and $_.LastWriteTimeUtc -ge $cutoff }

if (-not $files) {
  Write-Host "No session files found in the last $SinceDays day(s)."
  exit 0
}

foreach ($file in $files) {
  $sessionCwd = $null
  $sessionId = $null

  foreach ($line in Get-Content -Path $file.FullName) {
    $obj = $null
    try { $obj = $line | ConvertFrom-Json } catch { continue }

    if ($obj.type -eq "session_meta") {
      $sessionCwd = $obj.payload.cwd
      $sessionId = $obj.payload.id
      continue
    }

    $messageText = $null
    if ($obj.type -eq "event_msg" -and $obj.payload.type -eq "agent_message") {
      $messageText = $obj.payload.message
    } elseif ($obj.type -eq "response_item" -and $obj.payload.type -eq "message" -and $obj.payload.role -eq "assistant") {
      $parts = @()
      foreach ($item in $obj.payload.content) {
        if ($item.type -eq "output_text") {
          $parts += $item.text
        }
      }
      if ($parts.Count -gt 0) { $messageText = ($parts -join "`n") }
    }

    $skills = Extract-Skills $messageText
    if (-not $skills -or -not $obj.timestamp) { continue }

    $projectCwd = if ($sessionCwd) { $sessionCwd } else { "" }
    $projectRepoRoot = if ($RepoRootOverride) { $RepoRootOverride } elseif ($projectCwd) { Get-RepoRoot $projectCwd } else { "" }
    $notes = "auto: detected skill usage from session log"
    if ($sessionId) { $notes = "$notes ($sessionId)" }
    Assert-SafeNotes $notes

    foreach ($skill in $skills) {
      $entry = [ordered]@{
        timestamp = $obj.timestamp
        skill_name = $skill
        skill_version = "unknown"
        status = "success"
        notes = $notes
        project_repo_root = $projectRepoRoot
        project_cwd = $projectCwd
      }
      Add-LogEntry -entry $entry -DryRun:$DryRun
    }
  }
}
