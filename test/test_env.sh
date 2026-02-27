#!/usr/bin/env bash
# test/test_env.sh — Tests for environment variable loading & resolution

# Source the modules
source "$PROJECT_ROOT/lib/utils.sh"
source "$PROJECT_ROOT/lib/output.sh"
source "$PROJECT_ROOT/lib/env.sh"

FIXTURES="$PROJECT_ROOT/test/fixtures"
SAMPLE="$FIXTURES/sample-collection"

# -- parse_env_file --

test_parse_env_file_vars() {
  local output
  output=$(parse_env_file "$SAMPLE/environments/dev.bru")
  assert_contains "$output" "baseUrl=https://api.dev.example.com" "parse baseUrl"
  assert_contains "$output" "token=dev-token-123" "parse token"
  assert_contains "$output" "userId=1" "parse userId"
}

test_parse_env_file_secret_vars() {
  local output
  output=$(parse_env_file "$SAMPLE/environments/dev.bru")
  assert_contains "$output" "apiKey=dev-secret-key-456" "parse secret vars"
}

test_parse_env_file_skip_disabled() {
  local output
  output=$(parse_env_file "$SAMPLE/environments/dev.bru")
  assert_not_contains "$output" "disabledVar" "skip disabled vars"
}

test_parse_env_file_nonexistent() {
  local output
  output=$(parse_env_file "/nonexistent/file.bru" 2>&1)
  assert_eq "" "$output" "nonexistent file returns empty"
}

# -- resolve_vars --

test_resolve_single_variable() {
  local result
  result=$(resolve_vars "{{baseUrl}}/users" "baseUrl=https://api.example.com" 2>/dev/null)
  assert_eq "https://api.example.com/users" "$result" "resolve single variable"
}

test_resolve_multiple_variables() {
  local result
  result=$(resolve_vars "{{baseUrl}}/users/{{userId}}" "baseUrl=https://api.example.com" "userId=42" 2>/dev/null)
  assert_eq "https://api.example.com/users/42" "$result" "resolve multiple variables"
}

test_resolve_unresolved_left_intact() {
  local result
  result=$(resolve_vars "{{baseUrl}}/users/{{unknown}}" "baseUrl=https://api.example.com" 2>/dev/null)
  assert_contains "$result" "{{unknown}}" "unresolved variable left intact"
}

test_resolve_unresolved_warns() {
  local output
  output=$(resolve_vars "{{missing}}" 2>&1 >/dev/null)
  assert_contains "$output" "unresolved variable" "warn about unresolved variable"
}

test_resolve_variable_in_json() {
  local result
  result=$(resolve_vars '{"name": "{{userName}}"}' "userName=TestUser" 2>/dev/null)
  assert_eq '{"name": "TestUser"}' "$result" "resolve variable in JSON"
}

test_cli_var_overrides_env() {
  # When same key appears in both env and cli, last one wins
  local result
  result=$(resolve_vars "{{userId}}" "userId=1" "userId=42" 2>/dev/null)
  assert_eq "42" "$result" "CLI var overrides env"
}

test_resolve_case_sensitive() {
  local result
  result=$(resolve_vars "{{baseUrl}} {{baseurl}}" "baseUrl=correct" 2>/dev/null)
  assert_contains "$result" "correct" "case-sensitive match"
  assert_contains "$result" "{{baseurl}}" "case mismatch left intact"
}
