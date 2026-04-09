#!/usr/bin/env bash
# Automated tests for Claude Code hook scripts (v11).
# Usage: bash tests/test_hooks.sh
# Requires: jq, ruff, git

# Note: -e is intentionally omitted. Test runner must continue after individual test failures.
set -uo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# --- Helper functions ---

run_test() {
  local test_name="$1"
  local expected_exit="$2"
  local script="$3"
  local input="$4"

  actual_exit=0
  echo "$input" | "$script" >/dev/null 2>&1 || actual_exit=$?

  if [[ "$actual_exit" -eq "$expected_exit" ]]; then
    echo -e "  ${GREEN}PASS${NC} $test_name (exit $actual_exit)"
    ((PASS_COUNT++))
  else
    echo -e "  ${RED}FAIL${NC} $test_name (expected exit $expected_exit, got $actual_exit)"
    ((FAIL_COUNT++))
  fi
}

skip_test() {
  local test_name="$1"
  local reason="$2"
  echo -e "  ${YELLOW}SKIP${NC} $test_name ($reason)"
  ((SKIP_COUNT++))
}

# --- Pre-flight checks ---

echo "========================================="
echo " v11 Hook Tests"
echo "========================================="
echo ""

if ! command -v jq &>/dev/null; then
  echo -e "${RED}ERROR: jq is required but not installed${NC}"
  exit 1
fi

BLOCK_SCRIPT="$PROJECT_DIR/.claude/hooks/block-dangerous-git.sh"
SECURITY_SCRIPT="$PROJECT_DIR/.claude/hooks/security-check.sh"
FORMAT_SCRIPT="$PROJECT_DIR/.claude/hooks/auto-format.sh"

for script in "$BLOCK_SCRIPT" "$SECURITY_SCRIPT" "$FORMAT_SCRIPT"; do
  if [[ ! -x "$script" ]]; then
    echo -e "${RED}ERROR: $script is not executable${NC}"
    exit 1
  fi
done

# =========================================
# 1. block-dangerous-git.sh
# =========================================

echo "--- block-dangerous-git.sh ---"

run_test "TC-85: blocks git push --force" 2 "$BLOCK_SCRIPT" \
  '{"tool_input":{"command":"git push --force origin main"}}'

run_test "TC-86: blocks git push -f" 2 "$BLOCK_SCRIPT" \
  '{"tool_input":{"command":"git push -f origin main"}}'

run_test "TC-87: blocks git reset --hard" 2 "$BLOCK_SCRIPT" \
  '{"tool_input":{"command":"git reset --hard HEAD~1"}}'

run_test "TC-88: blocks rm -rf" 2 "$BLOCK_SCRIPT" \
  '{"tool_input":{"command":"rm -rf /tmp/test"}}'

run_test "TC-89: allows git status" 0 "$BLOCK_SCRIPT" \
  '{"tool_input":{"command":"git status"}}'

run_test "TC-90: allows normal git push" 0 "$BLOCK_SCRIPT" \
  '{"tool_input":{"command":"git push origin feature-branch"}}'

run_test "TC-91: allows empty input" 0 "$BLOCK_SCRIPT" \
  '{}'

echo ""

# =========================================
# 2. security-check.sh
# =========================================

echo "--- security-check.sh ---"

# TC-92: Non-commit commands should skip
run_test "TC-92: skips non-commit commands" 0 "$SECURITY_SCRIPT" \
  '{"tool_input":{"command":"git status"}}'

# TC-93 through TC-97 require git staged changes.
# We test by creating a temporary git repo.

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

