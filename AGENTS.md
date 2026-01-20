# Agents Guide (Skills Repo)

This repo is a living library of agent skills (each skill lives in a `<skill-name>/SKILL.md` folder). This file tells agents how to work inside this repo so collaboration stays seamless and the skills improve over time.

> ## NON-NEGOTIABLE: LOG EVERY SKILL INVOCATION
> If skill usage is not logged, the feedback loop breaks. Logging is mandatory for every skill invocation in this repo.
>
> **Do this every time:** ensure session-derived logs are generated via
> `scripts/backfill-skill-usage-from-sessions.ps1`. Use
> `scripts/log-skill-usage.ps1` only as a fallback if extraction is blocked.
>
> **Never skip it.** If logging fails, say so in the response and continue.

## Goals

- Make agent-user collaboration feel seamless and low-friction.
- Treat skill usage as an opportunity to improve the library over time.
- Keep changes auditable via git history (branch + merge to `main`).

## Scope

Applies to all files under `C:/Users/aitor/.codex/skills`, including:

- `*/SKILL.md`
- supporting `assets/`, `scripts/`, and docs inside the repo

## How To Use Skills (Behavior Rules)

- **Follow skill trigger rules**: if a skill is named, or the request clearly matches a skill, use it.
- **Prefer the skill's workflow over improvisation**; only deviate when blocked, then record a polish candidate.
- **Ask one question at a time** when a skill instructs that (common for design/brainstorming workflows).
- **Be explicit about permission points** before proposing or performing git changes.

## Skill Usage Tracking (JSONL)

This repo uses session-derived usage logging to keep a lightweight, diffable record of skill usage without storing prompts or user data.

> ### STOP: Logging is part of the task, not optional
> If you are about to respond and have not logged the skill, **you are not done**.
>
> **Mandatory micro-checklist (do not skip):**
> - [ ] Identify the skill invoked.
> - [ ] Ensure extraction is scheduled via `scripts/backfill-skill-usage-from-sessions.ps1`.
> - [ ] If extraction is blocked, run `scripts/log-skill-usage.ps1` with metadata only.
> - [ ] If logging fails, say so in the response and proceed.

### Where To Log

Write one JSONL line per skill invocation to:

`logs/skills/YYYY-MM/skill-usage-YYYY-MM-DD.jsonl`

Create the directory path if it does not exist.

Canonical extractor: `scripts/backfill-skill-usage-from-sessions.ps1`

Fallback (manual): `scripts/log-skill-usage.ps1`

### Auto-Backfill (Session Logs)

If manual logging is missed, use the session log backfill script:

- `scripts/backfill-skill-usage-from-sessions.ps1`

This script **only extracts skill names** from assistant messages that follow the
`Using \`<skill>\`` pattern and writes metadata-only entries. It must not write
user text, prompts, file contents, or secrets.

### Schema Migration (Legacy Logs)

If legacy logs exist, normalize them to the session-derived schema with:

- `scripts/migrate-skill-logs-to-session-schema.ps1`

### Data Hygiene (Non-Negotiable)

Before writing any log entry, ensure:

- **No prompts or user text** (ever).
- **No file contents** (even small snippets).
- **No secrets or credentials** (API keys, tokens, passwords).
- **Notes are generic** (metadata-only; keep them short).

### Required Fields (Session-Derived Schema)

- `timestamp`: ISO 8601 UTC timestamp (example: `2026-01-17T18:24:03Z`).
- `session_id`: session identifier from Codex session logs.
- `event_index`: integer sequence within the session file.
- `skill_name`: skill name as invoked.
- `skill_version`: from SKILL.md front matter when present, otherwise `unknown`.
- `status`: `success`, `failure`, or `retries`.
- `source`: `codex_session_log`.
- `event_type`: log event type (`event_msg` or `response_item`).
- `notes`: short, safe metadata only; no user text, file contents, secrets, or PII.
- `project_repo_root`: nearest git repo root if detected, otherwise `null`.
- `project_cwd`: current working directory.
- `cli_originator`: CLI originator from session meta (if present).
- `cli_version`: CLI version from session meta (if present).

### Operational Rules

- Log immediately before responding, or immediately after if the response must be first.
- Do not log prompts, outputs, or any user-provided text.
- If logging fails (e.g., file system error), say so in the response and continue.

### Example JSONL Entry

{"timestamp":"2026-01-17T18:24:03Z","session_id":"019bcc90-64b0-78d3-9b36-dec0d5e5f3ab","event_index":120,"skill_name":"doc-coauthoring","skill_version":"unknown","status":"success","source":"codex_session_log","event_type":"event_msg","notes":"auto: extracted from codex session logs","project_repo_root":"C:/Users/aitor/.codex/skills","project_cwd":"C:/Users/aitor/.codex/skills","cli_originator":"codex_cli_rs","cli_version":"0.87.0"}

## Telemetry-to-Improvement Chain (Handoff Contract)

This repo assumes a strict information chain so summaries and updates stay auditable.

