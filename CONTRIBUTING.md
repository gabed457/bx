# Contributing to bx

Thank you for your interest in contributing to bx!

## Development Setup

```bash
git clone https://github.com/gabed457/bx.git
cd bx
make test    # Run the test suite
make lint    # Run shellcheck
```

The main executable is `bin/bx`, which sources modules from `lib/*.sh`:

| Module | Responsibility |
|--------|----------------|
| `lib/utils.sh` | Shared helpers, error handling, debug output |
| `lib/output.sh` | Color handling and formatted printing |
| `lib/discovery.sh` | Collection root detection, request file finding, fuzzy matching |
| `lib/env.sh` | Environment loading and variable resolution |
| `lib/parser.sh` | `.bru` file parsing (headers, body, auth, query params) |
| `lib/client.sh` | HTTP client detection and request execution |

## Code Style

- All shell scripts must pass [ShellCheck](https://www.shellcheck.net/) with zero warnings
- Use `set -euo pipefail` (or `set -uo pipefail` for test files)
- 2-space indentation, no tabs
- `snake_case` for function names and variables
- All user-facing errors go to stderr
- All parseable output goes to stdout

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` New features
- `fix:` Bug fixes
- `docs:` Documentation changes
- `chore:` Maintenance tasks
- `test:` Test additions or fixes
- `refactor:` Code restructuring

Examples:

```
feat: add support for body:multipart-form
fix: resolve nested brace parsing in body:json
docs: update FEATURE_PARITY table
test: add integration tests for auth:basic
```

## Pull Request Process

1. Fork the repository
2. Create a feature branch (`feat/my-feature` or `fix/my-bug`)
3. Write tests for your changes
4. Ensure `make test` and `make lint` pass
5. Submit a PR against `main`

Please keep PRs focused on a single concern. If you are fixing a bug and adding a feature, submit them as separate PRs.

## Adding Support for New .bru Blocks

1. Add the parsing logic in `lib/parser.sh`
2. Add test fixtures in `test/fixtures/`
3. Add test cases in `test/test_parser.sh`
4. Update `docs/FEATURE_PARITY.md`
5. Update the CHANGELOG

## Reporting Issues

Use the GitHub issue tracker. When reporting a bug, include:

- The `bx version` output
- The `.bru` file content (or a minimal reproduction)
- Expected vs. actual behavior
- Your OS and shell version
