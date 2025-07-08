#!/usr/bin/env bash
# Script to set up git hooks for the project

set -e

HOOKS_DIR=".git/hooks"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Setting up git hooks..."

# Create pre-commit hook
cat > "$PROJECT_ROOT/$HOOKS_DIR/pre-commit" << 'EOF'
#!/usr/bin/env bash
# Git pre-commit hook to run dune fmt for OCaml

echo "Running OCaml formatting..."

# Check if dune is available
if command -v dune &> /dev/null; then
    # Get list of staged OCaml files
    OCAML_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(ml|mli)$|dune$')
    
    if [ -n "$OCAML_FILES" ]; then
        echo "→ Running dune fmt --auto-promote..."
        dune fmt --auto-promote
        
        # Check if any files were modified by dune fmt
        MODIFIED_OCAML_FILES=""
        for file in $OCAML_FILES; do
            if ! git diff --quiet "$file"; then
                MODIFIED_OCAML_FILES="$MODIFIED_OCAML_FILES $file"
            fi
        done
        
        # If files were modified, stage them
        if [ -n "$MODIFIED_OCAML_FILES" ]; then
            echo "→ dune fmt made changes. Staging modified files..."
            git add $MODIFIED_OCAML_FILES
            echo "✓ Staged OCaml files:$MODIFIED_OCAML_FILES"
        fi
        
        echo "✅ OCaml formatting complete!"
    else
        echo "No OCaml files to format."
    fi
fi

# Build check
echo ""
echo "🔨 Checking build..."
if ! dune build; then
    echo "❌ Build failed. Please fix build errors before committing."
    exit 1
fi
echo "✅ Build successful!"

# Test check
echo ""
echo "🧪 Running tests..."

# Check if tests should be skipped based on marker file
if [ -f ".git/SKIP_TESTS_MARKER" ]; then
    echo "⚠️  Commit prefix 'test!' or 'wip:' detected. Skipping test check."
    echo "   This commit is allowed to have failing tests."
    # Clean up the marker file
    rm -f .git/SKIP_TESTS_MARKER
else
    if ! dune test; then
        echo "❌ Tests failed. Please fix failing tests before committing."
        echo ""
        echo "   If you're intentionally committing failing tests, use one of these prefixes:"
        echo "   • test!: for test changes that are expected to fail"
        echo "   • wip: for work-in-progress commits"
        echo ""
        echo "   Example: git commit -m 'test!: add failing test for complex history'"
        echo ""
        exit 1
    fi
    echo "✅ All tests passed!"
fi

exit 0
EOF

# Make the hook executable
chmod +x "$PROJECT_ROOT/$HOOKS_DIR/pre-commit"

# Create prepare-commit-msg hook that checks for test!/wip prefixes
cat > "$PROJECT_ROOT/$HOOKS_DIR/prepare-commit-msg" << 'EOF'
#!/bin/bash
# Simpler and more robust prepare-commit-msg hook

MSG_FILE="$1"
COMMIT_SOURCE="$2"
MARKER_FILE=".git/SKIP_TESTS_MARKER"

# Clean up any old marker file first
rm -f "$MARKER_FILE"

# Only process if a message is provided via -m or -F
if [[ "$COMMIT_SOURCE" == "message" || "$COMMIT_SOURCE" == "file" ]]; then
    # Read the first line of the commit message into a variable
    read -r FIRST_LINE < "$MSG_FILE"
    
    # Check if the first line starts with "test!:" or "wip:"
    # Note: The space after the colon is intentional for good practice.
    if [[ "$FIRST_LINE" == "test!:"* || "$FIRST_LINE" == "wip:"* ]]; then
        # Create a marker file that pre-commit can check
        echo "Found '${FIRST_LINE%%:*}' prefix. Skipping tests for this commit."
        touch "$MARKER_FILE"
    fi
fi

# Always allow prepare-commit-msg to succeed
exit 0
EOF

# Make the hook executable
chmod +x "$PROJECT_ROOT/$HOOKS_DIR/prepare-commit-msg"

echo "✅ Git hooks set up successfully!"
echo ""
echo "The following hooks have been installed:"
echo "  • pre-commit: Runs dune fmt, dune build, and dune test"
echo "  • prepare-commit-msg: Detects test!/wip prefixes to allow failing tests"
echo ""
echo "To intentionally commit failing tests, use one of these prefixes:"
echo "  • test!: for test changes that are expected to fail"
echo "  • wip: for work-in-progress commits"
echo ""
echo "Example: git commit -m 'test!: add failing test for complex history'"