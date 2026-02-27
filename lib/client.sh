#!/usr/bin/env bash
# lib/client.sh — HTTP client abstraction (xh/curlie/curl)

detect_http_client() {
  local forced="${1:-}"
  if [[ -n "$forced" ]]; then
    command -v "$forced" &>/dev/null || die "$forced is not installed"
    echo "$forced"
    return
  fi

  if [[ -n "${BX_HTTP_CLIENT:-}" ]]; then
    command -v "$BX_HTTP_CLIENT" &>/dev/null || die "BX_HTTP_CLIENT='$BX_HTTP_CLIENT' is not installed"
    echo "$BX_HTTP_CLIENT"
    return
  fi

  for client in xh curlie curl; do
    if command -v "$client" &>/dev/null; then
      echo "$client"
      return
    fi
  done

  die "No HTTP client found. Install xh, curlie, or curl."
}

build_xh_cmd() {
  local method="$1" url="$2" raw="$3"
  shift 3
  local -a resolved_headers=() resolved_form=()
  local body="" bearer="" basic_user="" basic_pass=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --header) resolved_headers+=("$2"); shift ;;
      --body) body="$2"; shift ;;
      --bearer) bearer="$2"; shift ;;
      --basic-user) basic_user="$2"; shift ;;
      --basic-pass) basic_pass="$2"; shift ;;
      --form) resolved_form+=("$2"); shift ;;
    esac
    shift
  done

  local -a cmd=()
  if [[ "$raw" == "true" ]]; then
    cmd=(xh --body "$method" "$url")
  else
    cmd=(xh --print=hHbB "$method" "$url")
  fi

  for h in "${resolved_headers[@]}"; do
    cmd+=("${h%%:*}:${h#*: }")
  done
  if [[ -n "$bearer" ]]; then
    cmd+=("Authorization:Bearer ${bearer}")
  fi
  if [[ -n "$basic_user" ]]; then
    cmd+=(--auth "${basic_user}:${basic_pass}")
  fi
  if [[ -n "$body" ]]; then
    cmd+=(--raw "$body")
  fi
  for f in "${resolved_form[@]}"; do
    cmd+=("$f")
  done

  printf '%s\0' "${cmd[@]}"
}

build_curlie_cmd() {
  local method="$1" url="$2" raw="$3"
  shift 3
  local -a resolved_headers=() resolved_form=()
  local body="" bearer="" basic_user="" basic_pass=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --header) resolved_headers+=("$2"); shift ;;
      --body) body="$2"; shift ;;
      --bearer) bearer="$2"; shift ;;
      --basic-user) basic_user="$2"; shift ;;
      --basic-pass) basic_pass="$2"; shift ;;
      --form) resolved_form+=("$2"); shift ;;
    esac
    shift
  done

  local -a cmd=()
  if [[ "$raw" == "true" ]]; then
    cmd=(curlie -s -X "$method" "$url")
  else
    cmd=(curlie -X "$method" "$url")
  fi

  for h in "${resolved_headers[@]}"; do
    cmd+=(-H "$h")
  done
  if [[ -n "$bearer" ]]; then
    cmd+=(-H "Authorization: Bearer ${bearer}")
  fi
  if [[ -n "$basic_user" ]]; then
    cmd+=(-u "${basic_user}:${basic_pass}")
  fi
  if [[ -n "$body" ]]; then
    cmd+=(-d "$body")
  fi
  for f in "${resolved_form[@]}"; do
    cmd+=(--data-urlencode "$f")
  done

  printf '%s\0' "${cmd[@]}"
}