(
  cd "$TEMP_DIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"

  # TC-93: Dummy account ID should be allowed
  echo "account_id = 123456789012" > test.tf
  git add test.tf
  actual_exit=0
  echo '{"tool_input":{"command":"git commit -m test"}}' | "$SECURITY_SCRIPT" >/dev/null 2>&1 || actual_exit=$?
  if [[ "$actual_exit" -eq 0 ]]; then
    echo -e "  ${GREEN}PASS${NC} TC-93: allows dummy account ID (exit $actual_exit)"
    # Can't increment parent PASS_COUNT from subshell, use temp file
    echo "PASS" >> "$TEMP_DIR/.results"
  else
    echo -e "  ${RED}FAIL${NC} TC-93: allows dummy account ID (expected 0, got $actual_exit)"
    echo "FAIL" >> "$TEMP_DIR/.results"
  fi
  git commit -q -m "initial" --allow-empty

  # TC-94: Real CloudFront domain should be detected
  git checkout -q -b test-cf
  echo "domain = d1234567890abc.cloudfront.net" > cf.tf
  git add cf.tf
  actual_exit=0
  echo '{"tool_input":{"command":"git commit -m test"}}' | "$SECURITY_SCRIPT" >/dev/null 2>&1 || actual_exit=$?
  if [[ "$actual_exit" -eq 2 ]]; then
    echo -e "  ${GREEN}PASS${NC} TC-94: detects real CloudFront domain (exit $actual_exit)"
    echo "PASS" >> "$TEMP_DIR/.results"
  else
    echo -e "  ${RED}FAIL${NC} TC-94: detects real CloudFront domain (expected 2, got $actual_exit)"
    echo "FAIL" >> "$TEMP_DIR/.results"
  fi
  git checkout -q -f -

  # TC-95: Dummy CloudFront domain should be allowed
  git checkout -q -b test-cf-dummy
  echo "domain = dXXXXXXXXXXXXX.cloudfront.net" > cf_dummy.tf
  git add cf_dummy.tf
  actual_exit=0
  echo '{"tool_input":{"command":"git commit -m test"}}' | "$SECURITY_SCRIPT" >/dev/null 2>&1 || actual_exit=$?
  if [[ "$actual_exit" -eq 0 ]]; then
    echo -e "  ${GREEN}PASS${NC} TC-95: allows dummy CloudFront domain (exit $actual_exit)"
    echo "PASS" >> "$TEMP_DIR/.results"
  else
    echo -e "  ${RED}FAIL${NC} TC-95: allows dummy CloudFront domain (expected 0, got $actual_exit)"
    echo "FAIL" >> "$TEMP_DIR/.results"
  fi
  git checkout -q -f -

  # TC-96: AWS Access Key should be detected
  git checkout -q -b test-akia
  echo "aws_access_key = AKIAIOSFODNN7EXAMPLE" > secret.tf
  git add secret.tf
  actual_exit=0
  echo '{"tool_input":{"command":"git commit -m test"}}' | "$SECURITY_SCRIPT" >/dev/null 2>&1 || actual_exit=$?
  if [[ "$actual_exit" -eq 2 ]]; then
    echo -e "  ${GREEN}PASS${NC} TC-96: detects AWS Access Key (exit $actual_exit)"
    echo "PASS" >> "$TEMP_DIR/.results"
  else
    echo -e "  ${RED}FAIL${NC} TC-96: detects AWS Access Key (expected 2, got $actual_exit)"
    echo "FAIL" >> "$TEMP_DIR/.results"
  fi
  git checkout -q -f -

  # TC-97a: Hosted Zone ID should be detected
  git checkout -q -b test-hz
  echo "zone_id = Z09ABCDEFGHIJK" > hz.tf
  git add hz.tf
  actual_exit=0
  echo '{"tool_input":{"command":"git commit -m test"}}' | "$SECURITY_SCRIPT" >/dev/null 2>&1 || actual_exit=$?
  if [[ "$actual_exit" -eq 2 ]]; then
    echo -e "  ${GREEN}PASS${NC} TC-97a: detects Hosted Zone ID (exit $actual_exit)"
    echo "PASS" >> "$TEMP_DIR/.results"
  else
    echo -e "  ${RED}FAIL${NC} TC-97a: detects Hosted Zone ID (expected 2, got $actual_exit)"
    echo "FAIL" >> "$TEMP_DIR/.results"
  fi
  git checkout -q -f -

  # TC-97b: ALB DNS name should be detected
  git checkout -q -b test-alb
  echo "dns = sample-cicd-dev-alb-123456.ap-northeast-1.elb.amazonaws.com" > alb.tf
  git add alb.tf
  actual_exit=0
  echo '{"tool_input":{"command":"git commit -m test"}}' | "$SECURITY_SCRIPT" >/dev/null 2>&1 || actual_exit=$?
  if [[ "$actual_exit" -eq 2 ]]; then
    echo -e "  ${GREEN}PASS${NC} TC-97b: detects ALB DNS name (exit $actual_exit)"
    echo "PASS" >> "$TEMP_DIR/.results"
  else
    echo -e "  ${RED}FAIL${NC} TC-97b: detects ALB DNS name (expected 2, got $actual_exit)"
    echo "FAIL" >> "$TEMP_DIR/.results"
  fi
  git checkout -q -f -

  # TC-97: Clean commit should be allowed
  git checkout -q -b test-clean
  echo "resource = aws_s3_bucket" > clean.tf
  git add clean.tf
  actual_exit=0
  echo '{"tool_input":{"command":"git commit -m test"}}' | "$SECURITY_SCRIPT" >/dev/null 2>&1 || actual_exit=$?
  if [[ "$actual_exit" -eq 0 ]]; then
    echo -e "  ${GREEN}PASS${NC} TC-97: allows clean commit (exit $actual_exit)"
    echo "PASS" >> "$TEMP_DIR/.results"
  else
    echo -e "  ${RED}FAIL${NC} TC-97: allows clean commit (expected 0, got $actual_exit)"
    echo "FAIL" >> "$TEMP_DIR/.results"
  fi
)

