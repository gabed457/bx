#!/usr/bin/env bash
# lib/utils.sh — Shared helpers for bx

die() { echo -e "${RED:-}error:${RESET:-} $*" >&2; exit 1; }
warn() { echo -e "${YELLOW:-}warn:${RESET:-} $*" >&2; }
info() { echo -e "${DIM:-}$*${RESET:-}" >&2; }
debug() { if [[ "${BX_DEBUG:-}" == "1" ]]; then echo -e "${DIM:-}[debug] $*${RESET:-}" >&2; fi; }
