#!/usr/bin/env bash
# lib/output.sh — Colors, formatting, verbose/dry-run display

RED=''
GREEN=''
YELLOW=''
BLUE=''
CYAN=''
DIM=''
BOLD=''
RESET=''

init_colors() {
  # Respect NO_COLOR (https://no-color.org/)
  if [[ -n "${NO_COLOR:-}" ]]; then
    return
  fi

  # Disable colors if stderr is not a TTY
  if [[ ! -t 2 ]]; then
    return
  fi

  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  DIM='\033[2m'
  BOLD='\033[1m'
  RESET='\033[0m'
}

print_request() {
  local method="$1" url="$2"
  shift 2
  local -a headers=()
  local bearer="" body=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --header) headers+=("$2"); shift ;;
      --bearer) bearer="$2"; shift ;;
      --body) body="$2"; shift ;;
    esac
    shift
  done

  echo "" >&2
  echo -e "${BOLD}${method}${RESET} ${url}" >&2
  for h in "${headers[@]}"; do
    echo -e "  ${DIM}${h}${RESET}" >&2
  done
  if [[ -n "$bearer" ]]; then
    echo -e "  ${DIM}Authorization: Bearer ${bearer:0:20}...${RESET}" >&2
  fi
  if [[ -n "$body" ]]; then
    echo -e "\n${DIM}Body:${RESET}" >&2
    echo "$body" >&2
  fi
  echo "" >&2
}

print_command() {
  local -a cmd=("$@")
  echo -e "${CYAN}Command:${RESET}" >&2
  printf '%q ' "${cmd[@]}"
  echo ""
}
