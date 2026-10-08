---
name: bump-extension-version
description: Bumps the "version" field in manifest.json after any change to the Chrome extension's files (manifest.json, background.js, popup.html, popup.js, icons). Use whenever extension code is edited, or when the user says "bump version", "new release", or "update version".
---

# Bump Extension Version

After editing any extension file, bump `version` in `manifest.json` at most once per commit. The user commits outside the chat, so never rely on memory of earlier bumps — run this every time before deciding:

```bash
git show HEAD:manifest.json | rg '"version"'; rg '"version"' manifest.json
```

- **Same version** → the last commit already shipped it: bump.
- **Different version** → uncommitted work already has its bump: don't bump again (unless it now needs a bigger one, e.g. patch → minor).

Chrome versions are 1–4 dot-separated integers (e.g. `1.0`, `1.2.3`). Use `MAJOR.MINOR.PATCH`:

- **Patch** (default): bug fixes, tweaks, refactors → `1.0.0` → `1.0.1`
- **Minor**: new user-visible feature or option → `1.0.1` → `1.1.0`
- **Major**: only when the user asks.

If the current version has fewer than 3 parts, pad with zeros first (`1.0` → `1.0.0`), then bump.

Mention the new version in one line of the reply, e.g. `Version: 1.0.1 → 1.0.2`.
