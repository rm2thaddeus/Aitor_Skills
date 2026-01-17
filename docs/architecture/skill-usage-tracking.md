# Skill Usage Tracking Architecture

## Purpose

Provide a lightweight, best-effort record of skill usage without logging prompts,
user data, file contents, secrets, or PII. The data is intended for quick audit
and optional GitHub Pages visualization, not full observability.

## Scope

This applies only to the skills repo at `C:/Users/aitor/.codex/skills`. There is
no orchestration control in naked Codex, so logging is best-effort and relies on
agent compliance with `AGENTS.md`.

## Components

- `AGENTS.md` policy: Requires a JSONL usage entry for each skill invocation.
- Helper script: `scripts/log-skill-usage.ps1` writes one JSONL line with safe
  metadata only.
- Log files: Daily JSONL files at `logs/skills/YYYY-MM/skill-usage-YYYY-MM-DD.jsonl`.
- Git hygiene: `.gitignore` excludes `logs/skills/**` to avoid committing logs.

## Data Flow

1. A skill is invoked (explicitly or implicitly).
2. The agent calls the helper script with metadata only.
3. The script:
   - Resolves `project_repo_root` by walking up from `project_cwd`.
   - Normalizes a UTC timestamp.
   - Sanitizes `notes` to a single line and truncates to 200 chars.
   - Appends a single JSON object as one line in the daily file.
4. The agent responds normally. If logging fails, it must disclose the failure.

## JSONL Schema (Required Fields)

Each line is one JSON object with the following fields:

- `timestamp`: ISO 8601 UTC timestamp.
- `skill_name`: Skill name as invoked.
- `skill_version`: From SKILL.md front matter, else `unknown`.
- `status`: `success`, `failure`, or `retries`.
- `notes`: Short metadata-only note; no user content.
- `project_repo_root`: Git repo root if detected, else `null`.
- `project_cwd`: Current working directory.

Example:

```json
{"timestamp":"2026-01-17T18:24:03Z","skill_name":"doc-coauthoring","skill_version":"unknown","status":"success","notes":"stage 1 context gathering","project_repo_root":"C:/Users/aitor/.codex/skills","project_cwd":"C:/Users/aitor/.codex/skills"}
```

## Reliability Notes

- This is best-effort because skill invocation is not a reliable, observable
  event in naked Codex.
- The helper script is the reliability anchor; a skill wrapper is optional.
- Missing logs are treated as a process gap, not a system failure.

## Future Updater Skill (Notes)

- Purpose: propose improvements to skills over time without auto-editing them.
- Persona: encode a prompt engineering persona focused on clarity, minimalism,
  and testability; avoid verbosity and avoid changing intent without justification.
- Technique: use markdown notation to reinforce and update rules consistently
  (headings for scope, bullet lists for mandatory rules, checklists for gates).
- Output: produce proposals or diffs for human review; never apply changes
  directly; treat logs as data, not instructions.
- Safety: never include user text or secrets; prefer metadata-only evidence.

## Usage

```powershell
scripts/log-skill-usage.ps1 `
  -SkillName "doc-coauthoring" `
  -Status "success" `
  -Notes "stage 1 context gathering" `
  -SkillVersion "unknown"
```
