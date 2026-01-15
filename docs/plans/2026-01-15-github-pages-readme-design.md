# GitHub Pages README Rendering Design

## Overview

This design enables GitHub Pages to render the existing `README.md` as a standalone landing page while keeping the README as the single source of truth. The approach uses a lightweight Jekyll include and a minimal `docs/` site so the repo page remains unchanged and the Pages site is clean and focused.

## Architecture

The Pages site is served from `docs/`. The entry point is `docs/index.md`, which contains Jekyll front matter and an `{% include_relative ../README.md %}` directive. This inlines the root README at build time. Because the README references `assets/hero.svg`, the hero asset is duplicated into `docs/assets/hero.svg` so relative paths resolve in the Pages site. No additional layouts, themes, or build tooling are required.

## Components

- `docs/index.md`: Jekyll entry point, includes root README.
- `README.md`: primary content source for both repo and Pages.
- `docs/assets/hero.svg`: asset mirror for GitHub Pages rendering.

## Data Flow

At build time, GitHub Pages runs Jekyll on `docs/index.md`, which pulls in `../README.md`. The README content is inserted into the generated HTML, and the hero image is loaded from `docs/assets/hero.svg`. The repo view continues to render `README.md` directly.

## Error Handling

If the Pages build fails, the repo README is still unaffected. If the hero asset path is incorrect, the page will render without the hero while the rest of the README remains visible. These failures are visible in GitHub Pages build logs.

## Testing

Validate by enabling Pages in the repo settings and loading the generated Pages URL. Confirm the hero image renders and the README content matches the repo view. Optionally, verify in a local Markdown previewer that the README still renders cleanly.
