## MODIFIED Requirements

### Requirement: Scoped MoonBit runtime header fix

In full runtime mode on a Linux or macOS host, the `cc` wrapper SHALL make the unchanged MoonBit runtime and moonbitlang/async C sources compile with Zig for Linux and darwin targets, without a macOS SDK. It SHALL add the fix flags only to C sources that match `*/lib/runtime/*.c` or `*/moonbitlang/async/*.c`. Sync mode, Windows targets, and the old 0.10.15 pin SHALL get no fix.

#### Scenario: Linux host builds darwin targets with MoonBit 0.10.18
- **WHEN** a user on a Linux host without a macOS SDK runs `zig-cross build darwin-arm64 darwin-x64 -- <package-path>` with MoonBit 0.10.18 and a package that uses moonbitlang/async
- **THEN** the runtime `dir.c` and `fs.c` and the async C stubs compile with the `sys/vnode.h` shim
- **AND** the build produces Mach-O executables for both targets

#### Scenario: Linux targets get limits.h
- **WHEN** the wrapper for linux-x64 compiles `<toolchain>/lib/runtime/dir.c`
- **THEN** the zig command has `-DNAME_MAX=255`, the Linux `limits.h` value, before the original arguments
- **AND** the zig command does not force an include of `limits.h` or another header before the source

#### Scenario: Linux host compiles async sources that define feature-test macros
- **WHEN** `zig-cross exec host` on a Linux glibc host compiles moonbitlang/async 0.22.7 `src/internal/event_loop/fs.c`, which defines `_GNU_SOURCE` and uses `O_PATH`
- **THEN** the file compiles

#### Scenario: Darwin targets get the vnode shim
- **WHEN** the wrapper for darwin-arm64 compiles `<toolchain>/lib/runtime/fs.c`
- **THEN** the zig command has `-idirafter <target-dir>/zig/darwin-arm64/include` before the original arguments
- **AND** that directory holds a `sys/vnode.h` with only `enum vtype`, `VNON` = 0 to `VCPLX` = 10, as in the macOS SDK

#### Scenario: Other C code is not changed
- **WHEN** the wrapper compiles a C source that is not a MoonBit runtime or moonbitlang/async source
- **THEN** the zig command has no header fix flags

#### Scenario: Unassessed toolchain gets the fix with a notice
- **WHEN** an unassessed toolchain runs in full runtime mode for linux-arm64 and darwin-x64
- **THEN** the wrapper applies the header fix
- **AND** the `ZC_TOOLCHAIN_UNVERIFIED` message names those targets and the fix, and doctor does not report `ZC_LINUX_NAME_MAX`
