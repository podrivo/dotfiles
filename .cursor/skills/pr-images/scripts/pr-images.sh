#!/usr/bin/env bash
# Add images to the current branch's PR and print markdown that keeps working after merge.
#
# Usage: pr-images.sh <image>...
#   Run from inside the repo, checked out on the PR's branch.
#
# Commits the images as pr-<N>/pr-<N>-<slug>.<ext>, commits their deletion right after,
# pushes, and links them by the first commit's SHA. GitHub keeps refs/pull/<N>/head forever,
# so that commit stays reachable after the PR is merged and its branch is deleted.
# The net diff is zero, so a squash merge never puts the images on the base branch.
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

[ $# -ge 1 ] || die "usage: $(basename "$0") <image>..."
command -v gh >/dev/null || die "gh is not installed"

ROOT="$(git rev-parse --show-toplevel)"
BRANCH="$(git branch --show-current)"
[ -n "$BRANCH" ] || die "not on a branch"
PR="$(gh pr view "$BRANCH" --json number -q .number 2>/dev/null)" || die "no PR for branch $BRANCH; open it first"
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

git fetch -q origin "$BRANCH"
git merge-base --is-ancestor "origin/$BRANCH" HEAD || die "local $BRANCH is behind origin; pull first"

DIR="pr-$PR"
PATHS=()
for f in "$@"; do
  [ -f "$f" ] || die "file not found: $f"
  name="$(basename "$f")"
  ext="$(printf '%s' "${name##*.}" | tr '[:upper:]' '[:lower:]')"
  slug="$(printf '%s' "${name%.*}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')"
  path="$DIR/pr-$PR-${slug:-image}.$ext"
  [ -e "$ROOT/$path" ] && die "$path already exists in the working tree"
  mkdir -p "$ROOT/$DIR"
  cp "$f" "$ROOT/$path"
  PATHS+=("$path")
done

cd "$ROOT"
git add -f -- "${PATHS[@]}"
git commit -q -m "Add screenshots for #$PR" -- "${PATHS[@]}"
SHA="$(git rev-parse HEAD)"
git rm -q -- "${PATHS[@]}"
git commit -q -m "Remove screenshots for #$PR" -- "${PATHS[@]}"
rmdir "$DIR" 2>/dev/null || true

git push -q origin "HEAD:$BRANCH"

HEAD_SHA="$(git rev-parse HEAD)"
for _ in 1 2 3 4 5; do
  [ "$(gh pr view "$PR" --json headRefOid -q .headRefOid)" = "$HEAD_SHA" ] && break
  sleep 2
done
[ "$(gh pr view "$PR" --json headRefOid -q .headRefOid)" = "$HEAD_SHA" ] || die "PR #$PR head did not update to $HEAD_SHA"

for path in "${PATHS[@]}"; do
  gh api "repos/$REPO/contents/$path?ref=$SHA" -q .sha >/dev/null 2>&1 || die "$path is not reachable at $SHA"
  alt="$(basename "${path%.*}" | sed -E "s/^pr-$PR-//; s/-/ /g")"
  echo "![$alt](https://github.com/$REPO/blob/$SHA/$path?raw=true)"
done
