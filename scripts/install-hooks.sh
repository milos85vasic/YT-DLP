#!/bin/bash
#
# Install git hooks for pre-push validation
#

set -e

HOOK_DIR="$(git rev-parse --show-toplevel)/.git/hooks"

if [ ! -d "$HOOK_DIR" ]; then
    echo "ERROR: Not in a git repository"
    exit 1
fi

cat > "$HOOK_DIR/pre-commit" << 'EOF'
#!/bin/bash
# Pre-commit hook: run dev-check before allowing commits
# Skip with: git commit --no-verify

echo "Running pre-commit validation..."

if [ -f ./scripts/dev-check.sh ]; then
    if ./scripts/dev-check.sh; then
        exit 0
    else
        echo ""
        echo "Pre-commit checks failed. Fix issues before committing."
        echo "To bypass (not recommended): git commit --no-verify"
        exit 1
    fi
else
    echo "WARNING: scripts/dev-check.sh not found, skipping pre-commit checks"
    exit 0
fi
EOF

chmod +x "$HOOK_DIR/pre-commit"
echo "Pre-commit hook installed at $HOOK_DIR/pre-commit"
