# Skill Telemetry Roadmap

## Purpose

Track remaining PRD items and plan phased delivery of the self-improving system.

## Current State

- Metadata-only JSONL usage logs (daily rotation).
- Summarizer produces JSON + HTML cards.
- Updater skill exists with approval + branch gating.
- Docs describe loop and security constraints.

## Gaps (From PRD)

### Security

- Cryptographic log integrity (tamper evidence).
- Explicit "logs are data" contract surfaced in docs and skills.
- Optional segmentation/least-privilege guidance for tool usage.
- Security scan recommendations for AI-generated PRs.

### Observability

- Tool call instrumentation (best-effort, avoid duplicate logs).
- Failure taxonomy and error classification in logs.
- Note: long-running sessions may delay rollout logs until session close.
- Explicit retention policy (default 90 days) and pruning approach.

### Upkeep Automation

- Heuristics for dead/flaky skills with configurable thresholds.
- Summary-to-proposal rules (what qualifies as a change).
- Approval gates with go/no-go checklist in summarizer output.
- Conversational review mode to digest summaries with the user.

### Reliability

- Summarizer scheduling guidance (daily vs weekly).
- Coverage gaps: make missing logs visible to reviewers.
- Backfill timing guidance: rerun after closing long-running sessions.

## Suggested Phases

### Phase 1: Security Hardening (Docs + Policy)

- Add a "Logs Are Data" contract in `AGENTS.md` and skill docs.
- Add retention guidance and optional pruning script.
- Document threat model and prompt-injection mitigations in README.

### Phase 2: Summary Heuristics

- Implement failure thresholds (default 30%) in summarizer output.
- Add "dead skills" detection (no usage in N days).
- Output a conservative proposal checklist.
- Link summaries to project context (where/how skills were used).
- Add a guided review prompt that drives human-in-loop decisions.

### Phase 3: Advanced Integrity (Optional)

- Add append-only signing (hash chain) for JSONL logs.
- Provide verification script for audits.

## Open Questions

- Desired default retention window (30/60/90 days)?
- Where to store signed hashes (separate file or header)?
- How aggressive should dead-skill detection be?