build_curl_cmd() {
  local method="$1" url="$2" raw="$3"
  shift 3
  local -a resolved_headers=() resolved_form=()
  local body="" bearer="" basic_user="" basic_pass=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --header) resolved_headers+=("$2"); shift ;;
      --body) body="$2"; shift ;;
      --bearer) bearer="$2"; shift ;;
      --basic-user) basic_user="$2"; shift ;;
      --basic-pass) basic_pass="$2"; shift ;;
      --form) resolved_form+=("$2"); shift ;;
    esac
    shift
  done

  local -a cmd=()
  if [[ "$raw" == "true" ]]; then
    cmd=(curl -s -X "$method" "$url")
  else
    cmd=(curl -s -i -X "$method" "$url")
  fi

  for h in "${resolved_headers[@]}"; do
    cmd+=(-H "$h")
  done
  if [[ -n "$bearer" ]]; then
    cmd+=(-H "Authorization: Bearer ${bearer}")
  fi
  if [[ -n "$basic_user" ]]; then
    cmd+=(-u "${basic_user}:${basic_pass}")
  fi
  if [[ -n "$body" ]]; then
    cmd+=(-d "$body")
  fi
  for f in "${resolved_form[@]}"; do
    cmd+=(--data-urlencode "$f")
  done

  printf '%s\0' "${cmd[@]}"
}

