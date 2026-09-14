#!/bin/bash
#
# Single git entrypoint for committing and pushing changes
# Follows constitution principle §2: locked entrypoint for all git operations
#
# Usage: ./scripts/commit_all.sh "<commit message>" [--no-push]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Use current working directory as project root
PROJECT_DIR="$(pwd)"

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

# Print usage
usage() {
    echo "Usage: $0 \"<commit message>\" [--no-push]"
    echo "Example: $0 \"feat: add new feature\""
    echo "         $0 \"fix: typo\" --no-push"
    exit 1
}

# Check arguments
if [ $# -lt 1 ]; then
    log_error "Commit message is required"
    usage
fi

COMMIT_MESSAGE="$1"
NO_PUSH=false

# Parse optional --no-push flag
if [ "$2" = "--no-push" ]; then
    NO_PUSH=true
fi

# Ensure we're in the project directory
cd "$PROJECT_DIR"

# Verify we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    log_error "Not a git repository"
    exit 1
fi

log_info "Starting git commit process"
log_info "Commit message: $COMMIT_MESSAGE"

# Check git status
log_info "Checking git status..."
if ! git status --porcelain; then
    log_error "Failed to check git status"
    exit 1
fi

# Check for staged changes
if ! git diff --staged --quiet; then
    log_info "Staged changes detected"
else
    log_info "No staged changes found"
fi

# Check for unstaged changes
if ! git diff --quiet; then
    log_info "Unstaged changes detected"
else
    log_info "No unstaged changes found"
fi

# Add all changes
log_info "Adding all changes..."
if ! git add -A; then
    log_error "Failed to add changes"
    exit 1
fi

# Verify what's staged
log_info "Staged files:"
git diff --staged --name-only

# Commit changes
log_info "Committing changes..."
if ! git commit -m "$COMMIT_MESSAGE"; then
    log_error "Failed to commit changes"
    exit 1
fi

log_success "Changes committed successfully"

# Push if not disabled
if [ "$NO_PUSH" = false ]; then
    log_info "Pushing to remote..."
    if ! git push; then
        log_error "Failed to push changes"
        exit 1
    fi
    log_success "Changes pushed successfully"
else
    log_info "Skipping push (--no-push flag provided)"
fi

log_success "Git commit process completed successfully"
exit 0