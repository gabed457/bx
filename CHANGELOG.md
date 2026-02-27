# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-02-27

### Added
- Initial release
- Parse and execute .bru request files (GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD)
- Environment variable resolution
- HTTP client auto-detection (curlie → xh → curl)
- bx ls, bx envs, bx inspect commands
- --dry-run, --verbose, --raw modes
- Fuzzy request name matching
- Bearer and Basic auth support
- JSON, form, XML, text, and GraphQL body types
- Collection-level headers and auth from collection.bru
- --header and --var CLI overrides
- Bash, Zsh, and Fish shell completions
