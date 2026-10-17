# Changelog

All notable changes to `moonrockz/zig-cross` are listed here, newest first.
Versions follow [Semantic Versioning](https://semver.org); while the version
is 0.x, a minor release can contain breaking changes.

<!-- git-cliff: end of header -->

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
