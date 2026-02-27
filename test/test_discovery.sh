#!/usr/bin/env bash
# test/test_discovery.sh — Tests for collection + request file discovery

# Source the modules
source "$PROJECT_ROOT/lib/utils.sh"
source "$PROJECT_ROOT/lib/output.sh"
source "$PROJECT_ROOT/lib/discovery.sh"

FIXTURES="$PROJECT_ROOT/test/fixtures"
SAMPLE="$FIXTURES/sample-collection"

# -- find_collection_root --

test_find_root_via_bx_collection() {
  local result
  result=$(BX_COLLECTION="$SAMPLE" find_collection_root 2>/dev/null)
  assert_eq "$SAMPLE" "$result" "find root via BX_COLLECTION"
}

test_find_root_via_walk_up() {
  local result
  local saved_pwd="$PWD"
  cd "$SAMPLE/users"
  result=$(find_collection_root 2>/dev/null)
  cd "$saved_pwd"
  assert_eq "$SAMPLE" "$result" "find root by walking up"
}

test_find_root_error_no_collection() {
  local code=0
  local saved_pwd="$PWD"
  cd /tmp
  unset BX_COLLECTION
  (find_collection_root >/dev/null 2>&1) || code=$?
  cd "$saved_pwd"
  assert_not_eq "0" "$code" "exit non-zero when no collection found"
}

test_find_root_bad_bx_collection() {
  local output code=0
  output=$(BX_COLLECTION="/tmp" find_collection_root 2>&1) || code=$?
  assert_not_eq "0" "$code" "exit non-zero for invalid BX_COLLECTION"
  assert_contains "$output" "does not contain" "error message mentions bruno.json"
}

# -- find_request_file --

test_find_exact_path() {
  local result
  result=$(find_request_file "$SAMPLE" "users/get-user" 2>/dev/null)
  assert_eq "$SAMPLE/users/get-user.bru" "$result" "exact path match"
}

test_find_filename_match() {
  local result
  result=$(find_request_file "$SAMPLE" "get-user" 2>/dev/null)
  assert_contains "$result" "get-user.bru" "filename match"
}

test_find_no_match() {
  local code=0
  local output
  output=$(find_request_file "$SAMPLE" "nonexistent-request" 2>&1) || code=$?
  assert_not_eq "0" "$code" "exit non-zero for no match"
  assert_contains "$output" "not found" "error says not found"
}

# -- list_requests --

test_list_requests_finds_all() {
  local output
  output=$(NO_COLOR=1 list_requests "$SAMPLE" 2>&1)
  assert_contains "$output" "get-user" "lists get-user"
  assert_contains "$output" "create-user" "lists create-user"
  assert_contains "$output" "list-users" "lists list-users"
  assert_contains "$output" "get-order" "lists get-order"
  assert_contains "$output" "create-order" "lists create-order"
  assert_contains "$output" "login" "lists login"
  assert_contains "$output" "refresh-token" "lists refresh-token"
}

test_list_requests_shows_methods() {
  local output
  output=$(NO_COLOR=1 list_requests "$SAMPLE" 2>&1)
  assert_contains "$output" "GET" "shows GET method"
  assert_contains "$output" "POST" "shows POST method"
}

# -- list_envs --

test_list_envs() {
  local output
  output=$(NO_COLOR=1 list_envs "$SAMPLE" 2>&1)
  assert_contains "$output" "dev" "lists dev environment"
  assert_contains "$output" "staging" "lists staging environment"
  assert_contains "$output" "production" "lists production environment"
}

test_list_envs_no_dir() {
  local output
  output=$(NO_COLOR=1 list_envs "/tmp" 2>&1)
  assert_contains "$output" "No environments" "warns when no environments dir"
}
