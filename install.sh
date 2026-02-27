#!/usr/bin/env bash
set -euo pipefail

# bx installer — installs bx from GitHub releases
# Usage: curl -fsSL https://raw.githubusercontent.com/gabed457/bx/main/install.sh | bash

REPO="gabed457/bx"
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

info() { echo -e "${DIM}$*${RESET}"; }
success() { echo -e "${GREEN}$*${RESET}"; }
error() { echo -e "${RED}error:${RESET} $*" >&2; exit 1; }

# Determine install prefix
determine_prefix() {
  if [[ -n "${PREFIX:-}" ]]; then
    echo "$PREFIX"
    return
  fi

  if [[ -d "$HOME/.local/bin" ]] && echo "$PATH" | grep -q "$HOME/.local/bin"; then
    echo "$HOME/.local"
    return
  fi

  if [[ -w "/usr/local/bin" ]]; then
    echo "/usr/local"
    return
  fi

  echo "/usr/local"
}

# Detect download tool
detect_downloader() {
  if command -v curl &>/dev/null; then
    echo "curl"
  elif command -v wget &>/dev/null; then
    echo "wget"
  else
    error "Neither curl nor wget found. Please install one of them."
  fi
}

download() {
  local url="$1" dest="$2"
  case "$(detect_downloader)" in
    curl) curl -fsSL "$url" -o "$dest" ;;
    wget) wget -q "$url" -O "$dest" ;;
  esac
}

main() {
  echo -e "${BOLD}Installing bx — Bruno Execute${RESET}"
  echo ""

  local prefix
  prefix=$(determine_prefix)
  local needs_sudo="false"

  if [[ -d "$prefix/bin" ]]; then
    if [[ ! -w "$prefix/bin" ]]; then
      needs_sudo="true"
      info "Will need sudo to install to $prefix"
    fi
  elif [[ ! -w "$prefix" ]]; then
    needs_sudo="true"
    info "Will need sudo to install to $prefix"
  fi

  # Get latest version
  info "Fetching latest release..."
  local version
  if command -v curl &>/dev/null; then
    version=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name"' | sed 's/.*"tag_name": *"//;s/".*//')
  else
    version=$(wget -qO- "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name"' | sed 's/.*"tag_name": *"//;s/".*//')
  fi

  if [[ -z "$version" ]]; then
    error "Could not determine latest version. Check https://github.com/$REPO/releases"
  fi

  info "Installing bx $version to $prefix"

  # Create temp directory
  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT

  # Download and extract
  local tarball_url="https://github.com/$REPO/archive/refs/tags/${version}.tar.gz"

  info "Downloading $tarball_url..."
  download "$tarball_url" "$tmpdir/bx.tar.gz"
  tar -xzf "$tmpdir/bx.tar.gz" -C "$tmpdir" --strip-components=1

  # Install
  local sudo_cmd=""
  if [[ "$needs_sudo" == "true" ]]; then
    sudo_cmd="sudo"
  fi

  $sudo_cmd mkdir -p "$prefix/bin" "$prefix/lib/bx"
  $sudo_cmd install -m 755 "$tmpdir/bin/bx" "$prefix/bin/bx"
  $sudo_cmd install -m 644 "$tmpdir/lib/"*.sh "$prefix/lib/bx/"

  # Install completions if standard directories exist
  local shell_name
  shell_name=$(basename "${SHELL:-/bin/bash}")

  case "$shell_name" in
    bash)
      local bash_comp_dir="${BASH_COMPLETION_DIR:-$HOME/.local/share/bash-completion/completions}"
      if [[ -d "$(dirname "$bash_comp_dir")" ]]; then
        mkdir -p "$bash_comp_dir"
        install -m 644 "$tmpdir/completions/bx.bash" "$bash_comp_dir/bx"
        info "Installed bash completions to $bash_comp_dir/bx"
      fi
      ;;
    zsh)
      local zsh_comp_dir="${HOME}/.zsh/completions"
      mkdir -p "$zsh_comp_dir"
      install -m 644 "$tmpdir/completions/bx.zsh" "$zsh_comp_dir/_bx"
      info "Installed zsh completions to $zsh_comp_dir/_bx"
      info "Add 'fpath=(~/.zsh/completions \$fpath)' to your .zshrc if not already there"
      ;;
    fish)
      local fish_comp_dir="${HOME}/.config/fish/completions"
      mkdir -p "$fish_comp_dir"
      install -m 644 "$tmpdir/completions/bx.fish" "$fish_comp_dir/bx.fish"
      info "Installed fish completions to $fish_comp_dir/bx.fish"
      ;;
  esac

  echo ""
  # Verify
  if "$prefix/bin/bx" version >/dev/null 2>&1; then
    success "bx $("$prefix/bin/bx" version) installed successfully!"
  else
    success "bx installed to $prefix/bin/bx"
  fi

  echo ""
  info "For the best experience, install xh: https://github.com/ducaale/xh"
  info "  brew install xh  OR  cargo install xh"
  echo ""
  info "To uninstall: rm -f $prefix/bin/bx && rm -rf $prefix/lib/bx"
}

main "$@"