### Flow

1) Logs capture metadata-only usage.
2) Summarizer produces an overview + review prompts.
3) Updater consumes the summary to produce insights and proposals.

### Required Summary Fields (JSON)

Summaries written to `docs/skill-upkeep/YYYY-MM/summary-YYYY-MM-DD.json` must include:

- `summary_date`: ISO 8601 date.
- `window_days`: integer (e.g., 7).
- `totals`: counts for `invocations`, `success`, `failure`, `retries`.
- `by_skill`: array with `skill_name`, `count`, `success_rate`, `top_notes`.
- `by_repo`: array with `project_repo_root`, `skill_counts`, `notes`.
- `review_prompts`: 3-7 questions for human-in-loop review.
- `candidate_actions`: optional list of potential improvements (no edits implied).

### Updater Output Contract

When using the summary, the updater must return:

- **Insights report**: short narrative of usage patterns, gaps, and overlap.
- **Proposals** (if any): each with `why`, `where it helps`, `risk`, `test`.

## Skill Polish Loop (Proactive Improvement)

### Intent

Skills are not static. When a skill doesn't work well for this user, the agent treats that as input to improve the skill so the next run is more seamless.

### What Counts As A "Skill Gap"

Capture a "polish candidate" when any of the following happens while a skill is in use:

- **Failure**: the skill instructions lead to an error, dead-end, missing prerequisite, wrong path, or incompatible tooling.
- **User correction**: the user says the agent misunderstood intent, or restates the request in a way that implies the skill should have guided it better.
- **Repeated nudge**: the user asks for the same extra behavior 2+ times in the same session (e.g. “also do X every time”).
- **Improvisation**: the agent has to go outside the skill to succeed (ad-hoc steps, missing checks, missing decision points).
- **Friction**: the skill technically works but causes avoidable back-and-forth (too many questions, unclear exits, poor defaults).

### How To Track Polish Candidates (During The Session)

Maintain an in-memory list named **Skill polish candidates**. Each entry is a single bullet:

- `<skill-name>`: 1 sentence "gap", 1 sentence "proposed fix" (include file path(s) when obvious).

Do not interrupt the main task to edit skills mid-flight unless the user explicitly asks to stop and refactor the skill now.
Use the `skills-updater` skill to execute approved polish changes.
Use the `skills-summarizer` skill to digest usage logs and propose upkeep.

### How To Propose Skill Updates (Final Message)

At the end of the session, include a short checklist titled **Skill polish candidates**. Keep it terse:

- `[ ] <skill-name>` - proposed change summary (files: `...`)

Then explicitly ask permission to:

1) create a branch named `skill-polish/<yyyy-mm-dd>` (optionally with a short suffix),
2) implement the edits,
3) commit, and
4) push the branch to origin.

If permission is not granted, keep the checklist so the user can approve later.

## Permissioned Git Workflow (Branch -> Commit -> Push)

### Rule: Ask First

Any time the agent wants to change this repo (including polishing skills), it must ask permission before doing git actions that affect the remote:

- creating/pushing branches
- pushing `main`

### Branch Requirement For Skills

Any change under a skill folder (for example: `*/SKILL.md`, `*/scripts/**`, `*/references/**`, `*/assets/**`) must go through a branch.
Do not push skill changes directly to `main` unless the user explicitly requests it for that specific change.

### Fast Path For Repo-Doc Changes (No Branch)

If the change is only repo meta / documentation (for example: `AGENTS.md`, `README.md`, or `docs/**`) and the user asks to "commit and push", prefer the simplest flow:

1) commit directly on `main`
2) push `main`

Still ask permission before the push.

### Default Flow For Skill Polishing

When the user grants permission to apply "Skill polish candidates":

1) **Create a single branch** for all polish changes made in the session: `skill-polish/<yyyy-mm-dd>` (or a short topic suffix).
2) **Make the edits** (update `SKILL.md`, scripts, READMEs, etc.).
3) **Commit with a conventional message** (example: `chore(skills): polish skill workflows`).
4) **Push the branch** to origin.
5) **Provide PR-ready notes** in the final message: a short "why" and a short "what changed" list (the user can paste into a PR).
6) **Merge into `main` only after explicit permission** (keep history via the merge commit / PR link).

### Tooling Convention

If using the `git-pushing` skill, prefer the repo-local script:

- `bash git-pushing/scripts/smart_commit.sh "chore(skills): polish skill workflows"`

If bash is not available in the environment, ask the user whether to proceed with manual `git` commands.

## Quality Bar

- Updates should reduce user friction in the next run (fewer clarifications, fewer dead-ends).
- Prefer small, local changes to the relevant skill over repo-wide rewrites.
- Keep skill instructions action-oriented, environment-aware, and easy to follow.

## "Seamless Collaboration" Definition

- The agent reliably infers when to use a skill, asks minimal clarifying questions, and avoids repeating mistakes across sessions by polishing skills when gaps are found.
