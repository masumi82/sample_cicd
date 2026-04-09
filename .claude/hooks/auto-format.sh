#!/usr/bin/env bash
# PostToolUse hook: Auto-format Python files with ruff after Edit/Write.
# Always exits 0 (non-blocking). Formatting is best-effort.

# Note: -e is intentionally omitted. This hook must always exit 0 (non-blocking).
set -uo pipefail

INPUT=$(cat)

# Extract file_path from tool_input
FILE_PATH=""
if command -v jq &>/dev/null; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
fi

# Only format .py files
if [[ -z "$FILE_PATH" ]] || [[ "$FILE_PATH" != *.py ]]; then
  exit 0
fi

# Check if file exists
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Graceful degradation: skip if ruff is not installed
if ! command -v ruff &>/dev/null; then
  exit 0
fi

# Run ruff fix and format (suppress output)
ruff check --fix --quiet "$FILE_PATH" 2>/dev/null || true
ruff format --quiet "$FILE_PATH" 2>/dev/null || true

exit 0