# Count results from subshell
if [[ -f "$TEMP_DIR/.results" ]]; then
  PASS_COUNT=$((PASS_COUNT + $(grep -c "PASS" "$TEMP_DIR/.results" || true)))
  FAIL_COUNT=$((FAIL_COUNT + $(grep -c "FAIL" "$TEMP_DIR/.results" || true)))
fi

echo ""

# =========================================
# 3. auto-format.sh
# =========================================

echo "--- auto-format.sh ---"

# TC-98: Formats Python file
if command -v ruff &>/dev/null; then
  TEMP_PY=$(mktemp --suffix=.py)
  echo "x=1+2" > "$TEMP_PY"  # Bad formatting
  actual_exit=0
  echo "{\"tool_input\":{\"file_path\":\"$TEMP_PY\"}}" | "$FORMAT_SCRIPT" >/dev/null 2>&1 || actual_exit=$?
  FORMATTED=$(cat "$TEMP_PY")
  if [[ "$actual_exit" -eq 0 ]] && [[ "$FORMATTED" == *"x = 1 + 2"* ]]; then
    echo -e "  ${GREEN}PASS${NC} TC-98: formats Python file"
    ((PASS_COUNT++))
  else
    echo -e "  ${RED}FAIL${NC} TC-98: formats Python file (exit=$actual_exit, content=$FORMATTED)"
    ((FAIL_COUNT++))
  fi
  rm -f "$TEMP_PY"
else
  skip_test "TC-98: formats Python file" "ruff not installed"
fi

# TC-99: Skips non-Python file
run_test "TC-99: skips non-Python file" 0 "$FORMAT_SCRIPT" \
  '{"tool_input":{"file_path":"/tmp/test.tf"}}'

# TC-100: Skips empty input
run_test "TC-100: skips empty input" 0 "$FORMAT_SCRIPT" \
  '{}'

echo ""

# =========================================
# 4. Settings & config validation
# =========================================

echo "--- Settings & config validation ---"

# TC-101: settings.json is valid JSON
if jq empty "$PROJECT_DIR/.claude/settings.json" 2>/dev/null; then
  echo -e "  ${GREEN}PASS${NC} TC-101: settings.json is valid JSON"
  ((PASS_COUNT++))
else
  echo -e "  ${RED}FAIL${NC} TC-101: settings.json is not valid JSON"
  ((FAIL_COUNT++))
fi

