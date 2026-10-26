# zig-cross-compatibility-guidance Specification

## Purpose

Expose compatibility limits and actionable recovery guidance through zig-cross itself so users and agents can choose appropriate targets and workarounds before and after a build.

## Requirements

### Requirement: Discoverable guidance

The CLI SHALL advertise `doctor [<target>...] [--json]` in `--help`, describe the Windows platform/core limitation, and explain how to obtain compatibility guidance without consulting external documentation.

#### Scenario: User reads help
- **WHEN** a user invokes `zig-cross --help`
- **THEN** the output includes the diagnostic command, its JSON option, and the warning that a cross-built Windows executable can handle arguments, environment variables, and paths incorrectly

### Requirement: Non-building compatibility diagnosis

The CLI SHALL support `doctor [<target>...] [--json]`, reporting detected host, tool versions, requested targets, known compatibility findings, and unverified conditions. It SHALL default to all listed targets and SHALL NOT build projects, generate wrappers, or alter toolchain files.

#### Scenario: Diagnose selected targets
- **WHEN** a user invokes `zig-cross doctor linux-x64 windows-x64`
- **THEN** the report evaluates those targets and includes the detected MoonBit compiler, Moon build tool, and Zig versions
- **AND** the command does not launch a build or generate compiler wrappers

#### Scenario: Required tool is unavailable
- **WHEN** Moon or Zig cannot be located or executed
- **THEN** doctor reports the missing tool and an actionable installation or PATH correction
- **AND** it exits with status 1 rather than crashing

### Requirement: Actionable findings

Each finding SHALL have a stable code, severity, affected targets, explanation, evidence or applicability conditions, and a concrete next step. Guidance SHALL distinguish verified workarounds, experimental workarounds, and unknown compatibility; it SHALL NOT present an unavailable option as an executable remedy.

#### Scenario: Known runtime compilation limits
- **WHEN** doctor recognizes MoonBit 0.10.17+d971670cd with the shipped affected runtime sources and Zig 0.17.0
- **THEN** it identifies the Linux NAME_MAX issue, macOS vnode header requirement, or Windows MSVC-only runtime issue for each applicable target
- **AND** automatically selected Linux header injection or local macOS SDK headers are reported as active warning findings, with actual flags and prerequisites
- **AND** a restricted-runtime approach is labelled experimental until that mode is implemented and verified

#### Scenario: Toolchain version has not been assessed
- **WHEN** a detected toolchain version has no matching compatibility assessment
- **THEN** doctor reports that compatibility is unverified and gives a concrete validation command
- **AND** it does not claim that an old defect still exists solely because the version is newer

#### Scenario: Unverified validation command uses the assessed targets
- **WHEN** a user invokes `zig-cross doctor darwin-arm64 darwin-x64 windows-x64` with an unassessed toolchain
- **THEN** the `ZC_TOOLCHAIN_UNVERIFIED` command is `zig-cross build darwin-arm64 darwin-x64 windows-x64 -- <package-path>`
- **AND** the command contains only the finding targets and no repository-specific path, and its prerequisites tell the user to replace `<package-path>`

### Requirement: Structured agent report

With `--json`, doctor SHALL write exactly one JSON report to stdout with schema version 1, detected environment, requested targets, overall status, and findings. Finding fields SHALL include code, severity, targets, message, applicability, evidence, and next steps. Exit status SHALL be 1 for error findings, 0 otherwise, and 2 for invalid arguments.

#### Scenario: Agent consumes warnings
- **WHEN** an agent invokes `zig-cross doctor windows-x64 --json` in an environment with warnings but no error findings
- **THEN** stdout contains one JSON document without progress lines, ANSI decoration, or subprocess output
- **AND** the process exits with status 0 and exposes the Windows finding through a stable code

#### Scenario: Invalid doctor argument
- **WHEN** an invocation includes an unknown target, an unknown option, or an unsupported argument separator
- **THEN** it exits with status 2 and a useful usage error
- **AND** an invocation containing `--json` produces a structured usage-error report without mixed prose on stdout

#### Scenario: Finding severities set the report status
- **WHEN** a report contains findings
- **THEN** each finding severity is `error`, `warning` or `unverified`
- **AND** the status is `error` if a finding is `error`, else `warning` if a finding is `warning`, else `unknown` if a finding is `unverified`; a report without findings has status `ok`

### Requirement: Guidance accompanies execution

Build and exec SHALL emit applicable compatibility warnings and any active workaround notice to stderr before launching the affected command. Failed builds SHALL include a target-specific doctor invocation. Guidance SHALL preserve existing build results, executable-header checks, compiler output, child streams, and exit-code behavior.

#### Scenario: Windows build succeeds structurally
- **WHEN** a Windows cross-build produces an executable with a matching PE header
- **THEN** the platform/core warning remains visible
- **AND** the tool does not describe header validation as proof that Windows arguments, paths, or environment handling are correct

#### Scenario: Build fails
- **WHEN** `moon build` fails for linux-arm64
- **THEN** the original compiler diagnostics remain available
- **AND** zig-cross adds `zig-cross doctor linux-arm64` as a concrete diagnostic next step and exits nonzero

#### Scenario: Exec preserves the child contract
- **WHEN** an agent uses `zig-cross exec host -- <command>` and compatibility guidance applies
- **THEN** notices go to stderr while the child's stdin and stdout remain inherited
- **AND** the existing child exit-code mapping is preserved

#### Scenario: A compatibility mode is active
- **WHEN** the explicit `ZIG_CROSS_RUNTIME=sync` compatibility mode is selected for a build or exec command
- **THEN** its notice identifies the mode, affected targets, reason, and excluded functionality
- **AND** doctor reports the same mode and limitations from the same guidance definitions

### Requirement: Bounded isolated synchronous runtime

`ZIG_CROSS_RUNTIME=sync` SHALL select only the six validated synchronous runtime C units from the detected current toolchain in a temporary view. It SHALL require exact assessed compiler/build-tool versions, Zig version, and stock runtime fingerprints. It SHALL NOT mutate the installed toolchain, stub functions, reuse older runtime sources or activate implicitly. Full runtime SHALL remain the default.

#### Scenario: Explicit synchronous consumer build
- **WHEN** an eligible toolchain runs a sync-mode build
- **THEN** all five target formats can be built and checked without macOS SDK headers
- **AND** diagnostics identify the mode as experimental and list excluded runtime functionality

#### Scenario: Excluded functionality
- **WHEN** a sync consumer depends on excluded runtime APIs
- **THEN** compilation/linking fails with original diagnostics and a target-specific doctor hint
- **AND** the guidance directs the user to full runtime with a supported native compiler/host

#### Scenario: Unverified runtime selection
- **WHEN** sync mode is requested with an unknown version or altered runtime
- **THEN** the mode is refused with actionable guidance before child execution

### Requirement: Qualified stable-toolchain upgrade

All platform toolchain pins SHALL name the same independently verified latest stable MoonBit version. Required repository checks, pubman installed consumers, cross-build consumers and production release verification SHALL pass for the upgraded candidate.

#### Scenario: Release qualification
- **WHEN** the upgraded implementation is landed
- **THEN** a subsequent normal release PR publishes both public modules through the existing validated workflow
- **AND** the installed CLI doctor, build and exec behavior is verified before completion
