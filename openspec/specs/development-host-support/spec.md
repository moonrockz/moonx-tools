# development-host-support Specification

## Purpose

Defines which machines can install the repository's pinned toolchain and run its tasks, what a fresh setup leaves installed, and how tasks that need a Linux or macOS host behave on Windows.

## Requirements

### Requirement: Pinned toolchain installs on supported hosts

`mise install` SHALL install the pinned MoonBit version on linux-x64, macos-arm64, windows-x64 and windows-arm64 hosts. On windows-arm64 it SHALL use MoonBit's x64 Windows archive, which runs under Windows' x64 emulation, because MoonBit publishes no arm64 Windows archive.

#### Scenario: Windows arm64 host
- **WHEN** a contributor runs `mise trust` and `mise install` on a Windows arm64 machine
- **THEN** the install succeeds without a local override
- **AND** `mise exec -- moon version --all` reports the pinned compiler version

#### Scenario: Unsupported host
- **WHEN** `mise install` runs on a host with no MoonBit entry, such as macOS x64
- **THEN** mise fails and names the missing platform, as before

### Requirement: Complete toolchain after install

After `mise install`, the MoonBit install SHALL have the bundled core library for the pinned version and a working `moonx`, with no further manual step. The mise-managed `moon` SHALL use that core library even when another MoonBit install exists in `~/.moon`.

#### Scenario: Fresh install runs a task script
- **WHEN** a contributor runs `mise install` and then `mise run validate:versions` on a fresh machine
- **THEN** the task compiles and runs its `.mbtx` script with the pinned core library

#### Scenario: Older MoonBit in ~/.moon
- **WHEN** `~/.moon` holds a different MoonBit version and the contributor runs `mise run lint:moonbit`
- **THEN** compilation uses the core library of the mise install, not the one in `~/.moon`

#### Scenario: Core download fails
- **WHEN** the core library download fails during `mise install`
- **THEN** `mise install` exits nonzero and reports the failed step
- **AND** no later task runs against a partial toolchain without that error being shown

### Requirement: LF line endings in the working tree

Text files in a checkout SHALL have LF line endings regardless of the contributor's `core.autocrlf` setting.

#### Scenario: Clone with autocrlf enabled
- **WHEN** a contributor with `core.autocrlf=true` clones the repository
- **THEN** `git ls-files --eol` reports `w/lf` for tracked text files
- **AND** `mise run lint:yaml` reports no `new-lines` errors

### Requirement: Repository tasks on Windows hosts

On a Windows host with the pinned toolchain, `lint`, `validate`, `test:scripts`, `build`, `test` and `check` SHALL pass. `test` SHALL skip only the suites listed as needing a Linux or macOS host, pubman on every target and zig-cross on native, and SHALL print one line naming each skipped suite and its target.

#### Scenario: check on Windows arm64
- **WHEN** a contributor runs `mise run check` on a Windows arm64 machine
- **THEN** it exits 0

#### Scenario: Skipped suites are named
- **WHEN** a contributor runs `mise run test -- native` on a Windows host
- **THEN** the output names `apps/pubman` and `apps/zig-cross` as skipped for `native` because they need a Linux or macOS host
- **AND** the other members' native tests run

#### Scenario: Linux and macOS hosts skip nothing
- **WHEN** `mise run test` runs on a Linux or macOS host
- **THEN** every member is tested on every target it supports, as before

### Requirement: Host-limited tasks stop early on Windows

On a Windows host, `test:doctor`, `test:pubman`, `test:consumer`, `test:native-zig` and `build:cross` SHALL exit 1 with an error saying the task needs a Linux or macOS host. The scripts `test:doctor`, `test:pubman` and `test:consumer` SHALL check the host before any build or test step. `test:native-zig` and `build:cross` MAY compile zig-cross before its own host check stops them.

#### Scenario: test:doctor on Windows
- **WHEN** a contributor runs `mise run test:doctor` on a Windows host
- **THEN** it exits 1, and its output says that the task needs a Linux or macOS host
- **AND** it creates no files under `_build`

#### Scenario: test:consumer on Windows
- **WHEN** a contributor runs `mise run test:consumer` on a Windows host
- **THEN** it exits 1 and says that the task needs a Linux or macOS host, before it starts any cross-build

#### Scenario: Direct zig-cross tasks on Windows
- **WHEN** a contributor runs `mise run build:cross -- linux-x64` on a Windows host
- **THEN** it exits 1 with zig-cross's message that it runs on Linux or macOS only

### Requirement: Windows host in CI

CI SHALL run `lint`, `validate`, `test:scripts`, `test` and `build` on a Windows arm64 runner on every pull request, and the required `ci-ok` check SHALL fail when that job fails.

#### Scenario: A change breaks a Windows host
- **WHEN** a pull request makes `mise run test` fail on Windows arm64
- **THEN** the Windows job fails and `ci-ok` fails
