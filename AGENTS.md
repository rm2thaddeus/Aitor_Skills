# Agents Guide (Skills Repo)

This repo is a living library of agent skills (each skill lives in a `<skill-name>/SKILL.md` folder). This file tells agents how to work inside this repo so collaboration stays seamless and the skills improve over time.

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
