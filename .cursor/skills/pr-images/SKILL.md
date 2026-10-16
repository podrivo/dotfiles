---
name: pr-images
description: Adds images and screenshots to GitHub pull requests with gh, using PR-numbered file names, a temporary branch that is always deleted, and a tag that keeps the links working forever. Use whenever adding, attaching, uploading, or embedding images, screenshots, or visual proof in a PR description or PR comment, or when tempted to create a branch just to host images.
---

# PR images

Never create branches by hand to host PR images, and never leave image branches behind. Always use `scripts/pr-images.sh` from this skill's directory, run from inside the repo (or with `GH_REPO=owner/name`):

```bash
<this-skill-dir>/scripts/pr-images.sh <pr-number> <image>...
```

The PR must exist first; open it, then upload.

## What the script guarantees

- **Naming:** each file is stored at `pr-<N>/pr-<N>-<slug>.<ext>`, uploaded through the temporary branch `pr-images/<N>`.
- **Branch deleted:** the branch is removed at the end, including when the script fails, and the script checks that it's gone.
- **Links keep working:** the commit is pinned by the tag `pr-<N>-images`, so GitHub never garbage-collects it, and every URL uses the commit SHA, never a branch name. The script checks each file is reachable at that SHA after the branch is deleted.
- **Re-runs are safe:** a second run for the same PR stacks a new commit on top of the tag, so earlier links stay valid.
- The commit message carries `[skip ci]` so no workflow runs on it.

It prints one markdown line per image, for example:

```markdown
![billing tabs](https://github.com/owner/repo/blob/<sha>/pr-1234/pr-1234-billing-tabs.png?raw=true)
```

## Attaching to the PR

1. Name source files descriptively before uploading (`billing-tabs-dark.png`, not `Screenshot 2026-10-16 at 19.02.png`), since the name becomes the slug and alt text.
2. Put the printed lines where they belong in the body, then update it with `gh pr edit <N> --body-file <file>`, or post them with `gh pr comment <N> --body-file <file>`. Keep the existing body content.
3. Use the URLs exactly as printed: no `raw.githubusercontent.com` links (they break in private repos) and no branch-name URLs.

## Cleanup

To drop a PR's images entirely (for example after deleting a PR): `gh api -X DELETE repos/<owner>/<repo>/git/refs/tags/pr-<N>-images`. Their links stop resolving once GitHub prunes the commit.
