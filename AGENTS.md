# Agent Instructions

MoonBit monorepo for command-line tools runnable with `moonx`. Currently holds
`apps/zig-cross` (`moonrockz/zig-cross`). See [README.md](README.md) for usage.

## Toolchain

- `mise` installs and pins every tool (`.config/mise/config.toml`). Run `mise trust` and then `mise install` once.
- MoonBit `0.10.15+943464bfa`, Zig `0.17.0`. Change the MoonBit version in the version field and in each URL together.
- `moon.work` lists workspace members (`apps/*`, `fixtures/*`). `moon build`, `moon test`, `moon check`, `moon fmt` at the root act on all of them.

## Task scripts

Write task automation as standalone MoonBit `.mbtx` scripts, not bash/PowerShell. See Smithy's `AGENTS.md` pattern.

- Put the script in `scripts/` and run it with `moonx scripts/<name>.mbtx`.
- Declare its mise task in `.config/mise/config.toml`: `run = "moonx scripts/<name>.mbtx"`.
- Pin each import: `"moonbitlang/async@0.22.5/process"`. Use `moonbitlang/async` for processes/files/stdio, `moonbitlang/core/env` for args/env, `moonbitlang/x/sys` for exit.
- `@env.args()` has the binary at index 0; task args start at 1.
- A `.mbtx` file cannot start with a shebang; keep the toml task declaration.
- Exit non-zero on failure.

## Checks

`mise run lint` and `mise run validate` must pass before push. `mise run check` runs lint, validate, test, build (what CI runs). `mise run format` before committing MoonBit code. Commits use Conventional Commits, no AI attribution.

- `mise run test:native-zig` runs native tests with zig (`exec host`).
- `mise run test:consumer` cross-builds `fixtures/consumer` and runs `exec host`.
- `mise run test:scripts` runs script tests (`scripts/features/*.feature` via moonspec).

## Release

`moonrockz/zig-cross` publishes to mooncakes.io + GitHub Releases, recorded in `CHANGELOG.md` (git-cliff, `cliff.toml`).

- All modules share one version; root `moon.mod` is source of truth. `mise run validate:versions` fails on mismatch; `moonx scripts/versions.mbtx set X.Y.Z` rewrites.
- `mise run release:prepare [X.Y.Z]` computes next version, sets it, prepends CHANGELOG, opens draft PR on `release/vX.Y.Z`. Replace highlights placeholder, then `mise run release:refresh` and merge.
- Release workflow (`.github/workflows/release.yml`): `plan` → `validate` (check + test:scripts + test:consumer + versions check) → `publish` (mooncakes.io, idempotent) → `verify` (moonx with retries) → `release` (notes-only GitHub release). Dry runs (PRs, `dry_run`) stop after validate. Runs are serialized (`concurrency: release`).
- Needs org secret `MOONCAKES_USER_TOKEN` (`release:credentials` → `$MOON_HOME/credentials.json`).
