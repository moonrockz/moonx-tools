# moonx-tools
Command-line tools for MoonBit, runnable with moonx.

## Tools

- [`apps/zig-cross`](apps/zig-cross/README.md) — `moonrockz/zig-cross`: cross-compile MoonBit native
  binaries with zig (`linux-x64`, `linux-arm64`, `darwin-arm64`, `darwin-x64`, `windows-x64`, `host`).
  Moved from [moonrockz/smithy](https://github.com/moonrockz/smithy) with no CLI changes.

- [`apps/pubman`](apps/pubman/README.md): `moonrockz/pubman` packages and verifies
  one MoonBit library for Mooncakes and an npm ESM package with JS and Wasm-GC entries.
  Authors supply adapters, wrappers, declarations and consumer checks.

## Local development

Pinned toolchain (MoonBit `0.10.18+6c83a7f62`, Zig `0.17.0`):

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
mise exec -- playwright install --with-deps chromium
mise run test:pubman       # packed Node/Chromium/TypeScript consumers and previews
```

Consumer usage:

```sh
moonx moonrockz/zig-cross@<version> doctor linux-x64 --json
moonx moonrockz/zig-cross@<version> build linux-x64 -- fixtures/consumer
ZIG_CROSS_RUNTIME=sync moonx moonrockz/zig-cross@<version> build darwin-arm64 -- fixtures/consumer
moonx moonrockz/zig-cross@<version> exec host -- moon test fixtures/consumer --target native
moonx moonrockz/zig-cross@<version> --help
```

Run `doctor` before choosing a target or upgrading MoonBit. It emits stable codes and actionable steps for users and agents. Full-runtime Linux and local macOS header fixes are version-bounded. `ZIG_CROSS_RUNTIME=sync` is an explicit experimental subset for cross-target consumers that do not need the new asynchronous runtime APIs. See the [compatibility contract](apps/zig-cross/README.md#moonbit-01017-compatibility).

Windows note: a `windows-x64` binary that zig cross-builds is wrong for MoonBit code
that uses `OsString` (see `apps/zig-cross/README.md`). Build Windows binaries on Windows.
`zig-cross` itself runs on Linux/macOS only.

## Planning changes with OpenSpec

`mise install` installs the pinned OpenSpec CLI. Repository context and artifact
rules live in [`openspec/config.yaml`](openspec/config.yaml). Current specs live
in `openspec/specs/`; proposals, designs, spec changes, and tasks live in
`openspec/changes/<change-name>/` until archived.

The same six workflow skills are installed for every agent we use:

| Agent | Skill directory | Start a proposal |
| --- | --- | --- |
| Codex | `.agents/skills/` | `$openspec-propose "describe the change"` |
| Claude Code | `.claude/skills/` | `/openspec-propose "describe the change"` |
| GitHub Copilot | `.github/skills/` | `/openspec-propose "describe the change"` |
| Muse Code | `.agents/skills/` | `/openspec-propose "describe the change"` |
| Cursor | `.cursor/skills/` | `/openspec-propose "describe the change"` |
| Grok Build | `.grok/skills/` | `/openspec-propose "describe the change"` |

Use `openspec-explore` to investigate an idea and `openspec-propose` to generate
a proposal. Review the artifacts, use `openspec-update-change` to revise them,
then `openspec-apply-change <change-name>` to implement. Use
`openspec-sync-specs` to merge spec changes and `openspec-archive-change` to
finish. Add the invocation prefix from the table to each skill name.

Restart the agent or IDE after setup to load its skills. Muse reads the shared
skills once the workspace is trusted; see its
[skill documentation](https://meta-models.github.io/muse-code-sdk/next/guides/extend/).
To regenerate integrations after upgrading the pinned CLI, run:

```sh
mise run openspec:sync
```

This task fixes the workflow set to `core` and delivery to `skills` in an isolated
config under `_build/`. It preserves your global OpenSpec preferences and produces
the same skills for every contributor. Use this task to refresh this repo's
integrations.

```sh
openspec list                       # active changes
openspec list --specs               # current specifications
openspec validate --all --strict    # validate specs and changes
```

See the [OpenSpec documentation](https://openspec.dev/docs/setup) for the workflow.

## CI

`.github/workflows/ci.yml`:

- `lint` (MoonBit format + `moon check --deny-warn`, YAML lint, `validate`)
- `build` / `test` matrix (`wasm`, `wasm-gc`, `js`, `native`)
- `test-native-zig` (`exec host` native tests)
- `test-scripts`
- `consumer` on Linux and macOS: real cross-build, header validation of the
  cross-built `.exe` (ELF/Mach-O/PE, mirroring `format.mbt`), `exec host` tests,
  execution of a host-compatible binary, and pubman packed-package verification
- `ci-ok` gate

## Release

`moonrockz/zig-cross` and `moonrockz/pubman` publish to [mooncakes.io](https://mooncakes.io).
Both consumer fixtures remain unpublished. zig-cross releases independently
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

`.github/workflows/release.yml`: `plan` → `validate` (includes `test:consumer` and `test:pubman`) →
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
