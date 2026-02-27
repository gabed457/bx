#!/usr/bin/env bash
# lib/parser.sh — .bru file parsing

# Globals set by parse_bru_file:
#   BX_METHOD, BX_URL, BX_HEADERS[], BX_QUERY_PARAMS[],
#   BX_BODY, BX_BODY_TYPE (json|form|multipart|xml|text|graphql|none),
#   BX_BODY_FORM[], BX_BODY_GRAPHQL_VARS,
#   BX_AUTH_TYPE (bearer|basic|none), BX_AUTH_TOKEN,
#   BX_AUTH_USER, BX_AUTH_PASS

parse_bru_file() {
  local file="$1"

  # Reset globals
  BX_METHOD=""
  BX_URL=""
  BX_HEADERS=()
  BX_QUERY_PARAMS=()
  BX_BODY=""
  BX_BODY_TYPE="none"
  BX_BODY_FORM=()
  BX_BODY_GRAPHQL_VARS=""
  BX_AUTH_TYPE="none"
  BX_AUTH_TOKEN=""
  BX_AUTH_USER=""
  BX_AUTH_PASS=""

  [[ -f "$file" ]] || die "File not found: $file"

  # Strip carriage returns for Windows line endings
  local content
  content=$(tr -d '\r' < "$file")

  # Extract method
  BX_METHOD=$(echo "$content" | awk '/^(get|post|put|patch|delete|options|head)[[:space:]]*\{/ { print toupper($1); exit }')
  [[ -n "$BX_METHOD" ]] || die "Could not determine HTTP method from $file"

  # Extract URL
  local method_lower
  method_lower=$(echo "$BX_METHOD" | tr '[:upper:]' '[:lower:]')
  BX_URL=$(echo "$content" | awk -v m="$method_lower" '
    $0 ~ "^" m "[[:space:]]*\\{" { in_block=1; next }
    in_block && /^\}/ { exit }
    in_block && /url:/ {
      idx = index($0, ":")
      val = substr($0, idx+1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      print val
      exit
    }
  ')
  [[ -n "$BX_URL" ]] || die "Could not determine URL from $file"

  # Extract headers
  while IFS= read -r line; do
    [[ -n "$line" ]] && BX_HEADERS+=("$line")
  done < <(echo "$content" | awk '
    /^headers[[:space:]]*\{/ { in_block=1; next }
    in_block && /^\}/ { exit }
    in_block {
      gsub(/^[[:space:]]+/, "")
      if ($0 == "" || /^~/ || /^\/\//) next
      print
    }
  ')

  # Extract query params (both query {} and params:query {})
  while IFS= read -r line; do
    [[ -n "$line" ]] && BX_QUERY_PARAMS+=("$line")
  done < <(echo "$content" | awk '
    /^(query|params:query)[[:space:]]*\{/ { in_block=1; next }
    in_block && /^\}/ { exit }
    in_block {
      gsub(/^[[:space:]]+/, "")
      if ($0 == "" || /^~/ || /^\/\//) next
      print
    }
  ')

  # Extract body:json (handle nested braces — block ends at ^} with no leading space)
  local body_json
  body_json=$(echo "$content" | awk '
    /^body:json[[:space:]]*\{/ { in_block=1; next }
    in_block && /^\}$/ { exit }
    in_block { print }
  ')
  if [[ -n "$body_json" ]]; then
    BX_BODY="$body_json"
    BX_BODY_TYPE="json"
  fi

  # Extract body:form-urlencoded
  if [[ "$BX_BODY_TYPE" == "none" ]]; then
    while IFS= read -r line; do
      [[ -n "$line" ]] && BX_BODY_FORM+=("$line")
    done < <(echo "$content" | awk '
      /^body:form-urlencoded[[:space:]]*\{/ { in_block=1; next }
      in_block && /^\}/ { exit }
      in_block {
        gsub(/^[[:space:]]+/, "")
        if ($0 == "" || /^~/ || /^\/\//) next
        print
      }
    ')
    if [[ ${#BX_BODY_FORM[@]} -gt 0 ]]; then
      BX_BODY_TYPE="form"
    fi
  fi

  # Extract body:multipart-form
  if [[ "$BX_BODY_TYPE" == "none" ]]; then
    while IFS= read -r line; do
      [[ -n "$line" ]] && BX_BODY_FORM+=("$line")
    done < <(echo "$content" | awk '
      /^body:multipart-form[[:space:]]*\{/ { in_block=1; next }
      in_block && /^\}/ { exit }
      in_block {
        gsub(/^[[:space:]]+/, "")
        if ($0 == "" || /^~/ || /^\/\//) next
        print
      }
    ')
    if [[ ${#BX_BODY_FORM[@]} -gt 0 ]]; then
      BX_BODY_TYPE="multipart"
    fi
  fi

  # Extract body:xml, body:text, body:graphql
  if [[ "$BX_BODY_TYPE" == "none" ]]; then
    local body_raw
    body_raw=$(echo "$content" | awk '
      /^body:xml[[:space:]]*\{/ { in_block=1; btype="xml"; next }
      /^body:text[[:space:]]*\{/ { in_block=1; btype="text"; next }
      /^body:graphql[[:space:]]*\{/ { in_block=1; btype="graphql"; next }
      in_block && /^\}$/ { exit }
      in_block { print }
    ')
    if [[ -n "$body_raw" ]]; then
      BX_BODY="$body_raw"
      # Determine which type matched
      if echo "$content" | grep -q '^body:xml[[:space:]]*{'; then
        BX_BODY_TYPE="xml"
      elif echo "$content" | grep -q '^body:text[[:space:]]*{'; then
        BX_BODY_TYPE="text"
      elif echo "$content" | grep -q '^body:graphql[[:space:]]*{'; then
        BX_BODY_TYPE="graphql"
      fi
    fi
  fi

  # Extract body:graphql:vars
  BX_BODY_GRAPHQL_VARS=$(echo "$content" | awk '
    /^body:graphql:vars[[:space:]]*\{/ { in_block=1; next }
    in_block && /^\}$/ { exit }
    in_block { print }
  ')

  # Extract auth:bearer
  local bearer_token
  bearer_token=$(echo "$content" | awk '
    /^auth:bearer[[:space:]]*\{/ { in_block=1; next }
    in_block && /^\}/ { exit }
    in_block && /token:/ {
      idx = index($0, ":")
      val = substr($0, idx+1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      print val
      exit
    }
  ')
  if [[ -n "$bearer_token" ]]; then
    BX_AUTH_TYPE="bearer"
    BX_AUTH_TOKEN="$bearer_token"
  fi

  # Extract auth:basic
  local basic_user basic_pass
  basic_user=$(echo "$content" | awk '
    /^auth:basic[[:space:]]*\{/ { in_block=1; next }
    in_block && /^\}/ { exit }
    in_block && /username:/ {
      idx = index($0, ":")
      val = substr($0, idx+1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      print val
      exit
    }
  ')
  basic_pass=$(echo "$content" | awk '
    /^auth:basic[[:space:]]*\{/ { in_block=1; next }
    in_block && /^\}/ { exit }
    in_block && /password:/ {
      idx = index($0, ":")
      val = substr($0, idx+1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      print val
      exit
    }
  ')
  if [[ -n "$basic_user" ]]; then
    BX_AUTH_TYPE="basic"
    BX_AUTH_USER="$basic_user"
    BX_AUTH_PASS="$basic_pass"
  fi
}

# Parse collection.bru for collection-level headers and auth
parse_collection_bru() {
  local file="$1"
  [[ -f "$file" ]] || return

  # Parse collection headers
  while IFS= read -r line; do
    [[ -n "$line" ]] && BX_COLLECTION_HEADERS+=("$line")
  done < <(tr -d '\r' < "$file" | awk '
    /^headers[[:space:]]*\{/ { in_block=1; next }
    in_block && /^\}/ { exit }
    in_block {
      gsub(/^[[:space:]]+/, "")
      if ($0 == "" || /^~/ || /^\/\//) next
      print
    }
  ')

  # Parse collection auth:bearer
  local coll_bearer
  coll_bearer=$(tr -d '\r' < "$file" | awk '
    /^auth:bearer[[:space:]]*\{/ { in_block=1; next }
    in_block && /^\}/ { exit }
    in_block && /token:/ {
      idx = index($0, ":")
      val = substr($0, idx+1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      print val
      exit
    }
  ')
  if [[ -n "$coll_bearer" ]]; then
    BX_COLLECTION_AUTH_TYPE="bearer"
    BX_COLLECTION_AUTH_TOKEN="$coll_bearer"
  fi

  # Parse collection auth:basic
  local coll_user coll_pass
  coll_user=$(tr -d '\r' < "$file" | awk '
    /^auth:basic[[:space:]]*\{/ { in_block=1; next }
    in_block && /^\}/ { exit }
    in_block && /username:/ {
      idx = index($0, ":")
      val = substr($0, idx+1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      print val
      exit
    }
  ')
  coll_pass=$(tr -d '\r' < "$file" | awk '
    /^auth:basic[[:space:]]*\{/ { in_block=1; next }
    in_block && /^\}/ { exit }
    in_block && /password:/ {
      idx = index($0, ":")
      val = substr($0, idx+1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      print val
      exit
    }
  ')
  if [[ -n "$coll_user" ]]; then
    BX_COLLECTION_AUTH_TYPE="basic"
    BX_COLLECTION_AUTH_USER="$coll_user"
    BX_COLLECTION_AUTH_PASS="$coll_pass"
  fi
}
