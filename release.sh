#!/usr/bin/env bash
set -euo pipefail

# Usage: ./release.sh <major|minor|patch>
#
# Reads the current version from Info.plist, bumps the specified segment,
# commits, tags, and pushes to trigger the GitHub Actions release.
#
# Examples:
#   ./release.sh patch   # 1.0.0 → 1.0.1
#   ./release.sh minor   # 1.0.1 → 1.1.0
#   ./release.sh major   # 1.1.0 → 2.0.0

BUMP="${1:-}"
if [[ "$BUMP" != "major" && "$BUMP" != "minor" && "$BUMP" != "patch" ]]; then
    echo "Usage: ./release.sh <major|minor|patch>"
    echo ""
    echo "Examples:"
    echo "  ./release.sh patch   # 1.0.0 → 1.0.1"
    echo "  ./release.sh minor   # 1.0.1 → 1.1.0"
    echo "  ./release.sh major   # 1.1.0 → 2.0.0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST="$SCRIPT_DIR/Info.plist"

# Read current version from Info.plist
CURRENT=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

# Default to 0 if any segment is missing
MAJOR="${MAJOR:-0}"
MINOR="${MINOR:-0}"
PATCH="${PATCH:-0}"

# Bump the requested segment
case "$BUMP" in
    major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
    minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
    patch) PATCH=$((PATCH + 1)) ;;
esac

VERSION="$MAJOR.$MINOR.$PATCH"
TAG="v$VERSION"

echo "  Current version: $CURRENT"
echo "  New version:     $VERSION ($BUMP bump)"
echo ""

# Check for uncommitted changes
if ! git diff --quiet HEAD 2>/dev/null; then
    echo "⚠️  You have uncommitted changes. Commit or stash them first."
    exit 1
fi

# Check tag doesn't already exist
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "⚠️  Tag $TAG already exists."
    exit 1
fi

echo "==> Updating version to $VERSION..."
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$PLIST"

# Update CHANGELOG.md: rename [Unreleased] → [version] with today's date
CHANGELOG="$SCRIPT_DIR/CHANGELOG.md"
if [ -f "$CHANGELOG" ] && grep -q '## \[Unreleased\]' "$CHANGELOG"; then
    TODAY=$(date +%Y-%m-%d)
    sed -i '' "s/## \[Unreleased\]/## [$VERSION] - $TODAY/" "$CHANGELOG"
    # Add a fresh [Unreleased] section at the top
    sed -i '' "/^## \[$VERSION\]/i\\
\\
## [Unreleased]\\
" "$CHANGELOG"
    echo "==> Updated CHANGELOG.md: [Unreleased] → [$VERSION] - $TODAY"
else
    echo "==> No [Unreleased] section found in CHANGELOG.md, skipping"
fi

echo "==> Committing version bump..."
git add "$PLIST" "$CHANGELOG"
git commit -m "Release $TAG"

echo "==> Creating tag $TAG..."
git tag -a "$TAG" -m "Release $VERSION"

echo "==> Pushing to origin..."
git push origin HEAD
git push origin "$TAG"

echo ""
echo "✓ Released $TAG ($CURRENT → $VERSION)"
echo "  GitHub Actions will now build and publish the release."
REPO_URL=$(git remote get-url origin 2>/dev/null | sed 's/.*github.com[:/]\(.*\)\.git/\1/' || echo "your-repo")
echo "  Check: https://github.com/$REPO_URL/releases"
