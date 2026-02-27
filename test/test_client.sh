#!/usr/bin/env bash
# test/test_client.sh — Tests for HTTP client command building

# Source the modules
source "$PROJECT_ROOT/lib/utils.sh"
source "$PROJECT_ROOT/lib/output.sh"
source "$PROJECT_ROOT/lib/env.sh"
source "$PROJECT_ROOT/lib/parser.sh"
source "$PROJECT_ROOT/lib/client.sh"

# Helper: convert null-delimited output to space-separated string
cmd_to_str() {
  local result=""
  while IFS= read -r -d '' item; do
    [[ -n "$result" ]] && result+=" "
    result+="$item"
  done
  echo "$result"
}

# -- detect_http_client --

test_detect_forced_client() {
  if command -v curl &>/dev/null; then
    local result
    result=$(detect_http_client "curl")
    assert_eq "curl" "$result" "detect forced curl client"
  fi
}

test_detect_nonexistent_client() {
  local code=0
  (detect_http_client "nonexistent-client-xyz" >/dev/null 2>&1) || code=$?
  assert_not_eq "0" "$code" "fail for nonexistent client"
}

# -- build_xh_cmd --

test_build_xh_get() {
  local result
  result=$(build_xh_cmd "GET" "https://example.com/api" "false" \
    --header "Accept: application/json" | cmd_to_str)
  assert_contains "$result" "xh" "xh in command"
  assert_contains "$result" "--print=hHbB" "xh print flag"
  assert_contains "$result" "GET" "method in command"
  assert_contains "$result" "https://example.com/api" "URL in command"
  assert_contains "$result" "Accept:application/json" "header in command"
}

test_build_xh_post_with_body() {
  local result
  result=$(build_xh_cmd "POST" "https://example.com/api" "false" \
    --header "Content-Type: application/json" \
    --body '{"name":"test"}' \
    --bearer "token123" | cmd_to_str)
  assert_contains "$result" "POST" "POST method"
  assert_contains "$result" "--raw" "raw flag for body"
  assert_contains "$result" '{"name":"test"}' "body content"
  assert_contains "$result" "Authorization:Bearer token123" "bearer in command"
}

test_build_xh_raw_mode() {
  local result
  result=$(build_xh_cmd "GET" "https://example.com/api" "true" | cmd_to_str)
  assert_contains "$result" "--body" "xh --body for raw mode"
  assert_not_contains "$result" "--print" "no --print in raw mode"
}

test_build_xh_basic_auth() {
  local result
  result=$(build_xh_cmd "GET" "https://example.com/api" "false" \
    --basic-user "admin" --basic-pass "secret" | cmd_to_str)
  assert_contains "$result" "--auth" "xh auth flag"
  assert_contains "$result" "admin:secret" "basic auth credentials"
}

test_build_xh_form_data() {
  local result
  result=$(build_xh_cmd "POST" "https://example.com/api" "false" \
    --form "username=test" --form "password=secret" | cmd_to_str)
  assert_contains "$result" "username=test" "form field 1"
  assert_contains "$result" "password=secret" "form field 2"
}

# -- build_curlie_cmd --

test_build_curlie_get() {
  local result
  result=$(build_curlie_cmd "GET" "https://example.com/api" "false" \
    --header "Accept: application/json" | cmd_to_str)
  assert_contains "$result" "curlie" "curlie in command"
  assert_contains "$result" "-X" "method flag"
  assert_contains "$result" "GET" "method"
  assert_contains "$result" "-H" "header flag"
  assert_contains "$result" "Accept: application/json" "header value"
}

test_build_curlie_bearer() {
  local result
  result=$(build_curlie_cmd "GET" "https://example.com/api" "false" \
    --bearer "mytoken" | cmd_to_str)
  assert_contains "$result" "Authorization: Bearer mytoken" "bearer header"
}

test_build_curlie_raw() {
  local result
  result=$(build_curlie_cmd "GET" "https://example.com/api" "true" | cmd_to_str)
  assert_contains "$result" "-s" "silent flag in raw mode"
}

# -- build_curl_cmd --

test_build_curl_get() {
  local result
  result=$(build_curl_cmd "GET" "https://example.com/api" "false" \
    --header "Accept: application/json" | cmd_to_str)
  assert_contains "$result" "curl" "curl in command"
  assert_contains "$result" "-s" "silent flag"
  assert_contains "$result" "-i" "include headers flag"
  assert_contains "$result" "GET" "method"
}

test_build_curl_raw() {
  local result
  result=$(build_curl_cmd "GET" "https://example.com/api" "true" | cmd_to_str)
  assert_contains "$result" "-s" "silent flag"
  assert_not_contains "$result" "-i" "no include in raw mode"
}

test_build_curl_body() {
  local result
  result=$(build_curl_cmd "POST" "https://example.com/api" "false" \
    --body '{"key":"value"}' | cmd_to_str)
  assert_contains "$result" "-d" "data flag"
  assert_contains "$result" '{"key":"value"}' "body content"
}

test_build_curl_basic_auth() {
  local result
  result=$(build_curl_cmd "GET" "https://example.com/api" "false" \
    --basic-user "user" --basic-pass "pass" | cmd_to_str)
  assert_contains "$result" "-u" "auth flag"
  assert_contains "$result" "user:pass" "credentials"
}

test_build_curl_form() {
  local result
  result=$(build_curl_cmd "POST" "https://example.com/api" "false" \
    --form "key=value" | cmd_to_str)
  assert_contains "$result" "--data-urlencode" "form encoding flag"
  assert_contains "$result" "key=value" "form data"
}
