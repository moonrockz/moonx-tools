# Proposal

## Why

zig-cross can build Windows binaries only for x86-64 (`windows-x64`). Windows on Arm machines are common now, and Zig 0.17.0 can already target `aarch64-windows-gnu`. A user who wants an arm64 Windows binary has no target name for it and must call zig by hand without the wrappers' fixes.

The repository's own tasks also fail on a Windows arm64 machine before they start. mise has no MoonBit download for `windows-arm64`. The step that adds the core library and `moonx` exists only as a bash step in CI. A checkout with git's `core.autocrlf=true`, the default for Git for Windows and Scoop, breaks `lint:yaml` and `test:scripts`. A contributor on such a machine cannot run `mise run check` at all.

## What Changes

### windows-arm64 target

- Add the cross target `windows-arm64` to zig-cross, with Zig triple `aarch64-windows-gnu`.
- The build checks that each `windows-arm64` executable is PE with machine `0xAA64` (43620). A binary with another header fails as other targets do.
- `--help`, the unknown-target error and the README list `windows-arm64` after `windows-x64`.
- `doctor` with no targets now evaluates seven targets instead of six. This adds one target to the default report. Existing targets, finding codes and exit codes do not change.
- The Windows findings cover `windows-arm64` as they cover `windows-x64`:
  - `ZC_WINDOWS_OSSTRING` lists every requested Windows target.
  - `ZC_WINDOWS_MSVC_RUNTIME` is reported for `windows-arm64` in full runtime mode. It is an error, as it is for `windows-x64`.
- `windows-arm64` gets the same `cc` and `ar` wrappers as the other cross targets (`-D_CRT_RAND_S`, simdutf and libbacktrace filtering). It gets no header fix.
- The consumer test builds `windows-arm64` with `ZIG_CROSS_RUNTIME=sync` and checks its PE header, next to the five existing targets.

### Windows development hosts

- mise installs the pinned MoonBit on `windows-arm64` from MoonBit's x64 Windows archive. MoonBit publishes no arm64 Windows build, and its official installer makes the same choice. The x64 toolchain runs under Windows' x64 emulation.
- `mise install` alone leaves a complete MoonBit toolchain (core library and `moonx`) on every supported host. A post-install hook does this. CI's separate "Complete the MoonBit toolchain" bash step goes away.
- The mise-managed `moon` uses the core library of the mise install, even when another MoonBit install exists in `~/.moon`.
- `.gitattributes` makes git check out text files with LF endings, whatever `core.autocrlf` says.
- On a Windows host:
  - `lint`, `validate`, `test:scripts`, `build`, `test` and `check` run and pass.
  - `test` skips the suites that need a Linux or macOS host (pubman on every target, zig-cross on native) and names each skipped suite in its output.
  - `test:doctor`, `test:pubman` and `test:consumer` stop before doing any work. They print that they need a Linux or macOS host and exit 1.
  - `test:native-zig` and `build:cross` keep stopping at zig-cross's own Windows check.
- CI adds a job on GitHub's `windows-11-arm` runner that runs `lint`, `validate`, `test:scripts`, `test` and `build`. `ci-ok` requires it.

Out of scope:

- Running zig-cross on Windows (x64 or arm64). The tool still stops when `OS=Windows_NT`, and its wrappers stay `/bin/sh` scripts.
- Porting the pubman tests, the zig-cross native wrapper tests, `test:doctor`, `test:consumer` or `test:pubman` to Windows. Each is a later change.
- Native arm64 output from `moon build --target native` on Windows. The x64 toolchain builds x64 binaries, which run under emulation.
- A `linux-arm64` MoonBit pin. MoonBit publishes that archive, but this change does not need it.
- Making the full runtime build for Windows. `windows-arm64` builds only in sync mode, like `windows-x64`.
- Fixing `OsString` handling in cross-built Windows binaries. The upstream limit stays and the warning stays.
- Running the arm64 zig-cross output in CI. Validation checks linking and the header only.
- Release behavior. zig-cross still publishes as source to mooncakes.io and needs no per-platform artifacts.

## Capabilities

### New Capabilities

- `zig-cross-targets`: the set of zig-cross target names, their Zig triples, the executable format each must have, and how an unknown target name is rejected.
- `development-host-support`: which hosts can install the pinned toolchain and run the repository's tasks, what a fresh setup leaves installed, and how tasks that need a Linux or macOS host behave on Windows.

### Modified Capabilities

- `zig-cross-compatibility-guidance`: the Windows `OsString` and MSVC runtime findings apply to every Windows target, and the sync runtime requirement covers all six cross target formats instead of five.

## Impact

- `apps/zig-cross/target.mbt`: new enum case, name, parse and triple.
- `apps/zig-cross/format.mbt`: expected PE machine `0xAA64`.
- `apps/zig-cross/doctor.mbt`: `ZC_WINDOWS_OSSTRING` covers all Windows targets.
- `apps/zig-cross/cli.mbt`: help text target list.
- White-box tests: `target_wbtest.mbt`, `format_wbtest.mbt`, `doctor_wbtest.mbt`, `cli_wbtest.mbt`.
- `.config/mise/config.toml`: `windows-arm64` platform, post-install hook, `MOON_HOME` if needed.
- New bootstrap scripts `scripts/bootstrap/complete-moonbit.sh` and `scripts/bootstrap/complete-moonbit.ps1`.
- New `.gitattributes`.
- `scripts/test.mbtx` (Windows skip list), `scripts/test-doctor.mbtx`, `scripts/test-pubman.mbtx` and `scripts/test-consumer.mbtx` (host guard), and `scripts/test-consumer.mbtx` (`windows-arm64` sync build).
- `.github/actions/setup/action.yml` (bash completion step removed, Windows support), `.github/workflows/ci.yml` (Windows job, PE check).
- `README.md`, `apps/zig-cross/README.md`, `AGENTS.md`, and the `context` in `openspec/config.yaml`.
- No new MoonBit dependencies and no change to the release workflow.
