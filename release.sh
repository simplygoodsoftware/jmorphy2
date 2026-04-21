#!/usr/bin/env bash
# Build jmorphy2-elasticsearch plugin and publish a GitHub release.
#
# Tag format: elastic-<ES_VERSION> (matches historical releases elastic-8.6.2, elastic-8.10.4).
# Asset: analysis-jmorphy2-<LIB>-es<ES>.zip (only the zip; deb is not attached).
#
# Usage:
#   ./release.sh                       # uses es.version and project.version
#   ./release.sh 8.19.14               # override ES version
#   ./release.sh 8.19.14 0.3.0         # override ES and lib version
#
# Requirements:
#   - JAVA_HOME pointing to JDK 17+ (21 recommended)
#   - gh CLI authenticated (`gh auth login`)
#   - clean working tree (no uncommitted changes)

set -euo pipefail

cd "$(dirname "$0")"

ES_VERSION="${1:-$(tr -d '\r\n' <es.version)}"
LIB_VERSION="${2:-$(tr -d '\r\n' <project.version | sed 's/-SNAPSHOT$//')}"
TAG="elastic-${ES_VERSION}"
DIST_DIR="jmorphy2-elasticsearch/build/distributions"
ZIP="${DIST_DIR}/analysis-jmorphy2-${LIB_VERSION}-es${ES_VERSION}.zip"

# Extract owner/name from origin remote URL.
# Works for both git@github.com:owner/name.git and https://github.com/owner/name(.git)
REMOTE_URL="$(git remote get-url origin)"
REPO="$(echo "$REMOTE_URL" | sed -E 's#^(git@github\.com:|https?://github\.com/)##; s#\.git$##')"

echo ">>> Release: lib=${LIB_VERSION}, es=${ES_VERSION}, tag=${TAG}, repo=${REPO}"

if ! command -v gh >/dev/null; then
  echo "ERROR: gh CLI not found. Install from https://cli.github.com/" >&2
  exit 1
fi

# --ignore-cr-at-eol tolerates CRLF vs LF differences, which appear when
# the repo is checked out on Windows (autocrlf) but accessed from WSL.
if ! git diff --quiet --ignore-cr-at-eol HEAD -- 2>/dev/null \
    || ! git diff --quiet --cached --ignore-cr-at-eol HEAD -- 2>/dev/null; then
  echo "ERROR: working tree is dirty (non-EOL changes). Commit or stash first." >&2
  git diff --stat --ignore-cr-at-eol HEAD -- >&2
  exit 1
fi

untracked="$(git ls-files --others --exclude-standard)"
if [[ -n "$untracked" ]]; then
  echo "ERROR: untracked files present:" >&2
  echo "$untracked" >&2
  exit 1
fi

tag_local=0
tag_remote=0
git rev-parse "$TAG" >/dev/null 2>&1 && tag_local=1
git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1 && tag_remote=1

if [[ ! -f "$ZIP" ]]; then
  echo ">>> Building plugin against Elasticsearch ${ES_VERSION}..."
  ./gradlew :jmorphy2-elasticsearch:assemble -PesVersion="${ES_VERSION}" --no-daemon

  if [[ ! -f "$ZIP" ]]; then
    echo "ERROR: expected artifact not found after build: $ZIP" >&2
    ls -la "$DIST_DIR" >&2 || true
    exit 1
  fi
else
  echo ">>> Artifact already built, skipping gradle."
fi

echo ">>> Artifact:"
ls -lh "$ZIP"

if [[ $tag_local -eq 0 && $tag_remote -eq 0 ]]; then
  echo ">>> Creating git tag $TAG..."
  git tag "$TAG"
  git push origin "$TAG"
elif [[ $tag_local -eq 1 && $tag_remote -eq 0 ]]; then
  echo ">>> Tag $TAG exists locally, pushing to origin..."
  git push origin "$TAG"
elif [[ $tag_local -eq 0 && $tag_remote -eq 1 ]]; then
  echo ">>> Tag $TAG exists on origin, fetching..."
  git fetch origin "refs/tags/$TAG:refs/tags/$TAG"
else
  echo ">>> Tag $TAG already exists locally and on origin, skipping tag creation."
fi

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  echo ">>> Release $TAG already exists, uploading asset (--clobber)..."
  gh release upload "$TAG" --repo "$REPO" --clobber "$ZIP"
else
  echo ">>> Publishing GitHub release $TAG..."
  gh release create "$TAG" --repo "$REPO" \
    --title "Elastic ${ES_VERSION}" \
    --notes "Elastic ${ES_VERSION}" \
    "$ZIP"
fi

echo ">>> Done. Release URL:"
gh release view "$TAG" --repo "$REPO" --json url --jq .url
