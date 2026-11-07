## MODIFIED Requirements

### Requirement: Actionable findings

Each finding SHALL have a stable code, severity, affected targets, explanation, evidence or applicability conditions, and a concrete next step. Guidance SHALL distinguish verified workarounds, experimental workarounds, and unknown compatibility; it SHALL NOT present an unavailable option as an executable remedy.

#### Scenario: Known runtime compilation limits
- **WHEN** doctor recognizes MoonBit 0.10.17+d971670cd, 0.10.18+6c83a7f62 or 0.10.20+65efd5b93 with the shipped affected runtime sources and Zig 0.17.0
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
