#!/usr/bin/env bash
# test/test_secrets.sh — Tests for Bruno Desktop encrypted secrets

source "$PROJECT_ROOT/lib/utils.sh"
source "$PROJECT_ROOT/lib/output.sh"
source "$PROJECT_ROOT/lib/secrets.sh"

FIXTURES="$PROJECT_ROOT/test/fixtures"
SAMPLE="$FIXTURES/sample-collection"
DECRYPT_SCRIPT="$PROJECT_ROOT/lib/decrypt-secrets.js"

# Helper: create a temp secrets.json with the collection path filled in
_make_secrets_fixture() {
  local collection_path="$1"
  local tmp
  tmp=$(mktemp)
  sed "s|__COLLECTION_PATH__|${collection_path}|g" "$FIXTURES/secrets.json" > "$tmp"
  echo "$tmp"
}

# -- Node.js decrypt script direct tests --

test_decrypt_node_aes256() {
  command -v node >/dev/null 2>&1 || { SKIP=$((SKIP + 1)); return; }

  local fixture
  fixture=$(_make_secrets_fixture "$SAMPLE")
  local output
  output=$(BX_SECRETS_FILE="$fixture" BX_MACHINE_ID="test-machine-id" \
    node "$DECRYPT_SCRIPT" --collection-path "$SAMPLE" --env dev 2>/dev/null)
  rm -f "$fixture"
  assert_contains "$output" "apiKey=decrypted-secret-value" "decrypt $01: AES-256 secret"
}

test_decrypt_node_no_secrets_file() {
  command -v node >/dev/null 2>&1 || { SKIP=$((SKIP + 1)); return; }

  local output
  local rc=0
  output=$(BX_SECRETS_FILE="/nonexistent/secrets.json" \
    node "$DECRYPT_SCRIPT" --collection-path "$SAMPLE" --env dev 2>/dev/null) || rc=$?
  assert_eq "0" "$rc" "exit 0 when secrets.json missing"
  assert_eq "" "$output" "no output when secrets.json missing"
}

test_decrypt_node_no_matching_collection() {
  command -v node >/dev/null 2>&1 || { SKIP=$((SKIP + 1)); return; }

  local fixture
  fixture=$(_make_secrets_fixture "$SAMPLE")
  local output
  output=$(BX_SECRETS_FILE="$fixture" BX_MACHINE_ID="test-machine-id" \
    node "$DECRYPT_SCRIPT" --collection-path "/no/such/collection" --env dev 2>/dev/null)
  rm -f "$fixture"
  assert_eq "" "$output" "no output for unmatched collection"
}

test_decrypt_node_no_matching_env() {
  command -v node >/dev/null 2>&1 || { SKIP=$((SKIP + 1)); return; }

  local fixture
  fixture=$(_make_secrets_fixture "$SAMPLE")
  local output
  output=$(BX_SECRETS_FILE="$fixture" BX_MACHINE_ID="test-machine-id" \
    node "$DECRYPT_SCRIPT" --collection-path "$SAMPLE" --env nonexistent 2>/dev/null)
  rm -f "$fixture"
  assert_eq "" "$output" "no output for unmatched env"
}

test_decrypt_node_wrong_machine_id() {
  command -v node >/dev/null 2>&1 || { SKIP=$((SKIP + 1)); return; }

  local fixture
  fixture=$(_make_secrets_fixture "$SAMPLE")
  local output
  output=$(BX_SECRETS_FILE="$fixture" BX_MACHINE_ID="wrong-machine-id" \
    node "$DECRYPT_SCRIPT" --collection-path "$SAMPLE" --env dev 2>/dev/null)
  rm -f "$fixture"
  assert_eq "" "$output" "no output with wrong machine ID"
}

# -- Bash load_secrets wrapper tests --

test_load_secrets_with_valid_secrets() {
  command -v node >/dev/null 2>&1 || { SKIP=$((SKIP + 1)); return; }

  local fixture
  fixture=$(_make_secrets_fixture "$SAMPLE")
  local output
  # Set BX_LIB so load_secrets can find the decrypt script
  output=$(BX_LIB="$PROJECT_ROOT/lib" BX_SECRETS_FILE="$fixture" BX_MACHINE_ID="test-machine-id" \
    load_secrets "$SAMPLE" "dev" 2>/dev/null)
  rm -f "$fixture"
  assert_contains "$output" "apiKey=decrypted-secret-value" "load_secrets returns decrypted pairs"
}

test_load_secrets_no_secrets_file() {
  command -v node >/dev/null 2>&1 || { SKIP=$((SKIP + 1)); return; }

  local output
  output=$(BX_LIB="$PROJECT_ROOT/lib" BX_SECRETS_FILE="/nonexistent/secrets.json" \
    load_secrets "$SAMPLE" "dev" 2>/dev/null)
  assert_eq "" "$output" "load_secrets returns empty when no secrets.json"
}

test_load_secrets_no_node() {
  # Temporarily override PATH to hide node
  local output
  output=$(PATH="/usr/bin:/bin" BX_LIB="$PROJECT_ROOT/lib" \
    load_secrets "$SAMPLE" "dev" 2>/dev/null)
  assert_eq "" "$output" "load_secrets returns empty when node unavailable"
}
