#!/bin/bash
#
# Release script for YT-DLP Container System
# Tags new version using GitHub/GitLab CLIs and generates changelogs
#

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Header
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}    YT-DLP Release Script${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# =============================================================================
# Check Requirements
# =============================================================================

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    log_error "Not in a git repository"
    exit 1
fi

# Check for GitHub CLI (gh) or GitLab CLI (glab)
HAS_GH=false
HAS_GLAB=false

if command -v gh &> /dev/null; then
    HAS_GH=true
    log_info "GitHub CLI (gh) found: $(gh --version | head -1)"
fi

if command -v glab &> /dev/null; then
    HAS_GLAB=true
    log_info "GitLab CLI (glab) found: $(glab --version | head -1)"
fi

if [ "$HAS_GH" = "false" ] && [ "$HAS_GLAB" = "false" ]; then
    log_warning "Neither GitHub CLI (gh) nor GitLab CLI (glab) found"
    log_warning "Release tagging and changelog publishing will be skipped"
    log_warning "Install gh: https://cli.github.com/ or glab: https://gitlab.com/gitlab-org/cli"
fi

# =============================================================================
# Determine Version
# =============================================================================

# Get current version from git tags
CURRENT_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
log_info "Current version: $CURRENT_VERSION"

# Determine new version
if [ -n "$1" ]; then
    NEW_VERSION="$1"
else
    # Auto-increment patch version
    if [[ $CURRENT_VERSION =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        MAJOR="${BASH_REMATCH[1]}"
        MINOR="${BASH_REMATCH[2]}"
        PATCH="${BASH_REMATCH[3]}"
        NEW_PATCH=$((PATCH + 1))
        NEW_VERSION="v${MAJOR}.${MINOR}.${NEW_PATCH}"
    else
        NEW_VERSION="v1.0.0"
    fi
    
    echo -n "New version (auto: $NEW_VERSION): "
    read -r USER_VERSION
    if [ -n "$USER_VERSION" ]; then
        NEW_VERSION="$USER_VERSION"
    fi
fi

# Validate version format
if [[ ! $NEW_VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?$ ]]; then
    log_error "Invalid version format: $NEW_VERSION"
    log_error "Expected format: vX.Y.Z or vX.Y.Z-suffix"
    exit 1
fi

log_info "Releasing version: $NEW_VERSION"
echo ""

# =============================================================================
# Check Working Directory
# =============================================================================

if [ -n "$(git status --porcelain)" ]; then
    log_warning "Working directory has uncommitted changes"
    git status --short
    echo ""
    read -p "Commit changes before release? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git add -A
        read -p "Commit message: " COMMIT_MSG
        if [ -z "$COMMIT_MSG" ]; then
            COMMIT_MSG="chore: prepare release $NEW_VERSION"
        fi
        git commit -m "$COMMIT_MSG"
        log_success "Changes committed"
    else
        log_error "Please commit or stash changes before releasing"
        exit 1
    fi
fi

# =============================================================================
# Generate Changelog
# =============================================================================

log_info "Generating changelog..."

CHANGELOG_FILE="$PROJECT_DIR/CHANGELOG.md"
TEMP_CHANGELOG=$(mktemp)

# Get commits since last tag
if [ "$CURRENT_VERSION" != "v0.0.0" ]; then
    COMMITS=$(git log --pretty=format:"- %s (%h)" "$CURRENT_VERSION..HEAD" 2>/dev/null || git log --pretty=format:"- %s (%h)")
else
    COMMITS=$(git log --pretty=format:"- %s (%h)")
fi

# Categorize commits
FEATURES=$(echo "$COMMITS" | grep -E "^- (feat|feature):" | sed 's/^- //' || true)
FIXES=$(echo "$COMMITS" | grep -E "^- (fix|bugfix):" | sed 's/^- //' || true)
IMPROVEMENTS=$(echo "$COMMITS" | grep -E "^- (improve|perf|refactor):" | sed 's/^- //' || true)
DOCS=$(echo "$COMMITS" | grep -E "^- (docs|doc):" | sed 's/^- //' || true)
CHANGES=$(echo "$COMMITS" | grep -E "^- (chore|build|ci|test|style):" | sed 's/^- //' || true)
OTHER=$(echo "$COMMITS" | grep -vE "^- (feat|feature|fix|bugfix|improve|perf|refactor|docs|doc|chore|build|ci|test|style):" | sed 's/^- //' || true)

# Build changelog entry
{
    echo "## $NEW_VERSION - $(date +%Y-%m-%d)"
    echo ""
    
    if [ -n "$FEATURES" ]; then
        echo "### Features"
        echo "$FEATURES"
        echo ""
    fi
    
    if [ -n "$FIXES" ]; then
        echo "### Bug Fixes"
        echo "$FIXES"
        echo ""
    fi
    
    if [ -n "$IMPROVEMENTS" ]; then
        echo "### Improvements"
        echo "$IMPROVEMENTS"
        echo ""
    fi
    
    if [ -n "$DOCS" ]; then
        echo "### Documentation"
        echo "$DOCS"
        echo ""
    fi
    
    if [ -n "$CHANGES" ]; then
        echo "### Maintenance"
        echo "$CHANGES"
        echo ""
    fi
    
    if [ -n "$OTHER" ]; then
        echo "### Other Changes"
        echo "$OTHER"
        echo ""
    fi
    
    echo ""
} > "$TEMP_CHANGELOG"

# Prepend to existing changelog or create new
if [ -f "$CHANGELOG_FILE" ]; then
    cat "$CHANGELOG_FILE" >> "$TEMP_CHANGELOG"
fi

mv "$TEMP_CHANGELOG" "$CHANGELOG_FILE"
log_success "Changelog updated: $CHANGELOG_FILE"

# =============================================================================
# Create Git Tag
# =============================================================================

log_info "Creating git tag: $NEW_VERSION"

git tag -a "$NEW_VERSION" -m "Release $NEW_VERSION"
log_success "Git tag created: $NEW_VERSION"

# =============================================================================
# Push Changes and Tag
# =============================================================================

log_info "Pushing changes and tag to origin..."

git push origin main
git push origin "$NEW_VERSION"
log_success "Changes and tag pushed to origin"

# =============================================================================
# Create GitHub/GitLab Release
# =============================================================================

if [ "$HAS_GH" = "true" ]; then
    log_info "Creating GitHub release..."
    
    # Extract changelog for this version
    RELEASE_NOTES=$(sed -n "/^## $NEW_VERSION/,/^## v/p" "$CHANGELOG_FILE" | head -n -1)
    
    if gh release create "$NEW_VERSION" --title "Release $NEW_VERSION" --notes "$RELEASE_NOTES" 2>/dev/null; then
        log_success "GitHub release created"
    else
        log_warning "GitHub release creation failed (may already exist)"
    fi
fi

if [ "$HAS_GLAB" = "true" ]; then
    log_info "Creating GitLab release..."
    
    RELEASE_NOTES=$(sed -n "/^## $NEW_VERSION/,/^## v/p" "$CHANGELOG_FILE" | head -n -1)
    
    if glab release create "$NEW_VERSION" --name "Release $NEW_VERSION" --notes "$RELEASE_NOTES" 2>/dev/null; then
        log_success "GitLab release created"
    else
        log_warning "GitLab release creation failed (may already exist)"
    fi
fi

# =============================================================================
# Mirror to Submodules (if any)
# =============================================================================

log_info "Checking for submodules to mirror..."

if git submodule status | grep -q "^ "; then
    log_info "Submodules found, mirroring version tag..."
    
    git submodule foreach --recursive "
        if [ -d .git ]; then
            git tag -a \"$NEW_VERSION\" -m \"Release $NEW_VERSION\" 2>/dev/null || true
            git push origin \"$NEW_VERSION\" 2>/dev/null || true
        fi
    "
    log_success "Submodule tags mirrored"
else
    log_info "No submodules to mirror"
fi

# =============================================================================
# Summary
# =============================================================================

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}    Release Complete! ✓${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "Version:        ${CYAN}$NEW_VERSION${NC}"
echo -e "Changelog:      ${CYAN}$CHANGELOG_FILE${NC}"
echo -e "Git Tag:        ${CYAN}$NEW_VERSION${NC}"
echo ""

if [ "$HAS_GH" = "true" ]; then
    echo -e "GitHub Release: ${CYAN}https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)/releases/tag/$NEW_VERSION${NC}"
fi

if [ "$HAS_GLAB" = "true" ]; then
    echo -e "GitLab Release: ${CYAN}https://gitlab.com/$(glab repo view --json fullPath -q .fullPath 2>/dev/null)/-/releases/$NEW_VERSION${NC}"
fi

echo ""
log_success "Release $NEW_VERSION completed successfully!"