# TC-102: settings.json has hooks
HOOKS_COUNT=$(jq '.hooks | length' "$PROJECT_DIR/.claude/settings.json" 2>/dev/null || echo 0)
if [[ "$HOOKS_COUNT" -gt 0 ]]; then
  echo -e "  ${GREEN}PASS${NC} TC-102: settings.json has hooks section ($HOOKS_COUNT event types)"
  ((PASS_COUNT++))
else
  echo -e "  ${RED}FAIL${NC} TC-102: settings.json missing hooks"
  ((FAIL_COUNT++))
fi

# TC-103: settings.json has deny rules
DENY_COUNT=$(jq '.permissions.deny | length' "$PROJECT_DIR/.claude/settings.json" 2>/dev/null || echo 0)
if [[ "$DENY_COUNT" -ge 7 ]]; then
  echo -e "  ${GREEN}PASS${NC} TC-103: settings.json has $DENY_COUNT deny rules"
  ((PASS_COUNT++))
else
  echo -e "  ${RED}FAIL${NC} TC-103: settings.json has only $DENY_COUNT deny rules (expected >= 7)"
  ((FAIL_COUNT++))
fi

# TC-104: .claudeignore exists and is non-empty
if [[ -s "$PROJECT_DIR/.claudeignore" ]]; then
  echo -e "  ${GREEN}PASS${NC} TC-104: .claudeignore exists and is non-empty"
  ((PASS_COUNT++))
else
  echo -e "  ${RED}FAIL${NC} TC-104: .claudeignore missing or empty"
  ((FAIL_COUNT++))
fi

# TC-105: .claudeignore has .env pattern
if grep -q '\.env' "$PROJECT_DIR/.claudeignore"; then
  echo -e "  ${GREEN}PASS${NC} TC-105: .claudeignore has .env pattern"
  ((PASS_COUNT++))
else
  echo -e "  ${RED}FAIL${NC} TC-105: .claudeignore missing .env pattern"
  ((FAIL_COUNT++))
fi

# TC-106: .claudeignore has tfstate pattern
if grep -q 'tfstate' "$PROJECT_DIR/.claudeignore"; then
  echo -e "  ${GREEN}PASS${NC} TC-106: .claudeignore has tfstate pattern"
  ((PASS_COUNT++))
else
  echo -e "  ${RED}FAIL${NC} TC-106: .claudeignore missing tfstate pattern"
  ((FAIL_COUNT++))
fi

echo ""

# =========================================
# 5. Regression tests
# =========================================

echo "--- Regression tests ---"

# TC-107: Existing pytest tests pass
PYTEST_RESULT=$(DATABASE_URL=sqlite:// python3 -m pytest "$PROJECT_DIR/tests/" -q --tb=no 2>&1 | tail -1)
if echo "$PYTEST_RESULT" | grep -q "passed"; then
  echo -e "  ${GREEN}PASS${NC} TC-107: existing tests pass ($PYTEST_RESULT)"
  ((PASS_COUNT++))
else
  echo -e "  ${RED}FAIL${NC} TC-107: existing tests failed ($PYTEST_RESULT)"
  ((FAIL_COUNT++))
fi

# TC-108: ruff lint passes
RUFF_RESULT=$(ruff check "$PROJECT_DIR/app/" "$PROJECT_DIR/tests/" "$PROJECT_DIR/lambda/" 2>&1)
if echo "$RUFF_RESULT" | grep -q "All checks passed"; then
  echo -e "  ${GREEN}PASS${NC} TC-108: ruff lint passes"
  ((PASS_COUNT++))
else
  echo -e "  ${RED}FAIL${NC} TC-108: ruff lint failed ($RUFF_RESULT)"
  ((FAIL_COUNT++))
fi

echo ""

# =========================================
# Summary
# =========================================

echo "========================================="
TOTAL=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))
echo -e " Results: ${GREEN}$PASS_COUNT PASS${NC} / ${RED}$FAIL_COUNT FAIL${NC} / ${YELLOW}$SKIP_COUNT SKIP${NC} (Total: $TOTAL)"
echo "========================================="

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
exit 0
