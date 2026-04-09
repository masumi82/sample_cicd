#!/usr/bin/env bash
# PreToolUse hook: Scan staged changes for secrets before git commit.
# Exit 2 = block (secrets found), Exit 0 = allow.

set -euo pipefail

INPUT=$(cat)

# Extract the command from tool_input
COMMAND=""
if command -v jq &>/dev/null; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
fi

# Only check on git commit commands
if ! echo "$COMMAND" | grep -qE "git commit"; then
  exit 0
fi

# Get staged diff (added lines only), excluding test/doc files where example values are expected
STAGED_DIFF=$(git diff --staged -- ':!tests/' ':!docs/' ':!.claude/hooks/' ':!.claude/agents/' ':!.claude/skills/' 2>/dev/null || true)
if [[ -z "$STAGED_DIFF" ]]; then
  exit 0
fi

ADDED_LINES=$(echo "$STAGED_DIFF" | grep "^+" | grep -v "^+++" || true)
if [[ -z "$ADDED_LINES" ]]; then
  exit 0
fi

FOUND_ISSUES=()

# 1. Real AWS Account ID in AWS context (ARN, account_id, etc. — not bare 12-digit numbers)
if echo "$ADDED_LINES" | grep -P '(arn:aws:|account.?id|account_id|AccountId|ACCOUNT)[^0-9]*[0-9]{12}' | grep -vq '123456789012'; then
  FOUND_ISSUES+=("AWS Account ID in ARN or account context")
fi

# 2. CloudFront domain (not dummy dXXXXXXXXXXXXX.cloudfront.net)
if echo "$ADDED_LINES" | grep -oP 'd[a-z0-9]{13,14}\.cloudfront\.net' | grep -vq 'dXXXXXXXXXXXXX\.cloudfront\.net'; then
  FOUND_ISSUES+=("CloudFront domain name")
fi

# 3. Route 53 Hosted Zone ID (not dummy Z0XXXXXXXXXXXXXXXXXX)
if echo "$ADDED_LINES" | grep -oP '\bZ[A-Z0-9]{10,32}\b' | grep -vq 'Z0XXXXXXXXXXXXXXXXXX'; then
  FOUND_ISSUES+=("Route 53 Hosted Zone ID")
fi

# 4. Cognito User Pool ID
if echo "$ADDED_LINES" | grep -qP 'ap-northeast-1_[A-Za-z0-9]{9}' && ! echo "$ADDED_LINES" | grep -q 'ap-northeast-1_XXXXXXXXX'; then
  FOUND_ISSUES+=("Cognito User Pool ID")
fi

# 5. AWS Access Key (always block)
if echo "$ADDED_LINES" | grep -qP 'AKIA[A-Z0-9]{16}'; then
  FOUND_ISSUES+=("AWS Access Key (AKIA...)")
fi

# 6. ALB DNS name
if echo "$ADDED_LINES" | grep -qP 'sample-cicd-.*\.ap-northeast-1\.elb\.amazonaws\.com'; then
  FOUND_ISSUES+=("ALB DNS name")
fi

if [[ ${#FOUND_ISSUES[@]} -gt 0 ]]; then
  echo "Security check FAILED: Potential secrets detected in staged changes." >&2
  echo "" >&2
  echo "Detected issues:" >&2
  for issue in "${FOUND_ISSUES[@]}"; do
    echo "  - $issue" >&2
  done
  echo "" >&2
  echo "Please replace real values with dummy values before committing." >&2
  echo "Run /security-check for detailed analysis and auto-fix suggestions." >&2
  exit 2
fi

exit 0
