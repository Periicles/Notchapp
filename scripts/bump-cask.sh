#!/usr/bin/env bash
# Bumps the notchbar cask in the Homebrew tap to a published release, as an
# auto-merging pull request.
#
# Usage: bump-cask.sh VERSION TAP_DIR [--dry-run]
#   VERSION   the released version, without the leading v (e.g. 0.4.0)
#   TAP_DIR   a checkout of Periicles/homebrew-tap
#   --dry-run rewrite the cask and print the diff, then stop before any push
#
# The sha256 is computed from the .dmg attached to the GitHub release, not from
# a local build: it has to match the exact bytes Homebrew will download.
#
# Pushing needs a token with contents, pull-requests and issues write access on
# the tap (CI passes TAP_TOKEN); `gh` reads it from GH_TOKEN.
set -euo pipefail

TAP_REPO="Periicles/homebrew-tap"
CASK_PATH="Casks/notchbar.rb"
DMG_URL_BASE="https://github.com/Periicles/Notchapp/releases/download"

VERSION="${1:-}"
TAP_DIR="${2:-}"
DRY_RUN=""
[ "${3:-}" = "--dry-run" ] && DRY_RUN=1

if [ -z "$VERSION" ] || [ -z "$TAP_DIR" ]; then
  sed -n '2,12p' "$0" >&2
  exit 2
fi
if ! [[ "$VERSION" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
  echo "error: '$VERSION' is not a version like 0.4.0" >&2
  exit 2
fi

CASK="$TAP_DIR/$CASK_PATH"
test -f "$CASK" || { echo "error: $CASK not found — is $TAP_DIR a tap checkout?" >&2; exit 2; }

sha256_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

DMG_URL="$DMG_URL_BASE/v$VERSION/NotchBar.dmg"
# Not `mktemp -t notchbar-dmg`: BSD mktemp appends the random suffix itself,
# GNU mktemp rejects a template with no X. The job runs on Linux, dev runs on macOS.
DMG="$(mktemp "${TMPDIR:-/tmp}/notchbar-dmg.XXXXXX")"
trap 'rm -f "$DMG"' EXIT

echo "==> Downloading $DMG_URL"
curl -fsSL -o "$DMG" "$DMG_URL"
SHA="$(sha256_of "$DMG")"
echo "==> sha256 $SHA"

CURRENT_VERSION="$(sed -n 's/^  version "\(.*\)"$/\1/p' "$CASK")"
CURRENT_SHA="$(sed -n 's/^  sha256 "\(.*\)"$/\1/p' "$CASK")"
if [ "$CURRENT_VERSION" = "$VERSION" ] && [ "$CURRENT_SHA" = "$SHA" ]; then
  echo "==> Cask is already on $VERSION with a matching sha256 — nothing to do"
  exit 0
fi

echo "==> Rewriting the cask: $CURRENT_VERSION -> $VERSION"
sed -i.bak \
  -e "s|^  version \".*\"$|  version \"$VERSION\"|" \
  -e "s|^  sha256 \".*\"$|  sha256 \"$SHA\"|" \
  "$CASK"
rm -f "$CASK.bak"

# A silent no-op sed here would open an empty PR that auto-merges into nothing.
grep -q "^  version \"$VERSION\"$" "$CASK" || { echo "error: version line not rewritten" >&2; exit 1; }
grep -q "^  sha256 \"$SHA\"$" "$CASK" || { echo "error: sha256 line not rewritten" >&2; exit 1; }

git -C "$TAP_DIR" --no-pager diff -- "$CASK_PATH"

if [ -n "$DRY_RUN" ]; then
  echo "==> Dry run: stopping before commit"
  exit 0
fi

BRANCH="chore/notchbar-$VERSION"
echo "==> Pushing $BRANCH to $TAP_REPO"
git -C "$TAP_DIR" config user.name "github-actions[bot]"
git -C "$TAP_DIR" config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git -C "$TAP_DIR" checkout -B "$BRANCH"
git -C "$TAP_DIR" add "$CASK_PATH"
git -C "$TAP_DIR" commit -m "chore(cask): notchbar $VERSION"
# Force-push so re-running a failed release job reuses the same branch and PR.
git -C "$TAP_DIR" push --force origin "HEAD:refs/heads/$BRANCH"

PR_URL="$(gh pr list --repo "$TAP_REPO" --head "$BRANCH" --state open --json url --jq '.[0].url // empty')"
if [ -n "$PR_URL" ]; then
  echo "==> Reusing the open PR $PR_URL"
else
  echo "==> Opening the pull request"
  PR_URL="$(gh pr create --repo "$TAP_REPO" --base main --head "$BRANCH" --assignee @me \
    --title "chore(cask): notchbar $VERSION" \
    --body "NotchBar $VERSION is published, so the cask has to follow — until it does, \`brew upgrade --cask notchbar\` is a no-op and Homebrew users stay on $CURRENT_VERSION.

Version and sha256 come from the .dmg attached to the [v$VERSION release]($DMG_URL_BASE/v$VERSION/NotchBar.dmg), computed on the exact bytes Homebrew downloads.

Verification: \`brew test-bot --only-tap-syntax\` on this PR, then \`brew upgrade --cask notchbar\`.")"
fi

echo "==> Enabling auto-merge on $PR_URL"
gh pr merge --repo "$TAP_REPO" --auto --squash --delete-branch "$PR_URL"
echo "==> Done: $PR_URL"
