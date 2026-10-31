## Why

MoonBit 0.10.17 and 0.10.18 compile every runtime C file. With zig-cross, `dir.c` fails on Linux targets (`NAME_MAX` is not declared, because the file does not include `limits.h`), and `dir.c` and `fs.c` fail on darwin targets (`sys/vnode.h` is not in Zig's macOS headers). The moonbitlang/async C stubs have the same two defects. zig-cross 0.3.1 adds a fix only for the exact 0.10.17 fingerprint, and for darwin only on a macOS host with an SDK. Thus MoonBit 0.10.18 consumers cannot cross-build on any host, and no consumer can cross-build darwin targets on Linux. moonrockz/mission-control PR #24 fails on this.

## What Changes

- The `cc` wrapper adds the header fix only when an argument is a MoonBit runtime source (`*/lib/runtime/*.c`) or a moonbitlang/async source (`*/moonbitlang/async/*.c`). Other C code compiles as before.
- Linux targets get `-include limits.h`. Darwin targets get `-idirafter <wrapper-dir>/include`, where zig-cross writes a minimal `sys/vnode.h` shim with `enum vtype` and the macOS SDK values. The macOS SDK is no longer used, so Linux hosts can build darwin targets.
- The fix applies to the full runtime of every toolchain on a Linux or macOS host, except the old 0.10.15 pin. Sync mode gets no fix, as before.
- MoonBit 0.10.18+6c83a7f62 with Moon 0.1.20261028 gets a full-runtime assessment. Doctor reports `ZC_LINUX_NAME_MAX` and `ZC_DARWIN_VNODE_HEADER` as active warnings for it. Sync mode stays assessed for 0.10.17 only.
- For an unassessed toolchain, `ZC_TOOLCHAIN_UNVERIFIED` states which targets get the header fix.
- `test:consumer` cross-builds `apps/zig-cross` with the full runtime for the four Linux and darwin targets. A new CI job does the same with MoonBit 0.10.18 on a Linux host.

Out of scope: the pinned toolchain (stays 0.10.17), Windows full-runtime support, sync mode for 0.10.18, pubman, and changes in other repositories.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `zig-cross-compatibility-guidance`: the known-limits scenario covers 0.10.18 and the shim; new scenarios cover the scope of the header fix and its notice for unassessed toolchains.

## Impact

- `apps/zig-cross/headers.mbt` (new: shim, source patterns, wrapper line), `doctor.mbt`, `target.mbt`, `main.mbt` and their tests.
- `apps/zig-cross/README.md`, `AGENTS.md`, `scripts/test-consumer.mbtx`, `.github/workflows/ci.yml`.
- JSON consumers: schema version 1 does not change. Darwin findings change from `error` to `warning` on hosts without an SDK. `environment.darwin_sdk` stays for information.
