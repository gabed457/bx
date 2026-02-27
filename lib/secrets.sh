#!/usr/bin/env bash
# lib/secrets.sh — Bruno Desktop encrypted secrets decryption

load_secrets() {
  local root="$1"
  local env_name="$2"

  # Require node
  command -v node >/dev/null 2>&1 || { debug "node not found, skipping secrets"; return; }

  # Determine secrets.json path (used only for existence check;
  # the Node script resolves its own path via BX_SECRETS_FILE or platform default)
  local secrets_file
  if [[ -n "${BX_SECRETS_FILE:-}" ]]; then
    secrets_file="$BX_SECRETS_FILE"
  elif [[ "$(uname)" == "Darwin" ]]; then
    secrets_file="$HOME/Library/Application Support/bruno/secrets.json"
  else
    secrets_file="${XDG_CONFIG_HOME:-$HOME/.config}/bruno/secrets.json"
  fi
  [[ -f "$secrets_file" ]] || { debug "no secrets.json found"; return; }

  local decrypt_script="$BX_LIB/decrypt-secrets.js"

  if [[ "${BX_DEBUG:-}" == "1" ]]; then
    node "$decrypt_script" --collection-path "$root" --env "$env_name"
  else
    node "$decrypt_script" --collection-path "$root" --env "$env_name" 2>/dev/null
  fi
}
