# Skills Summarizer Concept

## Purpose

Digest JSONL usage logs into daily JSON summaries and HTML cards for quick
review, then propose conservative upkeep actions with human approval.

## Outputs

- `docs/skill-upkeep/YYYY-MM/summary-YYYY-MM-DD.json`
- `docs/skill-upkeep/YYYY-MM/summary-YYYY-MM-DD.html`

## Data Sources

- Usage logs: `logs/skills/YYYY-MM/skill-usage-YYYY-MM-DD.jsonl`
- Repo rules: `AGENTS.md`

## Constraints

- Metadata only; no prompts, user text, file contents, or PII.
- Proposals must be conservative and reviewable.
- No edits without explicit go/no-go.
