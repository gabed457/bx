#compdef bx
# Zsh completion for bx (Bruno Execute)

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

_bx_requests() {
  local root
  root=$(_bx_find_root 2>/dev/null)
  [[ -z "$root" ]] && return
  local -a requests
  requests=(${(f)"$(find "$root" -name '*.bru' -not -path '*/environments/*' | sed "s|$root/||;s|\.bru$||")"})
  _describe 'request' requests
}

_bx_envs() {
  local root
  root=$(_bx_find_root 2>/dev/null)
  [[ -z "$root" || ! -d "$root/environments" ]] && return
  local -a envs
  envs=(${(f)"$(find "$root/environments" -name '*.bru' -exec basename {} .bru \;)"})
  _describe 'environment' envs
}

_bx() {
  local -a commands
  commands=(
    'ls:List all requests in the collection'
    'envs:List available environments'
    'inspect:Show the fully resolved request without executing'
    'help:Show help message'
    'version:Print version'
    'completion:Output shell completion script'
  )

  _arguments -s \
    '1: :->cmd_or_request' \
    '(-e --env)'{-e,--env}'[Use a specific environment]:environment:_bx_envs' \
    '(-v --verbose)'{-v,--verbose}'[Show parsed request details]' \
    '(-d --dry-run)'{-d,--dry-run}'[Print command without executing]' \
    '--raw[Output raw response body only]' \
    '--xh[Force xh as HTTP client]' \
    '--curlie[Force curlie as HTTP client]' \
    '--curl[Force curl as HTTP client]' \
    '--no-color[Disable colored output]' \
    '(-H --header)'{-H,--header}'[Add or override a header]:header:' \
    '*--var[Override an environment variable]:var:' \
    && return

  case "$state" in
    cmd_or_request)
      _describe 'command' commands
      _bx_requests
      ;;
  esac
}

_bx "$@"
