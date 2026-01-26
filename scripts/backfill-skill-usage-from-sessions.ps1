param(
  [string]$SessionsRoot = "$env:USERPROFILE\\.codex\\sessions",
  [int]$SinceDays = 7,
  [string]$RepoRootOverride = '',
  [string]$OutputRoot = "$PSScriptRoot\\..\\logs\\skills",
  [switch]$Rewrite,
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
  $logDir = [IO.Path]::GetFullPath((Join-Path -Path $OutputRoot -ChildPath $month))
  New-Item -ItemType Directory -Force -Path $logDir | Out-Null
  return Join-Path -Path $logDir -ChildPath "skill-usage-$day.jsonl"
}

function Add-LogEntry($entry, [switch]$DryRun) {
  $entryJson = $entry | ConvertTo-Json -Compress
  $ts = [DateTime]::Parse($entry.timestamp).ToUniversalTime()
  $logFile = Get-LogPath -UtcTime $ts
  $entryKey = "$($entry.session_id)|$($entry.timestamp)|$($entry.skill_name)"
  $dateKey = $ts.ToString('yyyy-MM-dd')

  if ($script:SeenKeys.ContainsKey($entryKey)) {
    return
  }
  $script:SeenKeys[$entryKey] = $true

  if ($Rewrite -and -not $script:ClearedDates.ContainsKey($dateKey)) {
    if (-not $DryRun) {
      Clear-Content -Path $logFile -ErrorAction SilentlyContinue
    }
    $script:ClearedDates[$dateKey] = $true
  }

  if (Test-Path $logFile) {
    $existing = Get-Content -Path $logFile -ErrorAction SilentlyContinue
    $key = '"timestamp":"' + $entry.timestamp + '"'
    $nameKey = '"skill_name":"' + $entry.skill_name + '"'
    $sessionKey = if ($entry.session_id) { '"session_id":"' + $entry.session_id + '"' } else { "" }
    if (
      $existing -match [regex]::Escape($key) -and
      $existing -match [regex]::Escape($nameKey) -and
      (-not $sessionKey -or $existing -match [regex]::Escape($sessionKey))
    ) {
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

  if (-not $script:KnownSkills) {
    return $skills
  }

  $filtered = @()
  foreach ($skill in $skills) {
    if ($script:KnownSkills.Contains($skill)) {
      $filtered += $skill
    }
  }
  return $filtered
}

function Assert-SafeNotes([string]$notes) {
  if (-not $notes) { return }
  $danger = @("api", "token", "secret", "password", "passwd", "key=", "bearer", "oauth", "auth", "cookie")
  foreach ($term in $danger) {
    if ($notes.ToLower().Contains($term)) {
      throw "Unsafe note detected ($term). Refusing to write logs."
    }
  }
}

$cutoff = (Get-Date).ToUniversalTime().AddDays(-$SinceDays)
$script:SeenKeys = @{}
$script:ClearedDates = @{}

# Build a catalog of known skills so we don't log arbitrary backticked text.
try {
  $skillsRepoRoot = [IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath ".."))
  $script:KnownSkills = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  Get-ChildItem -Path $skillsRepoRoot -Recurse -Filter "SKILL.md" -File -ErrorAction SilentlyContinue | ForEach-Object {
    [void]$script:KnownSkills.Add($_.Directory.Name)
  }
} catch {
  $script:KnownSkills = $null
}

$files = Get-ChildItem -Path $SessionsRoot -Recurse -Filter "rollout-*.jsonl" -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Length -gt 0 -and $_.LastWriteTimeUtc -ge $cutoff }

if (-not $files) {
  Write-Host "No session files found in the last $SinceDays day(s)."
  exit 0
}

foreach ($file in $files) {
  $sessionCwd = $null
  $sessionId = $null
  $sessionOriginator = $null
  $sessionCliVersion = $null
  $eventIndex = 0

  foreach ($line in Get-Content -Path $file.FullName) {
    $eventIndex += 1
    $obj = $null
    try { $obj = $line | ConvertFrom-Json } catch { continue }

    if ($obj.type -eq "session_meta") {
      $sessionCwd = $obj.payload.cwd
      $sessionId = $obj.payload.id
      $sessionOriginator = $obj.payload.originator
      $sessionCliVersion = $obj.payload.cli_version
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
    $notes = "auto: extracted from codex session logs"
    Assert-SafeNotes $notes

    $timestamp = [DateTime]::Parse($obj.timestamp).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

    foreach ($skill in $skills) {
      $entry = [ordered]@{
        timestamp = $timestamp
        session_id = $sessionId
        event_index = $eventIndex
        skill_name = $skill
        skill_version = "unknown"
        status = "success"
        source = "codex_session_log"
        event_type = $obj.type
        notes = $notes
        project_repo_root = $projectRepoRoot
        project_cwd = $projectCwd
        cli_originator = $sessionOriginator
        cli_version = $sessionCliVersion
      }
      Add-LogEntry -entry $entry -DryRun:$DryRun
    }
  }
}
