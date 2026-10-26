## MODIFIED Requirements

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
