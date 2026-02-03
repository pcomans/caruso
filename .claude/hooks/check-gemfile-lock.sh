#!/bin/bash
# Check if Gemfile.lock is in sync with gemspec version
# Exit 2 to block Claude from stopping if out of sync

set -e

cd "$CLAUDE_PROJECT_DIR"

# Run bundle install in check mode (doesn't modify anything)
# If Gemfile.lock would change, bundle check fails
if ! bundle check > /dev/null 2>&1; then
  echo "Gemfile.lock is out of sync. Run 'bundle install' and commit the changes." >&2
  exit 2
fi

# Also check if Gemfile.lock has uncommitted changes
if git diff --name-only | grep -q "Gemfile.lock"; then
  echo "Gemfile.lock has uncommitted changes. Please commit them before finishing." >&2
  exit 2
fi

exit 0
