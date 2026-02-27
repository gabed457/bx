#!/usr/bin/env bash
# lib/discovery.sh — Collection root & request file discovery

find_collection_root() {
  if [[ -n "${BX_COLLECTION:-}" ]]; then
    if [[ -f "$BX_COLLECTION/bruno.json" ]]; then
      echo "$BX_COLLECTION"
      return
    fi
    die "BX_COLLECTION='$BX_COLLECTION' does not contain a bruno.json"
  fi

  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/bruno.json" ]]; then
      echo "$dir"
      return
    fi
    dir="$(dirname "$dir")"
  done

  die "No Bruno collection found. Set BX_COLLECTION or cd into a collection."
}

find_request_file() {
  local root="$1"
  local name="$2"

  # Exact path match
  if [[ -f "$root/$name.bru" ]]; then
    echo "$root/$name.bru"
    return
  fi

  # Filename match
  local matches
  matches=$(find "$root" -name "${name}.bru" -not -path '*/environments/*' 2>/dev/null)
  local count
  count=$(echo "$matches" | grep -c '.' 2>/dev/null || true)

  if [[ "$count" -eq 1 ]]; then
    echo "$matches"
    return
  fi

  if [[ "$count" -gt 1 ]]; then
    echo -e "${RED}error:${RESET} Ambiguous request '${name}'. Matches:" >&2
    echo "$matches" | while read -r f; do
      echo "  ${f#"$root"/}" >&2
    done
    echo "" >&2
    echo "Use the full path: bx folder/request-name" >&2
    exit 3
  fi

  # Fuzzy match
  matches=$(find "$root" -name "*.bru" -not -path '*/environments/*' 2>/dev/null | grep -i "$name" || true)
  count=$(echo "$matches" | grep -c '.' 2>/dev/null || true)

  if [[ "$count" -eq 1 ]]; then
    echo "$matches"
    return
  fi

  if [[ "$count" -gt 1 ]]; then
    echo -e "${RED}error:${RESET} No exact match for '${name}'. Did you mean:" >&2
    echo "$matches" | while read -r f; do
      echo "  ${f#"$root"/}" >&2
    done | head -10
    exit 3
  fi

  die "Request '${name}' not found. Run 'bx ls' to see available requests."
}

list_requests() {
  local root="$1"
  echo -e "${BOLD}Requests in collection:${RESET}"
  echo ""

  find "$root" -name '*.bru' -not -path '*/environments/*' | sort | while read -r file; do
    local rel="${file#"$root"/}"
    rel="${rel%.bru}"

    local method
    method=$(awk '/^(get|post|put|patch|delete|options|head)[[:space:]]*\{/ { print toupper($1); exit }' "$file")
    method="${method:-???}"

    local name
    name=$(awk '/^meta[[:space:]]*\{/,/^\}/' "$file" | awk -F': ' '/^  name:/ { print $2; exit }')

    local method_color
    case "$method" in
      GET)     method_color="${GREEN}" ;;
      POST)    method_color="${BLUE}" ;;
      PUT|PATCH) method_color="${YELLOW}" ;;
      DELETE)  method_color="${RED}" ;;
      *)       method_color="${DIM}" ;;
    esac

    printf "  ${method_color}%-7s${RESET} ${BOLD}%-30s${RESET} ${DIM}%s${RESET}\n" "$method" "$rel" "${name:-}"
  done
}

list_envs() {
  local root="$1"
  local env_dir="$root/environments"

  if [[ ! -d "$env_dir" ]]; then
    warn "No environments directory found at $env_dir"
    return
  fi

  echo -e "${BOLD}Available environments:${RESET}"
  echo ""

  for f in "$env_dir"/*.bru; do
    [[ -f "$f" ]] || continue
    local name
    name="$(basename "$f" .bru)"

    local count
    count=$(awk '/^vars[[:space:]]*\{/,/^\}/' "$f" | grep -cE '^\s+\S+:' || true)

    printf "  ${CYAN}%-15s${RESET} ${DIM}(%d variables)${RESET}\n" "$name" "$count"
  done
}
