## Why

For Linux targets, the zig-cross `cc` wrapper adds `-include limits.h` to MoonBit runtime and moonbitlang/async C sources, because `dir.c` uses `NAME_MAX` and does not include `limits.h`. The forced include comes before the first line of the source. moonbitlang/async 0.22.7 `src/internal/event_loop/fs.c` starts with `#define _GNU_SOURCE` and, on Linux, uses `O_PATH`. With glibc, `limits.h` reads `features.h` before `_GNU_SOURCE` is defined, so `O_PATH` is not declared and the file does not compile. This occurs for `host` on a Linux (glibc) machine: `zig-cross exec host` and `zig-cross build host` fail for every package that uses moonbitlang/async 0.22.7. The musl targets are not affected.

## What Changes

- For Linux targets, including `host` on Linux, the wrapper adds `-DNAME_MAX=255` in place of `-include limits.h`. 255 is the Linux value in glibc and musl, and the definitions are token-identical, so a source that includes `limits.h` gets no redefinition diagnostic. The flag includes no header, so feature-test macros in the source keep their effect.
- Doctor messages and the documentation name the new flag.

Out of scope: darwin (the `sys/vnode.h` shim is not changed), sync mode, Windows targets, the pinned toolchain bump (in the same pull request), and changes in other repositories.

## Capabilities

### Modified Capabilities

- `zig-cross-compatibility-guidance`: the Linux part of the scoped MoonBit runtime header fix.

## Impact

`apps/zig-cross/doctor.mbt`, `apps/zig-cross/headers.mbt`, their white-box tests, and `apps/zig-cross/README.md`. CI `test:native-zig` on Linux checks a glibc host with moonbitlang/async 0.22.7.
