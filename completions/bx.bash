#!/usr/bin/env bash
# Bash completion for bx (Bruno Execute)

_bx_completions() {
  local cur prev commands flags
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  commands="ls envs inspect help version completion"
  flags="--env -e --verbose -v --dry-run -d --raw --xh --curlie --curl --no-color --header -H --var"

  # After -e / --env, complete environment names
  if [[ "$prev" == "-e" || "$prev" == "--env" ]]; then
    local root envs
    root=$(_bx_find_root 2>/dev/null)
    if [[ -n "$root" && -d "$root/environments" ]]; then
      envs=$(find "$root/environments" -name '*.bru' -exec basename {} .bru \;)
      COMPREPLY=($(compgen -W "$envs" -- "$cur"))
    fi
    return
  fi

  # After "completion", suggest shells
  if [[ "$prev" == "completion" ]]; then
    COMPREPLY=($(compgen -W "bash zsh fish" -- "$cur"))
    return
  fi

  # If current word starts with -, complete flags
  if [[ "$cur" == -* ]]; then
    COMPREPLY=($(compgen -W "$flags" -- "$cur"))
    return
  fi

  # Otherwise complete commands + request names
  local root requests
  root=$(_bx_find_root 2>/dev/null)
  if [[ -n "$root" ]]; then
    requests=$(find "$root" -name '*.bru' -not -path '*/environments/*' | sed "s|$root/||;s|\.bru$||")
  fi
  COMPREPLY=($(compgen -W "$commands $requests" -- "$cur"))
}

_bx_find_root() {
  if [[ -n "${BX_COLLECTION:-}" && -f "$BX_COLLECTION/bruno.json" ]]; then
    echo "$BX_COLLECTION"
    return
  fi
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    [[ -f "$dir/bruno.json" ]] && echo "$dir" && return
    dir="$(dirname "$dir")"
  done
}

complete -F _bx_completions bx
