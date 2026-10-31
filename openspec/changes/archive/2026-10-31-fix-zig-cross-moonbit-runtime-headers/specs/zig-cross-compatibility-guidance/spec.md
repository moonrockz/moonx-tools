## ADDED Requirements

### Requirement: Scoped MoonBit runtime header fix

In full runtime mode on a Linux or macOS host, the `cc` wrapper SHALL make the unchanged MoonBit runtime and moonbitlang/async C sources compile with Zig for Linux and darwin targets, without a macOS SDK. It SHALL add the fix flags only to C sources that match `*/lib/runtime/*.c` or `*/moonbitlang/async/*.c`. Sync mode, Windows targets, and the old 0.10.15 pin SHALL get no fix.

#### Scenario: Linux host builds darwin targets with MoonBit 0.10.18
- **WHEN** a user on a Linux host without a macOS SDK runs `zig-cross build darwin-arm64 darwin-x64 -- <package-path>` with MoonBit 0.10.18 and a package that uses moonbitlang/async
- **THEN** the runtime `dir.c` and `fs.c` and the async C stubs compile with the `sys/vnode.h` shim
- **AND** the build produces Mach-O executables for both targets

#### Scenario: Linux targets get limits.h
- **WHEN** the wrapper for linux-x64 compiles `<toolchain>/lib/runtime/dir.c`
- **THEN** the zig command has `-include limits.h` before the original arguments

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

## MODIFIED Requirements

### Requirement: Actionable findings

Each finding SHALL have a stable code, severity, affected targets, explanation, evidence or applicability conditions, and a concrete next step. Guidance SHALL distinguish verified workarounds, experimental workarounds, and unknown compatibility; it SHALL NOT present an unavailable option as an executable remedy.

#### Scenario: Known runtime compilation limits
- **WHEN** doctor recognizes MoonBit 0.10.17+d971670cd or 0.10.18+6c83a7f62 with the shipped affected runtime sources and Zig 0.17.0
- **THEN** it identifies the Linux NAME_MAX issue, macOS vnode header requirement, or Windows MSVC-only runtime issue for each applicable target
- **AND** the automatically selected Linux header injection and macOS `sys/vnode.h` shim are reported as active warning findings, with actual flags, on Linux and macOS hosts
- **AND** a restricted-runtime approach is labelled experimental until that mode is implemented and verified

#### Scenario: Toolchain version has not been assessed
- **WHEN** a detected toolchain version has no matching compatibility assessment
- **THEN** doctor reports that compatibility is unverified and gives a concrete validation command
- **AND** it does not claim that an old defect still exists solely because the version is newer

#### Scenario: Unverified validation command uses the assessed targets
- **WHEN** a user invokes `zig-cross doctor darwin-arm64 darwin-x64 windows-x64` with an unassessed toolchain
- **THEN** the `ZC_TOOLCHAIN_UNVERIFIED` command is `zig-cross build darwin-arm64 darwin-x64 windows-x64 -- <package-path>`
- **AND** the command contains only the finding targets and no repository-specific path, and its prerequisites tell the user to replace `<package-path>`
