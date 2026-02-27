#!/usr/bin/env bash
# test/test_integration.sh — End-to-end integration tests

# Skip if BX_SKIP_INTEGRATION is set
if [[ "${BX_SKIP_INTEGRATION:-1}" == "1" ]]; then
  echo "  Skipping integration tests (set BX_SKIP_INTEGRATION=0 to enable)"
  return 0 2>/dev/null || exit 0
fi

BX="$PROJECT_ROOT/bin/bx"
SAMPLE="$PROJECT_ROOT/test/fixtures/sample-collection"

# -- Version --

test_integration_version() {
  local output
  output=$("$BX" version 2>&1)
  assert_contains "$output" "bx v" "version command output"
}

# -- Help --

test_integration_help() {
  local output
  output=$("$BX" help 2>&1)
  assert_contains "$output" "USAGE" "help shows usage"
  assert_contains "$output" "COMMANDS" "help shows commands"
}

# -- List --

test_integration_ls() {
  local output
  output=$(BX_COLLECTION="$SAMPLE" NO_COLOR=1 "$BX" ls 2>&1)
  assert_contains "$output" "get-user" "ls shows get-user"
  assert_contains "$output" "GET" "ls shows methods"
}

# -- Envs --

test_integration_envs() {
  local output
  output=$(BX_COLLECTION="$SAMPLE" NO_COLOR=1 "$BX" envs 2>&1)
  assert_contains "$output" "dev" "envs shows dev"
  assert_contains "$output" "staging" "envs shows staging"
}

# -- Dry Run --

test_integration_dry_run() {
  local output
  output=$(BX_COLLECTION="$SAMPLE" "$BX" get-user -e dev --dry-run --curl 2>&1)
  assert_contains "$output" "curl" "dry-run shows curl command"
  assert_contains "$output" "https://api.dev.example.com" "dry-run resolves URL"
}

# -- Inspect --

test_integration_inspect() {
  local output
  output=$(BX_COLLECTION="$SAMPLE" NO_COLOR=1 "$BX" inspect get-user -e dev 2>&1)
  assert_contains "$output" "GET" "inspect shows method"
  assert_contains "$output" "https://api.dev.example.com" "inspect resolves URL"
  assert_contains "$output" "Bearer" "inspect shows auth"
}

# -- Var override --

test_integration_var_override() {
  local output
  output=$(BX_COLLECTION="$SAMPLE" "$BX" get-user -e dev --var "userId=999" --dry-run --curl 2>&1)
  assert_contains "$output" "999" "var override applied"
}

# -- Header override --

test_integration_header_override() {
  local output
  output=$(BX_COLLECTION="$SAMPLE" "$BX" get-user -e dev --dry-run --curl -H "X-Custom: test" 2>&1)
  assert_contains "$output" "X-Custom" "header override in command"
}
