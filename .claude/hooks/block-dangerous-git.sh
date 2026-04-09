#!/usr/bin/env bash
# PreToolUse hook: Block dangerous git commands and destructive operations.
# Exit 2 = block, Exit 0 = allow.

set -euo pipefail

INPUT=$(cat)

# Extract the command from tool_input
COMMAND=""
if command -v jq &>/dev/null; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
fi

# If no command extracted, allow (not a Bash tool call we care about)
if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# Dangerous patterns to block (single regex for reliability)
if echo "$COMMAND" | grep -qE "git push (-f|--force)|git reset --hard|git clean -f|git checkout -- \.|git restore \.|rm -rf"; then
  echo "Dangerous command blocked: $COMMAND" >&2
  echo "This command could cause irreversible damage. Please confirm with the user first." >&2
  exit 2
fi

exit 0
