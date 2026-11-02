# Spec Delta

## ADDED Requirements

### Requirement: Windows findings cover every Windows target

Doctor, build and exec SHALL apply the Windows findings to every requested Windows target, `windows-x64` and `windows-arm64`. `ZC_WINDOWS_OSSTRING` SHALL be one finding whose targets are the requested Windows targets. In full runtime mode with an assessed toolchain, each Windows target SHALL get its own `ZC_WINDOWS_MSVC_RUNTIME` error finding.

#### Scenario: Doctor on windows-arm64 in sync mode
- **WHEN** an agent invokes `ZIG_CROSS_RUNTIME=sync zig-cross doctor windows-arm64 --json` with an eligible toolchain
- **THEN** the report has `ZC_COMPATIBILITY_MODE` and a `ZC_WINDOWS_OSSTRING` warning whose targets are `["windows-arm64"]`
- **AND** the process exits with status 0

#### Scenario: Both Windows targets requested
- **WHEN** a user invokes `zig-cross doctor windows-x64 windows-arm64 linux-x64`
- **THEN** the report has exactly one `ZC_WINDOWS_OSSTRING` finding, with targets `windows-x64` and `windows-arm64`
- **AND** `linux-x64` is not among its targets

#### Scenario: Full runtime for windows-arm64
- **WHEN** a user invokes `zig-cross doctor windows-arm64` with an assessed toolchain and no `ZIG_CROSS_RUNTIME`
- **THEN** the report has a `ZC_WINDOWS_MSVC_RUNTIME` error for `windows-arm64` whose next steps name `ZIG_CROSS_RUNTIME=sync zig-cross build windows-arm64 -- <package-path>`
- **AND** the process exits with status 1

#### Scenario: windows-arm64 build keeps the warning
- **WHEN** a `windows-arm64` build produces an executable with a matching PE header
- **THEN** stderr contains the `ZC_WINDOWS_OSSTRING` warning for `windows-arm64`
- **AND** the tool does not describe the header check as proof that arguments, paths or environment handling are correct

## MODIFIED Requirements

### Requirement: Bounded isolated synchronous runtime

`ZIG_CROSS_RUNTIME=sync` SHALL select only the six validated synchronous runtime C units from the detected current toolchain in a temporary view. It SHALL require exact assessed compiler/build-tool versions, Zig version, and stock runtime fingerprints. It SHALL NOT mutate the installed toolchain, stub functions, reuse older runtime sources or activate implicitly. Full runtime SHALL remain the default.

#### Scenario: Explicit synchronous consumer build
- **WHEN** an eligible toolchain runs a sync-mode build
- **THEN** all six cross target formats can be built and checked without macOS SDK headers
- **AND** diagnostics identify the mode as experimental and list excluded runtime functionality

#### Scenario: Excluded functionality
- **WHEN** a sync consumer depends on excluded runtime APIs
- **THEN** compilation/linking fails with original diagnostics and a target-specific doctor hint
- **AND** the guidance directs the user to full runtime with a supported native compiler/host

#### Scenario: Unverified runtime selection
- **WHEN** sync mode is requested with an unknown version or altered runtime
- **THEN** the mode is refused with actionable guidance before child execution
