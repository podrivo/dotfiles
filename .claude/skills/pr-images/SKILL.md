---
name: pr-images
description: Adds images and screenshots to GitHub pull requests by committing them to the PR's own branch, deleting them in the next commit, and linking them by commit SHA so they keep working after merge, with PR-numbered file names and no extra branches or tags. Use whenever adding, attaching, uploading, or embedding images, screenshots, or visual proof in a PR description or PR comment, or when tempted to create a branch just to host images.
---

# PR images

Never create branches or tags to host PR images. Always use `scripts/pr-images.sh` from this skill's directory, run from inside the repo while checked out on the PR's branch:

```bash
<this-skill-dir>/scripts/pr-images.sh <image>...
```

The PR must exist first; open it, then upload.

## What the script does

- **Naming:** each file is committed as `pr-<N>/pr-<N>-<slug>.<ext>`, with `<N>` read from the current branch's PR.
- **Add, then delete:** one commit adds the images and the next removes them, so the PR's net diff is zero and a squash merge never puts them on the base branch.
- **Links keep working:** URLs use the SHA of the commit that added the images. GitHub keeps `refs/pull/<N>/head` forever, and that commit is in its history, so it is never garbage collected, even after the branch is deleted on merge.
- **Checks:** it pushes, waits until the PR head matches, and checks every file is reachable at the SHA.

It prints one markdown line per image, for example:

```markdown
![billing tabs](https://github.com/owner/repo/blob/<sha>/pr-1234/pr-1234-billing-tabs.png?raw=true)
```

## Rules

1. **Upload with real code changes.** Commit the code first and run the script before pushing, so code and screenshots go up in a single push and CI and Vercel run once. Never add `[skip ci]`: required checks would not run on the PR head.
2. **Never rebase or force-push the branch after uploading.** That rewrites the screenshot commit's SHA and its links eventually 404. Update the branch by merging the base branch instead. If a rebase is unavoidable, re-run the script afterwards and replace every old link.
3. **Name files descriptively before uploading** (`billing-tabs-dark.png`, not `Screenshot 2026-10-16 at 19.02.png`); the name becomes the slug and alt text.
4. **Attach the links:** put the printed lines where they belong in the body and update it with `gh pr edit <N> --body-file <file>` (keep the existing content), or post them with `gh pr comment <N> --body-file <file>`. Use the URLs exactly as printed: no `raw.githubusercontent.com` links (they break in private repos) and no branch-name URLs.

## Check existing links

To confirm a linked SHA is still in the PR's history (for example after someone else touched the branch):

```bash
gh api repos/<owner>/<repo>/compare/<sha>...<pr-head-sha> -q .status
```

`ahead` or `identical` means the link is safe; `diverged` means the commit was rewritten, so re-run the script and replace the links.