execute_request() {
  local client="$1" dry_run="$2" verbose="$3" raw="$4"
  shift 4
  local -a env_vars=("$@")

  # Resolve URL
  local resolved_url="$BX_URL"
  resolved_url=$(resolve_vars "$resolved_url" "${env_vars[@]}")

  # Append query params
  if [[ ${#BX_QUERY_PARAMS[@]} -gt 0 ]]; then
    local sep="?"
    [[ "$resolved_url" == *"?"* ]] && sep="&"
    for qp in "${BX_QUERY_PARAMS[@]}"; do
      local qkey="${qp%%:*}"
      local qval="${qp#*:}"
      qval="${qval#"${qval%%[![:space:]]*}"}"
      qkey=$(resolve_vars "$qkey" "${env_vars[@]}")
      qval=$(resolve_vars "$qval" "${env_vars[@]}")
      resolved_url="${resolved_url}${sep}${qkey}=${qval}"
      sep="&"
    done
  fi

  # Resolve body
  local resolved_body=""
  if [[ -n "$BX_BODY" ]]; then
    resolved_body=$(resolve_vars "$BX_BODY" "${env_vars[@]}")
  fi

  # Resolve auth
  local resolved_bearer=""
  if [[ "$BX_AUTH_TYPE" == "bearer" ]]; then
    resolved_bearer=$(resolve_vars "$BX_AUTH_TOKEN" "${env_vars[@]}")
  elif [[ "$BX_AUTH_TYPE" == "none" && "${BX_COLLECTION_AUTH_TYPE:-none}" == "bearer" ]]; then
    resolved_bearer=$(resolve_vars "${BX_COLLECTION_AUTH_TOKEN:-}" "${env_vars[@]}")
  fi
  local resolved_basic_user="" resolved_basic_pass=""
  if [[ "$BX_AUTH_TYPE" == "basic" ]]; then
    resolved_basic_user=$(resolve_vars "$BX_AUTH_USER" "${env_vars[@]}")
    resolved_basic_pass=$(resolve_vars "$BX_AUTH_PASS" "${env_vars[@]}")
  elif [[ "$BX_AUTH_TYPE" == "none" && "${BX_COLLECTION_AUTH_TYPE:-none}" == "basic" ]]; then
    resolved_basic_user=$(resolve_vars "${BX_COLLECTION_AUTH_USER:-}" "${env_vars[@]}")
    resolved_basic_pass=$(resolve_vars "${BX_COLLECTION_AUTH_PASS:-}" "${env_vars[@]}")
  fi

  # Resolve headers — merge collection headers with request headers
  local -a resolved_headers=()
  local -A header_map=()

  # Collection headers first (lower priority)
  if [[ ${#BX_COLLECTION_HEADERS[@]} -gt 0 ]]; then
    for h in "${BX_COLLECTION_HEADERS[@]}"; do
      local hkey="${h%%:*}"
      local hval="${h#*:}"
      hval="${hval#"${hval%%[![:space:]]*}"}"
      hval=$(resolve_vars "$hval" "${env_vars[@]}")
      local hkey_lower
      hkey_lower=$(echo "$hkey" | tr '[:upper:]' '[:lower:]')
      header_map["$hkey_lower"]="${hkey}: ${hval}"
    done
  fi

  # Request headers override collection headers
  for h in "${BX_HEADERS[@]}"; do
    local hkey="${h%%:*}"
    local hval="${h#*:}"
    hval="${hval#"${hval%%[![:space:]]*}"}"
    hval=$(resolve_vars "$hval" "${env_vars[@]}")
    local hkey_lower
    hkey_lower=$(echo "$hkey" | tr '[:upper:]' '[:lower:]')
    header_map["$hkey_lower"]="${hkey}: ${hval}"
  done

  # CLI --header overrides
  for h in "${BX_CLI_HEADERS[@]}"; do
    local hkey="${h%%:*}"
    local hval="${h#*:}"
    hval="${hval#"${hval%%[![:space:]]*}"}"
    local hkey_lower
    hkey_lower=$(echo "$hkey" | tr '[:upper:]' '[:lower:]')
    header_map["$hkey_lower"]="${hkey}: ${hval}"
  done

  for key in "${!header_map[@]}"; do
    resolved_headers+=("${header_map[$key]}")
  done

  # Resolve form data
  local -a resolved_form=()
  for f in "${BX_BODY_FORM[@]}"; do
    local fkey="${f%%:*}"
    local fval="${f#*:}"
    fval="${fval#"${fval%%[![:space:]]*}"}"
    fval=$(resolve_vars "$fval" "${env_vars[@]}")
    resolved_form+=("${fkey}=${fval}")
  done

  # Build command args for the builder
  local -a builder_args=()
  for h in "${resolved_headers[@]}"; do
    builder_args+=(--header "$h")
  done
  if [[ -n "$resolved_body" ]]; then
    builder_args+=(--body "$resolved_body")
  fi
  if [[ -n "$resolved_bearer" ]]; then
    builder_args+=(--bearer "$resolved_bearer")
  fi
  if [[ -n "$resolved_basic_user" ]]; then
    builder_args+=(--basic-user "$resolved_basic_user" --basic-pass "$resolved_basic_pass")
  fi
  for f in "${resolved_form[@]}"; do
    builder_args+=(--form "$f")
  done

  # Build command array
  local cmd_str
  case "$client" in
    xh)     cmd_str=$(build_xh_cmd "$BX_METHOD" "$resolved_url" "$raw" "${builder_args[@]}") ;;
    curlie) cmd_str=$(build_curlie_cmd "$BX_METHOD" "$resolved_url" "$raw" "${builder_args[@]}") ;;
    curl)   cmd_str=$(build_curl_cmd "$BX_METHOD" "$resolved_url" "$raw" "${builder_args[@]}") ;;
  esac

  # Parse null-delimited string into array
  local -a cmd=()
  while IFS= read -r -d '' item; do
    cmd+=("$item")
  done <<< "$cmd_str"

  # Verbose / dry-run output
  if [[ "$verbose" == "true" || "$dry_run" == "true" ]]; then
    local -a print_args=()
    for h in "${resolved_headers[@]}"; do print_args+=(--header "$h"); done
    [[ -n "$resolved_bearer" ]] && print_args+=(--bearer "$resolved_bearer")
    [[ -n "$resolved_body" ]] && print_args+=(--body "$resolved_body")
    print_request "$BX_METHOD" "$resolved_url" "${print_args[@]}"
  fi

  if [[ "$dry_run" == "true" ]]; then
    print_command "${cmd[@]}"
    return
  fi

  # Execute
  if [[ "$client" == "curl" && "$raw" != "true" ]]; then
    "${cmd[@]}" 2>&1 | {
      if command -v jq &>/dev/null; then
        local header_done=false
        local body=""
        while IFS= read -r line; do
          if [[ "$header_done" == false ]]; then
            if [[ "$line" == $'\r' || "$line" == "" ]]; then
              header_done=true
              echo ""
            else
              echo -e "${CYAN}${line}${RESET}"
            fi
          else
            body+="${line}"$'\n'
          fi
        done
        if [[ -n "$body" ]]; then
          echo "$body" | jq . 2>/dev/null || echo "$body"
        fi
      else
        cat
      fi
    }
  else
    "${cmd[@]}"
  fi
}
