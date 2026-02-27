# bx -- Bruno Execute

**Your team uses Bruno. You use the terminal. Same collection, zero friction.**

[![CI](https://github.com/gabed457/bx/actions/workflows/ci.yml/badge.svg)](https://github.com/gabed457/bx/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## What is bx?

`bx` reads `.bru` files from [Bruno](https://www.usebruno.com/) API collections and executes HTTP requests using `xh`, `curlie`, or `curl`. Your team keeps designing collections in Bruno. You stay in the terminal.

**bx is read-only.** It never writes to, modifies, or creates `.bru` files.

## Quick Start

```bash
# Homebrew
brew install gabed457/tap/bx

# curl installer
curl -fsSL https://raw.githubusercontent.com/gabed457/bx/main/install.sh | bash

# npm
npm install -g brunox
```

Then run requests from inside any Bruno collection directory:

```bash
cd your-bruno-collection/
bx ls                            # List all requests
bx get-user -e dev               # Execute a request with the dev environment
bx create-order -e staging -v    # Verbose mode shows request details
```

## Features

- Execute any `.bru` request file directly from the terminal
- Auto-detect and use `curlie`, `xh`, or `curl` as the HTTP client
- Environment variable resolution from Bruno environment files
- Collection-level headers and auth from `collection.bru`
- Fuzzy request name matching -- type less, do more
- `--dry-run` mode outputs a copy-pasteable shell command
- `--raw` mode for piping responses to `jq` and other tools
- Bearer and Basic auth support
- JSON, form-urlencoded, multipart-form, XML, text, and GraphQL body types
- Bash, Zsh, and Fish shell completions
- Respects `NO_COLOR` for accessible output

## Usage

```
bx <request> [options]
bx <command>
```

### Commands

| Command | Description |
|---------|-------------|
| `bx ls` | List all requests (color-coded by HTTP method) |
| `bx envs` | List available environments |
| `bx inspect <request> -e <env>` | Show fully resolved request without executing |
| `bx help` | Show help text |
| `bx version` | Print version |
| `bx completion bash\|zsh\|fish` | Output shell completion script |

### Options

| Flag | Short | Description |
|------|-------|-------------|
| `--env <name>` | `-e` | Use a specific environment |
| `--verbose` | `-v` | Show parsed request before executing |
| `--dry-run` | `-d` | Print command without executing |
| `--raw` | | Raw response body only (ideal for piping) |
| `--xh` | | Force xh as HTTP client |
| `--curlie` | | Force curlie as HTTP client |
| `--curl` | | Force curl as HTTP client |
| `--no-color` | | Disable colored output |
| `--header "K: V"` | `-H` | Add/override a header |
| `--var "key=val"` | | Override an environment variable |

### Examples

```bash
# List all requests in your collection
bx ls

# Execute a GET request with dev environment
bx get-user -e dev

# POST with verbose output
bx create-user -e staging -v

# Dry-run to see what command would be executed
bx get-user -e dev --dry-run

# Pipe raw JSON to jq
bx get-user -e dev --raw | jq '.data.email'

# Override a variable for this request
bx get-user -e dev --var "userId=42"

# Add a custom header
bx get-user -e dev -H "X-Debug: true"

# Use a specific HTTP client
bx get-user -e dev --curl
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `BX_COLLECTION` | Path to Bruno collection root | Auto-discovered from current directory |
| `BX_ENV` | Default environment name | None |
| `BX_HTTP_CLIENT` | Preferred HTTP client | Auto-detected (`curlie` > `xh` > `curl`) |
| `NO_COLOR` | Disable colored output (any value) | Unset |
| `BX_DEBUG` | Enable debug output (set to `1`) | Unset |

## FAQ

**Does this replace Bruno?**
No. `bx` is read-only. Your team keeps using Bruno to design and manage collections. `bx` just executes requests from the terminal.

**What about pre-request scripts?**
Not supported. `bx` handles HTTP request execution, not JavaScript. Use Bruno's own CLI for scripted test runs.

**Can I use this in CI/CD?**
Yes. `bx get-user -e ci --raw | jq .status` works great in pipelines and shell scripts.

**Does this work with Bruno Pro/Enterprise?**
It should work with any standard `.bru` files regardless of Bruno edition.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, code style, and PR process.

## License

[MIT](LICENSE)
