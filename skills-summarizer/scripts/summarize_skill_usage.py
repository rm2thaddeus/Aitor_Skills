import argparse
import json
import os
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(description="Summarize skill usage logs.")
    parser.add_argument("--logs-root", default="logs/skills", help="Logs root dir.")
    parser.add_argument(
        "--output-root",
        default="docs/skill-upkeep",
        help="Output root dir for summaries.",
    )
    parser.add_argument("--days", type=int, default=7, help="Days to include.")
    parser.add_argument(
        "--as-of",
        default="",
        help="UTC date (YYYY-MM-DD) for summary end date. Defaults to today.",
    )
    return parser.parse_args()


def utc_today():
    return datetime.now(timezone.utc).date()


def iter_log_files(logs_root, start_date, end_date):
    current = start_date
    while current <= end_date:
        month_dir = current.strftime("%Y-%m")
        day_file = current.strftime("skill-usage-%Y-%m-%d.jsonl")
        path = Path(logs_root) / month_dir / day_file
        if path.exists():
            yield path
        current += timedelta(days=1)


def load_entries(paths):
    entries = []
    errors = 0
    for path in paths:
        with path.open("r", encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                try:
                    data = json.loads(line)
                    entries.append(data)
                except json.JSONDecodeError:
                    errors += 1
    return entries, errors


def summarize(entries, start_date, end_date):
    total = len(entries)
    status_counts = Counter()
    skill_counts = Counter()
    skill_status = defaultdict(Counter)
    projects = Counter()

    for entry in entries:
        status = entry.get("status", "unknown")
        skill = entry.get("skill_name", "unknown")
        repo_root = entry.get("project_repo_root") or "unknown"
        status_counts[status] += 1
        skill_counts[skill] += 1
        skill_status[skill][status] += 1
        projects[repo_root] += 1

    top_skills = skill_counts.most_common(10)
    top_projects = projects.most_common(5)

    return {
        "range": {
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            "days": (end_date - start_date).days + 1,
        },
        "totals": {
            "invocations": total,
            "status_counts": dict(status_counts),
            "unique_skills": len(skill_counts),
            "unique_projects": len(projects),
        },
        "top_skills": [
            {
                "skill_name": name,
                "count": count,
                "status_counts": dict(skill_status[name]),
            }
            for name, count in top_skills
        ],
        "top_projects": [
            {"project_repo_root": name, "count": count}
            for name, count in top_projects
        ],
    }


def render_html(summary, errors):
    totals = summary["totals"]
    top_skills = summary["top_skills"]
    top_projects = summary["top_projects"]
    range_info = summary["range"]
    status_counts = totals.get("status_counts", {})

    def render_list(items, formatter):
        if not items:
            return "<p>No data.</p>"
        return "<ul>" + "".join(formatter(item) for item in items) + "</ul>"

    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Skill Usage Summary</title>
  <style>
    :root {{
      --bg: #f6f2ea;
      --card: #fffdf8;
      --ink: #1b1b1b;
      --accent: #2f6f3f;
      --muted: #6b6b6b;
      --border: #e4d9c8;
    }}
    body {{
      margin: 0;
      font-family: "Georgia", "Times New Roman", serif;
      background: radial-gradient(circle at 10% 10%, #efe6d7, var(--bg));
      color: var(--ink);
    }}
    main {{
      max-width: 980px;
      margin: 32px auto;
      padding: 0 20px 40px;
    }}
    h1 {{
      font-size: 2.2rem;
      margin-bottom: 8px;
    }}
    .subtitle {{
      color: var(--muted);
      margin-bottom: 24px;
    }}
    .grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
      gap: 16px;
    }}
    .card {{
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 16px;
      box-shadow: 0 10px 20px rgba(0, 0, 0, 0.06);
    }}
    .card h2 {{
      font-size: 1.1rem;
      margin: 0 0 8px;
    }}
    .stat {{
      font-size: 1.8rem;
      color: var(--accent);
      font-weight: bold;
    }}
    ul {{
      margin: 8px 0 0;
      padding-left: 18px;
    }}
    li {{
      margin-bottom: 4px;
    }}
    .footer {{
      margin-top: 24px;
      color: var(--muted);
      font-size: 0.9rem;
    }}
  </style>
</head>
<body>
  <main>
    <h1>Skill Usage Summary</h1>
    <div class="subtitle">Range: {range_info["start_date"]} to {range_info["end_date"]} ({range_info["days"]} days)</div>
    <div class="grid">
      <div class="card">
        <h2>Total Invocations</h2>
        <div class="stat">{totals["invocations"]}</div>
      </div>
      <div class="card">
        <h2>Unique Skills</h2>
        <div class="stat">{totals["unique_skills"]}</div>
      </div>
      <div class="card">
        <h2>Unique Projects</h2>
        <div class="stat">{totals["unique_projects"]}</div>
      </div>
      <div class="card">
        <h2>Status Breakdown</h2>
        {render_list(status_counts.items(), lambda i: f"<li>{i[0]}: {i[1]}</li>")}
      </div>
    </div>
    <div class="grid" style="margin-top: 18px;">
      <div class="card">
        <h2>Top Skills</h2>
        {render_list(top_skills, lambda i: f"<li>{i['skill_name']}: {i['count']}</li>")}
      </div>
      <div class="card">
        <h2>Top Projects</h2>
        {render_list(top_projects, lambda i: f"<li>{i['project_repo_root']}: {i['count']}</li>")}
      </div>
      <div class="card">
        <h2>Parsing Notes</h2>
        <p>Invalid log lines skipped: {errors}</p>
      </div>
    </div>
    <div class="footer">Metadata only. No prompts or user content captured.</div>
  </main>
</body>
</html>
"""


def main():
    args = parse_args()
    as_of = utc_today() if not args.as_of else datetime.strptime(args.as_of, "%Y-%m-%d").date()
    days = max(args.days, 1)
    end_date = as_of
    start_date = end_date - timedelta(days=days - 1)

    log_paths = list(iter_log_files(args.logs_root, start_date, end_date))
    entries, errors = load_entries(log_paths)
    summary = summarize(entries, start_date, end_date)

    output_month = end_date.strftime("%Y-%m")
    output_dir = Path(args.output_root) / output_month
    output_dir.mkdir(parents=True, exist_ok=True)

    output_date = end_date.strftime("%Y-%m-%d")
    json_path = output_dir / f"summary-{output_date}.json"
    html_path = output_dir / f"summary-{output_date}.html"

    with json_path.open("w", encoding="utf-8") as handle:
        json.dump(summary, handle, indent=2, sort_keys=True)

    html = render_html(summary, errors)
    with html_path.open("w", encoding="utf-8") as handle:
        handle.write(html)

    print(json_path)
    print(html_path)


if __name__ == "__main__":
    main()
