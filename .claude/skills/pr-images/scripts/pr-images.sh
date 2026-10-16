#!/usr/bin/env bash
# Upload images for a PR and print markdown that keeps working after the branch is gone.
#
# Usage: pr-images.sh <pr-number> <image>...
#   Run from inside the repo, or set GH_REPO=owner/name.
#
# Files land at pr-<N>/pr-<N>-<slug>.<ext> on a temporary branch pr-images/<N>.
# The commit is pinned by the tag pr-<N>-images (so it is never garbage collected),
# the branch is deleted, and every URL is checked against the commit SHA.
# Re-running for the same PR stacks a new commit on top of the tag, so older links stay valid.
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

[ $# -ge 2 ] || die "usage: $(basename "$0") <pr-number> <image>..."
PR="$1"; shift
[[ "$PR" =~ ^[0-9]+$ ]] || die "PR number must be numeric, got '$PR'"
command -v gh >/dev/null || die "gh is not installed"
command -v jq >/dev/null || die "jq is not installed"

REPO="${GH_REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
gh pr view "$PR" --repo "$REPO" --json number >/dev/null 2>&1 || die "PR #$PR not found in $REPO"

BRANCH="pr-images/$PR"
TAG="pr-$PR-images"
DIR="pr-$PR"
TMP="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP"
  gh api -X DELETE "repos/$REPO/git/refs/heads/$BRANCH" >/dev/null 2>&1 || true
}
trap cleanup EXIT

PARENT="$(gh api "repos/$REPO/git/ref/tags/$TAG" -q .object.sha 2>/dev/null || true)"
BASE_TREE=""
[ -n "$PARENT" ] && BASE_TREE="$(gh api "repos/$REPO/git/commits/$PARENT" -q .tree.sha)"

echo '[]' > "$TMP/entries.json"
PATHS=()
for f in "$@"; do
  [ -f "$f" ] || die "file not found: $f"
  name="$(basename "$f")"
  ext="$(printf '%s' "${name##*.}" | tr '[:upper:]' '[:lower:]')"
  slug="$(printf '%s' "${name%.*}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')"
  path="$DIR/pr-$PR-${slug:-image}.$ext"

  base64 < "$f" | tr -d '\n' > "$TMP/b64"
  blob="$(jq -n --rawfile c "$TMP/b64" '{content: $c, encoding: "base64"}' \
    | gh api -X POST "repos/$REPO/git/blobs" --input - -q .sha)"

  jq --arg p "$path" --arg s "$blob" '. + [{path: $p, mode: "100644", type: "blob", sha: $s}]' \
    "$TMP/entries.json" > "$TMP/e2" && mv "$TMP/e2" "$TMP/entries.json"
  PATHS+=("$path")
done

TREE="$(jq -n --slurpfile e "$TMP/entries.json" --arg b "$BASE_TREE" \
  '{tree: $e[0]} + (if $b == "" then {} else {base_tree: $b} end)' \
  | gh api -X POST "repos/$REPO/git/trees" --input - -q .sha)"

COMMIT="$(jq -n --arg t "$TREE" --arg p "$PARENT" --arg m "Images for #$PR [skip ci]" \
  '{message: $m, tree: $t, parents: (if $p == "" then [] else [$p] end)}' \
  | gh api -X POST "repos/$REPO/git/commits" --input - -q .sha)"

gh api -X POST "repos/$REPO/git/refs" -f ref="refs/heads/$BRANCH" -f sha="$COMMIT" >/dev/null

if [ -n "$PARENT" ]; then
  gh api -X PATCH "repos/$REPO/git/refs/tags/$TAG" -f sha="$COMMIT" -F force=true >/dev/null
else
  gh api -X POST "repos/$REPO/git/refs" -f ref="refs/tags/$TAG" -f sha="$COMMIT" >/dev/null
fi

gh api -X DELETE "repos/$REPO/git/refs/heads/$BRANCH" >/dev/null
gh api "repos/$REPO/git/ref/heads/$BRANCH" >/dev/null 2>&1 && die "branch $BRANCH still exists"
[ "$(gh api "repos/$REPO/git/ref/tags/$TAG" -q .object.sha)" = "$COMMIT" ] || die "tag $TAG does not point at $COMMIT"

for path in "${PATHS[@]}"; do
  gh api "repos/$REPO/contents/$path?ref=$COMMIT" -q .sha >/dev/null 2>&1 || die "$path is not reachable at $COMMIT"
  alt="$(basename "${path%.*}" | sed -E "s/^pr-$PR-//; s/-/ /g")"
  echo "![$alt](https://github.com/$REPO/blob/$COMMIT/$path?raw=true)"
done
