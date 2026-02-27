#!/usr/bin/env bash
# lib/env.sh — Environment variable loading & resolution

parse_env_file() {
  local env_file="$1"
  [[ -f "$env_file" ]] || return

  awk '
    /^vars[[:space:]]*\{/ { in_vars=1; next }
    /^vars:secret[[:space:]]*\{/ { in_secret=1; next }
    in_vars && /^\}/ { in_vars=0; next }
    in_secret && /^\}/ { in_secret=0; next }
    (in_vars || in_secret) {
      gsub(/\r$/, "")
      gsub(/^[[:space:]]+/, "")
      if ($0 == "" || /^~/ || /^\/\//) next
      idx = index($0, ":")
      if (idx > 0) {
        key = substr($0, 1, idx-1)
        val = substr($0, idx+1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
        print key "=" val
      }
    }
  ' "$env_file"
}

load_environment() {
  local root="$1"
  local name="$2"

  local env_file="$root/environments/${name}.bru"
  [[ -f "$env_file" ]] || die "Environment '${name}' not found. Run 'bx envs' to see available environments."

  parse_env_file "$env_file"
}

resolve_vars() {
  local text="$1"
  shift

  # Build associative array — last value for each key wins
  local -A var_map=()
  local -a var_order=()
  for kv in "$@"; do
    local key="${kv%%=*}"
    local val="${kv#*=}"
    if [[ -z "${var_map[$key]+x}" ]]; then
      var_order+=("$key")
    fi
    var_map["$key"]="$val"
  done

  # Apply resolved values
  for key in "${var_order[@]}"; do
    text="${text//\{\{$key\}\}/${var_map[$key]}}"
  done

  # Warn about unresolved variables
  local remaining
  remaining=$(echo "$text" | grep -oE '\{\{[^}]+\}\}' || true)
  if [[ -n "$remaining" ]]; then
    while IFS= read -r var; do
      [[ -n "$var" ]] && warn "unresolved variable '$var'"
    done <<< "$remaining"
  fi

  echo "$text"
}
