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

  # Build parallel arrays — last value for each key wins (Bash 3.2 compatible)
  local -a var_keys=() var_vals=()
  for kv in "$@"; do
    local key="${kv%%=*}"
    local val="${kv#*=}"
    local found=false
    local i
    if [[ ${#var_keys[@]} -gt 0 ]]; then
      for i in "${!var_keys[@]}"; do
        if [[ "${var_keys[$i]}" == "$key" ]]; then
          var_vals[i]="$val"
          found=true
          break
        fi
      done
    fi
    if [[ "$found" == false ]]; then
      var_keys+=("$key")
      var_vals+=("$val")
    fi
  done

  # Apply resolved values
  local i
  if [[ ${#var_keys[@]} -gt 0 ]]; then
    for i in "${!var_keys[@]}"; do
      text="${text//\{\{${var_keys[$i]}\}\}/${var_vals[$i]}}"
    done
  fi

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
