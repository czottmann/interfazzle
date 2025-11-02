#!/usr/bin/env bash

set -euo pipefail

function allow_or_exit() {
  local prompt="${1:-}"

  if command -v gum &> /dev/null; then
    # Use gum if available
    if ! gum confirm "${prompt} Continue?" --default=No; then
      echo "Aborting!"
      exit 0
    fi
  else
    # Fallback to read
    read -p "$prompt Continue? [y/n] " -n 1 -r
    echo
    case $REPLY in
      y|Y)
        echo
        # We're good to go
        ;;
      *)
        echo "Aborting!"
        exit 0
        ;;
    esac
  fi
}

function show_help() {
  cat <<EOF

Only works in \`release/\` branches, e.g. \`release/2025.11.x\` or \`release/2026.1.x\`.

Commits the current changes and tags the commit, effectively marking the commit
as the release commit for the version contained in the branch name.

EXAMPLE:
- If the branch name is \`release/2025.11.x\`, and the patch version is '3', then
  the tag \`2025.11.3\` will be created.

FLAGS:
  --patch-version N   Specify patch version number (optional, auto-calculated if omitted)
  --help              This usage description.
EOF
  exit 1
}

# Parse arguments
PATCH_VERSION=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --patch-version)
      PATCH_VERSION="$2"
      shift 2
      ;;
    --help)
      show_help
      ;;
    *)
      echo "ERROR: Unknown argument: $1"
      show_help
      ;;
  esac
done

# Get current branch
GIT_BRANCH=$(git branch --show-current)

# Verify we're in a release branch
if [[ ! "$GIT_BRANCH" =~ ^release/ ]]; then
  echo "ERROR: Must be in a release/ branch (current: $GIT_BRANCH)"
  exit 1
fi

VERSION_FILE="./Sources/InterfazzleCLI/Version.swift"

# Extract current version from Version.swift
if [[ ! -f "$VERSION_FILE" ]]; then
  echo "ERROR: $VERSION_FILE not found"
  exit 1
fi

CURRENT_VERSION=$(grep -E 'let packageVersion = "' "$VERSION_FILE" | sed -E 's/.*"([^"]+)".*/\1/')

if [[ -z "$CURRENT_VERSION" ]]; then
  echo "ERROR: Could not extract version from $VERSION_FILE"
  exit 1
fi

echo "Current version: $CURRENT_VERSION"

# Calculate new version
if [[ -n "$PATCH_VERSION" ]]; then
  # Use provided patch version with branch name
  BRANCH_VERSION=$(echo "$GIT_BRANCH" | cut -d "/" -f 2 | sed 's/.x$//')
  NEW_VERSION="${BRANCH_VERSION}.${PATCH_VERSION}"
else
  # Auto-calculate version based on current date
  CURRENT_DATE=$(date +"%Y.%-m")

  # Extract segments from current version
  IFS='.' read -r YEAR MONTH PATCH <<< "$CURRENT_VERSION"
  CURRENT_PREFIX="${YEAR}.${MONTH}"

  if [[ "$CURRENT_PREFIX" == "$CURRENT_DATE" ]]; then
    # Same month, increment patch
    NEW_PATCH=$((PATCH + 1))
    NEW_VERSION="${CURRENT_DATE}.${NEW_PATCH}"
  else
    # New month, reset to .1
    NEW_VERSION="${CURRENT_DATE}.1"
  fi
fi

echo "New version: $NEW_VERSION"

# Update Version.swift
echo "Updating $VERSION_FILE"
sed -i '' "s/let packageVersion = \".*\"/let packageVersion = \"$NEW_VERSION\"/" "$VERSION_FILE"

# Build and verify version
echo "Building interfazzle to verify version …"
swift build -c release > /dev/null 2>&1

BUILT_VERSION=$(.build/release/interfazzle --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "")

if [[ "$BUILT_VERSION" != "$NEW_VERSION" ]]; then
  echo "ERROR: Built version ($BUILT_VERSION) does not match expected version ($NEW_VERSION)"
  # Revert the version file change
  git checkout "$VERSION_FILE"
  exit 1
fi

echo "✓ Version verified: $BUILT_VERSION"
echo

RELEASE_TAG="$NEW_VERSION"

allow_or_exit "New tag will be named '$RELEASE_TAG'."

echo "Committing the following files with a message of '[REL] Release $RELEASE_TAG':"
echo
git status --porcelain | sed -E "s/^/  /"
echo

allow_or_exit

git commit -m "[REL] Release $RELEASE_TAG" -a
git tag "$RELEASE_TAG"
echo "Done!"
echo

allow_or_exit "Pushing the commit and tag to the remote …"

git push --tags
echo "Done!"
echo

allow_or_exit "Merging branch '$GIT_BRANCH' into 'main' …"

git checkout main
git pull --tags
git merge -m "[MRG] Merge release '$RELEASE_TAG'" --no-edit --no-ff "$GIT_BRANCH"

allow_or_exit "Push main to remote?"
git push

echo "Done!"
echo
