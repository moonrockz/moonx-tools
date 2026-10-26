# Proposal

## Why

zig-cross currently reports a generic build exit code, while important compatibility limits live only in its README. Users and agents need actionable guidance from the executable as MoonBit upgrades introduce runtime portability problems and temporary workarounds.

## What Changes

- Add `zig-cross doctor [<target>...] [--json]` to report detected tools, compatibility findings, available workarounds, their limits, and concrete next steps without building a project.
- Make `--help` advertise diagnostics and summarize the Windows platform/core limitation.
- Show relevant guidance before `build` and `exec`, including any active compatibility mode, and point failed builds to target-specific diagnostics while preserving compiler output and exit behavior.
- Give findings stable identifiers and structured JSON so agents do not need to interpret prose or terminal decoration.
- Share guidance between diagnostics, command notices, and documentation; distinguish verified behavior from experimental workarounds and unknown toolchain versions.
- Upgrade every platform pin and archive URL to the independently verified latest stable MoonBit toolchain. Migrate standalone scripts to fenced frontmatter imports.
- Implement explicit `ZIG_CROSS_RUNTIME=sync` selection for the fingerprinted 0.10.17 runtime through an isolated `MOON_TOOLCHAIN_ROOT` view. Keep full runtime as default. Excluded runtime APIs must fail at link time with original diagnostics and recovery guidance. Never edit the installed runtime or mix compiler/runtime versions.
- Qualify guidance, sync-mode consumers, full-runtime host builds, pubman installed consumers and release builds; land one implementation PR, then use the normal release PR and production workflow. Windows runtime correctness remains outside our claims.

## Capabilities

### New Capabilities

- `zig-cross-compatibility-guidance`: discoverable compatibility diagnostics and actionable command guidance for people and agents.

### Modified Capabilities

None. The current main-spec inventory is empty.

## Impact

- `apps/zig-cross/cli.mbt`, `main.mbt`, and new diagnostic/reporting modules and focused tests.
- `apps/zig-cross/README.md` and root usage documentation.
- Existing consumer verification and a focused CLI diagnostic integration check, implemented as MoonBit task automation if a standalone runner is needed.
- Preserve pubman behavior, target names, existing build/exec syntax, binary output paths, and publication policy; fix compiler fallout across the repository as needed.
