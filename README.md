# moonx-tools
Command-line tools for MoonBit, runnable with moonx.

## Tools

- [`apps/zig-cross`](apps/zig-cross/README.md) — `moonrockz/zig-cross`: cross-compile MoonBit native
  binaries with zig (`linux-x64`, `linux-arm64`, `darwin-arm64`, `darwin-x64`, `windows-x64`, `host`).
  Moved from [moonrockz/smithy](https://github.com/moonrockz/smithy) with no CLI changes.

## Local development

Pinned toolchain (MoonBit `0.10.15+943464bfa`, Zig `0.17.0`):

```sh
mise trust
mise install
mise run lint
mise run validate
mise run check
mise run test
mise run build
```

Tool-specific checks:

```sh
mise run test:native-zig   # native tests with zig as the C compiler (host wrapper)
mise run test:consumer     # real cross-build + exec host against fixtures/consumer
mise run test:scripts      # task script tests
```

Consumer usage:

```sh
moonx moonrockz/zig-cross@<version> build linux-x64 darwin-arm64 -- fixtures/consumer
moonx moonrockz/zig-cross@<version> exec host -- moon test fixtures/consumer --target native
moonx moonrockz/zig-cross@<version> --help
```

Windows note: a `windows-x64` binary that zig cross-builds is wrong for MoonBit code
that uses `OsString` (see `apps/zig-cross/README.md`). Build Windows binaries on Windows.
`zig-cross` itself runs on Linux/macOS only.

## CI

`.github/workflows/ci.yml`:

- `lint` (MoonBit format + `moon check --deny-warn`, YAML lint, `validate`)
- `build` / `test` matrix (`wasm`, `wasm-gc`, `js`, `native`)
- `test-native-zig` (`exec host` native tests)
- `test-scripts`
- `consumer` on Linux and macOS: real cross-build, header validation of the
  cross-built `.exe` (ELF/Mach-O/PE, mirroring `format.mbt`), `exec host` tests,
  and execution of a host-compatible binary
- `ci-ok` gate

## Release

`moonrockz/zig-cross` publishes to [mooncakes.io](https://mooncakes.io) independently
of Smithy. First independent version is `0.1.2`, above published `0.1.1`.

```sh
mise run release:prepare [X.Y.Z] [--local]  # set version + CHANGELOG + release PR
mise run release:refresh                    # update PR body after highlights
mise run release:plan                       # what the Release workflow does
mise run release:status                     # main/tags/GitHub/mooncakes agreement
mise run release:publish                    # CI only: moon publish with retries
mise run release:verify-cli -- X.Y.Z       # CI only: moonx verification with retries
mise run release:notes X.Y.Z                # GitHub release notes
mise run release:github X.Y.Z               # CI only: create GitHub release
mise run release:credentials                # CI only: MOONCAKES_USER_TOKEN -> $MOON_HOME
```

`.github/workflows/release.yml`: `plan` → `validate` (includes `test:consumer`) →
`publish` → `verify` (moonx `--version`/`--help`, consumer cross-build, `exec host`,
bounded retries for prebuilt-Wasm readiness) → `release` (notes-only GitHub release).

- Dry run (`workflow_dispatch` with `dry_run`, or any PR touching release files):
  runs `plan` + `validate` only; never publishes or creates a production release.
- Production releases are serialized (`concurrency: release`).
- Retries after partial publication do not replace an immutable registry version:
  `moon publish` classifies `is duplicated with an existing version` as done and
  retries only transient network failures (5s, 20s, 60s), never 401/403/409.
- Credentials: org secret `MOONCAKES_USER_TOKEN` → `$MOON_HOME/credentials.json`
  (or `~/.moon/credentials.json`).

Handover: publish and verify `moonrockz/zig-cross@<version>` from this repository
before Smithy removes its local source (see
[smithy#19](https://github.com/moonrockz/smithy/issues/19)). Only one repository
publishes this module during the transition.
