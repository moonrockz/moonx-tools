# Spec Delta

## Purpose

Defines which target names zig-cross accepts, the Zig triple each cross target compiles for, and the executable format a build must produce for each target.

## ADDED Requirements

### Requirement: Supported target names

The CLI SHALL accept exactly these target names, listed in this order in help and errors: `linux-x64`, `linux-arm64`, `darwin-arm64`, `darwin-x64`, `windows-x64`, `windows-arm64`, `host`. Any other name SHALL be rejected with exit status 2 and an error that lists the accepted names.

#### Scenario: Help lists windows-arm64
- **WHEN** a user invokes `zig-cross --help`
- **THEN** the targets line lists `windows-arm64` after `windows-x64` and before `host`

#### Scenario: Unknown target is rejected
- **WHEN** a user invokes `zig-cross build windows-arm`
- **THEN** zig-cross exits with status 2 without starting `moon`
- **AND** stderr contains `unknown target: windows-arm (expected one of linux-x64, linux-arm64, darwin-arm64, darwin-x64, windows-x64, windows-arm64, host)`

#### Scenario: Doctor defaults to every target
- **WHEN** a user invokes `zig-cross doctor` with no target
- **THEN** the report's targets are all seven names, in the order above

### Requirement: Cross target triples

Each cross target's `cc` wrapper SHALL pass the Zig target triple below. `host` passes no triple. `linux-x64` uses `x86_64-linux-musl`, `linux-arm64` uses `aarch64-linux-musl`, `darwin-arm64` uses `aarch64-macos`, `darwin-x64` uses `x86_64-macos`, `windows-x64` uses `x86_64-windows-gnu`, and `windows-arm64` uses `aarch64-windows-gnu`.

#### Scenario: windows-arm64 wrapper
- **WHEN** zig-cross writes the wrappers for `windows-arm64`
- **THEN** the `cc` wrapper runs `zig cc -target aarch64-windows-gnu -D_CRT_RAND_S`
- **AND** like the other cross wrappers, it drops `-DMOONBIT_USE_SIMDUTF`, `moonbit_simdutf.o`, `simdutf.o` and `libbacktrace.a`, and the `ar` wrapper drops the two simdutf objects

#### Scenario: Windows targets get no header fix
- **WHEN** the `windows-arm64` wrapper compiles a MoonBit runtime C source in full runtime mode
- **THEN** the zig command has no `-include limits.h` and no `-idirafter` flag

### Requirement: Executable format check

After a build, zig-cross SHALL read the header of each executable of a cross target and report it as failed when the format differs from the target's expected format: ELF machine 62 or 183 for Linux x64 or arm64, Mach-O cputype 16777223 or 16777228 for darwin x64 or arm64, and PE machine 0x8664 or 0xAA64 for Windows x64 or arm64. `host` is not checked.

#### Scenario: Correct windows-arm64 header
- **WHEN** a `windows-arm64` build produces an executable with PE machine 0xAA64
- **THEN** the summary row for that executable reports success

#### Scenario: x64 binary under windows-arm64
- **WHEN** a `windows-arm64` build produces an executable with PE machine 0x8664
- **THEN** the summary reports the expected and found machine for that executable
- **AND** zig-cross exits with status 1

#### Scenario: Synchronous runtime consumer for windows-arm64
- **WHEN** an eligible toolchain builds the consumer fixture for `windows-arm64` with `ZIG_CROSS_RUNTIME=sync` on a Linux or macOS host
- **THEN** the build links and produces a PE executable with machine 0xAA64
