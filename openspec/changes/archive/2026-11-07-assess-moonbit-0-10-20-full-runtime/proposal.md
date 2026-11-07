## Why

The repository pin moves to MoonBit 0.10.20+65efd5b93 with Moon 0.1.20261104. zig-cross has no assessment for this toolchain, so doctor reports `ZC_TOOLCHAIN_UNVERIFIED` for the pin and `test:doctor` fails. The 0.10.20 runtime has the same header defects as 0.10.18: `dir.c` uses `NAME_MAX` and does not include `limits.h`, and `dir.c` and `fs.c` include `sys/vnode.h`. With the existing header fix, the full runtime and moonbitlang/async 0.22.7 cross-build for linux-x64, linux-arm64, darwin-arm64 and darwin-x64.

## What Changes

- MoonBit 0.10.20+65efd5b93 with Moon 0.1.20261104 and runtime SHA-256 `9460b04586700bdff229393bca37473f18db42fb0cfc4711394e7ea410899ab0` gets a full-runtime assessment. Doctor reports `ZC_LINUX_NAME_MAX` and `ZC_DARWIN_VNODE_HEADER` as active warnings for it.
- Sync mode stays assessed for 0.10.17 only. The 0.10.17 and 0.10.18 assessments do not change.

Out of scope: the header fix itself, sync mode for 0.10.20, Windows full-runtime support, and changes in other repositories.

## Capabilities

### Modified Capabilities

- `zig-cross-compatibility-guidance`: the known-limits scenario covers 0.10.20.

## Impact

`apps/zig-cross/doctor.mbt`, its white-box tests and `apps/zig-cross/README.md`. Consumers on MoonBit 0.10.20 get the assessment only after a zig-cross release.
