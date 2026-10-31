## Context

`prepare` in `apps/zig-cross/main.mbt` writes the `cc` and `ar` wrappers for each target. In 0.3.1 `header_flags` gives `-include limits.h` (Linux) or `-idirafter <SDK>/usr/include` (macOS host with an SDK), only when `sync_eligible` is true, that is, for the exact 0.10.17 toolchain. The wrapper puts the flags on every C compile.

The defects are in these upstream files (still present at moonbit-native-runtime commit 88e2a69 and async v0.22.5):

- runtime `dir.c` line 72 uses `NAME_MAX` and does not include `limits.h`; line 27 includes `sys/vnode.h`.
- runtime `fs.c` line 61 includes `sys/vnode.h`.
- async `src/fs/dir.c` and `src/internal/event_loop/fs.c` are copies with the same includes.

These files use only `enum vtype` (`VNON`, `VREG`, `VDIR`, `VBLK`, `VCHR`, `VLNK`, `VSOCK`, `VFIFO`) from `sys/vnode.h`. `fsobj_type_t` and the `ATTR_*` values come from `sys/attr.h`, which Zig has.

## Goals / Non-Goals

**Goals:**
- The MoonBit 0.10.17 and 0.10.18 full runtime and moonbitlang/async compile unchanged for linux-x64, linux-arm64, darwin-arm64 and darwin-x64, on Linux and macOS hosts.
- Other C code gets no new flags.

**Non-Goals:**
- No Windows full-runtime support, no sync assessment for 0.10.18, no pin change.

## Decisions

- **A shim, not the SDK.** zig-cross writes `<target-dir>/zig/<target>/include/sys/vnode.h` with `enum vtype` and explicit values 0 to 10, copied from the macOS SDK and XNU `bsd/sys/vnode.h`. The values are the same for arm64 and x86_64. `-idirafter` puts the directory last, so a real `sys/vnode.h` wins. The SDK was the alternative; it is not available on Linux hosts, and it adds every SDK header as a fallback.
- **Keep `-include limits.h`.** `-DNAME_MAX=255` is narrower, but it changes the meaning of `#ifndef NAME_MAX` in code that includes `limits.h` later. `limits.h` is a standard header with include guards.
- **Scope by source path.** The wrapper adds the flags when an argument matches `*/lib/runtime/*.c` or `*/moonbitlang/async/*.c`. These patterns are fixed and do not need the detected toolchain root, which can differ from the path that moon passes (for example `/tmp` and `/private/tmp`). A C file of a consumer in a directory named `lib/runtime` also gets the flags; the flags are harmless for it.
- **Apply for every toolchain in full mode, except 0.10.15.** The fix only adds a standard header and a fallback header to MoonBit sources, so it cannot break a runtime that does not have the defects. If the fix were only for fingerprinted toolchains, each MoonBit release would break cross builds until a new zig-cross release. Doctor tells the user about the fix: per-target warnings for assessed toolchains, and a sentence in `ZC_TOOLCHAIN_UNVERIFIED` for unassessed ones. The old 0.10.15 pin gets no fix, so its report stays `ok`.
- **Separate full and sync assessments.** `assessed_toolchains` holds 0.10.17 and 0.10.18. `sync_eligible` stays the 0.10.17 entry, because the six sync files were validated only for 0.10.17 (0.10.18 changed `env.c`).

## Risks / Trade-offs

- [A future runtime uses more of `sys/vnode.h`] → The compile fails with the original diagnostics, and doctor reports the toolchain as unverified. Extend the shim after a check.
- [A path pattern misses a vendored copy of async in another directory] → That copy fails as before; the user sees the same compiler error. The README lists the patterns.
- [The shim hides a missing header in a consumer's own C file] → It does not: other C sources do not get `-idirafter`.

## Removal

Remove `headers.mbt` and the flags when moonbit-native-runtime `dir.c` includes `limits.h` and `dir.c`/`fs.c` no longer include `sys/vnode.h` (and moonbitlang/async does the same), or when Zig ships `sys/vnode.h` for macOS.
