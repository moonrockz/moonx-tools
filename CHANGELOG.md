# Changelog

All notable changes to `moonrockz/zig-cross` and `moonrockz/pubman` are listed here, newest first.
Versions follow [Semantic Versioning](https://semver.org); while the version
is 0.x, a minor release can contain breaking changes.

<!-- git-cliff: end of header -->

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
