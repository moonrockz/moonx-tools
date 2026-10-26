# Changelog

All notable changes to `moonrockz/zig-cross` and `moonrockz/pubman` are listed here, newest first.
Versions follow [Semantic Versioning](https://semver.org); while the version
is 0.x, a minor release can contain breaking changes.

<!-- git-cliff: end of header -->

## [0.3.1] - 2026-10-26

<!-- Highlights: replace this comment with a few sentences on what this release brings. -->

### 🐛 Bug fixes

- *(zig-cross)* Use assessed targets in unverified next step ([#10](https://github.com/moonrockz/moonx-tools/pull/10)) by @DamianReeves

**Full changelog**: https://github.com/moonrockz/moonx-tools/compare/v0.3.0...v0.3.1

## [0.3.0] - 2026-10-26

Upgrade to stable MoonBit `0.10.17+d971670cd` with actionable zig-cross guidance for users and agents. Run `moonx moonrockz/zig-cross@0.3.0 doctor linux-x64 --json` for a schema-version-1 report with detected tools, stable finding codes, applicability and recovery steps. Build/exec notices use stderr, and failed targets retain raw diagnostics plus a doctor hint.

Full runtime remains the default, with version/fingerprint-bound Linux header injection and detected local macOS SDK headers. Explicit `ZIG_CROSS_RUNTIME=sync` selects an experimental six-file synchronous runtime in a temporary toolchain view without editing the installed toolchain. It excludes the runtime's event loop, async filesystem, networking, processes, TLS, thread pools and watchers; consumers needing excluded symbols fail at link time and should use a native compiler on the target OS. Unknown/custom toolchains cannot inherit this whitelist.

Linux/macOS CI qualifies the upgrade, all five cross-target headers, doctor/stream contracts, host runtime APIs and dependencies, and pubman's installed Node/Chromium/TypeScript consumers and previews. Both tools share version 0.3.0. Windows output is link/header checked only: programs using OsString for arguments, environment variables or paths must still be built on Windows. See the [compatibility guide](https://github.com/moonrockz/moonx-tools/blob/v0.3.0/apps/zig-cross/README.md#moonbit-01017-compatibility) for mode selection and limits.

### 🚀 Features

- Upgrade MoonBit and add zig-cross doctor ([#6](https://github.com/moonrockz/moonx-tools/pull/6)) by @DamianReeves

### Fixes

- Emit each compatibility notice once for repeated build targets while preserving the requested build sequence.

**Full changelog**: https://github.com/moonrockz/moonx-tools/compare/v0.2.0...v0.3.0

## [0.2.0] - 2026-10-25

First release of `moonrockz/pubman`, a CLI for packaging one MoonBit library as
a Mooncakes source release and a typed npm ESM package. The npm package exposes
JavaScript at its root and Wasm-GC at `/wasm`, with explicit author wrappers
and declarations for both entries.

Pubman provides `plan`, `pack`, `verify`, and `publish`, versioned JSON reports,
local-read-only dry runs, installed Node/Chromium/TypeScript verification,
and recovery from partial registry publication using the same verified bundle.
The repository releases pubman and zig-cross together at version 0.2.0.

### 🚀 Features

- *(pubman)* Add dual-registry release tool ([#4](https://github.com/moonrockz/moonx-tools/pull/4)) by @DamianReeves

### ⚙️ Maintenance

- Set up OpenSpec for coding agents ([#3](https://github.com/moonrockz/moonx-tools/pull/3)) by @DamianReeves

**Full changelog**: https://github.com/moonrockz/moonx-tools/compare/v0.1.2...v0.2.0

## [0.1.2] - 2026-10-17

First independent release of `moonrockz/zig-cross` from
[moonrockz/moonx-tools](https://github.com/moonrockz/moonx-tools), moved from
[moonrockz/smithy](https://github.com/moonrockz/smithy) `apps/zig-cross` with no CLI changes.

Package name, CLI commands (`build`, `exec`, `--help`, `--version`), target names
(`linux-x64`, `linux-arm64`, `darwin-arm64`, `darwin-x64`, `windows-x64`, `host`),
output paths (`_build/cross/<target>`), and wrapper behavior (`_CRT_RAND_S`,
host-only simdutf/libbacktrace stripping, Linux host `-lunwind`) are unchanged.
Module repository metadata now points to `moonrockz/moonx-tools`.

**Install:**

- `moonx moonrockz/zig-cross@0.1.2 --help`
