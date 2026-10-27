# npm-distribution Specification

## Purpose

Package a MoonBit library for JavaScript and TypeScript consumers through explicit JavaScript and Wasm-GC npm entry points, with verification of the actual distributed files.

## Requirements

### Requirement: Explicit module configuration

The CLI SHALL read a versioned configuration selecting one MoonBit module, its npm name, export packages, author-defined wrappers, declarations, packaged assets, and consumer checks. It SHALL reject unsupported fields, unsupported targets, ambiguous module selection, and incompatible metadata before building.

#### Scenario: Select a workspace library

- **WHEN** configuration selects a library module inside a workspace containing other modules
- **THEN** the plan identifies only that module and its configured export packages
- **AND** both npm entry points use that module's version

#### Scenario: Reject unsupported backend

- **WHEN** configuration requests the plain `wasm` backend
- **THEN** the command fails with a diagnostic listing `js` and `wasm-gc` as supported outputs
- **AND** no build or publication begins

### Requirement: Standard command options

The CLI SHALL provide contextual help and a global `--json` flag for `plan`, `pack`, `verify`, and `publish` from its first release. The flag SHALL work before or after the subcommand. Invalid invocations SHALL exit with status 2 and perform no build or registry operation.

#### Scenario: Select JSON before or after a subcommand

- **WHEN** a valid invocation selects `--json` before or after any of the four subcommands
- **THEN** the command uses the same JSON reporting contract in either position
- **AND** the flag is available without project-specific configuration

#### Scenario: Reject invalid invocation

- **WHEN** a command has an unknown option or a missing option value
- **THEN** the CLI prints a contextual diagnostic to stderr and exits 2
- **AND** stdout is empty and no command work begins

### Requirement: Dry run for every mutating command

Every command that can change local or remote state SHALL support `--dry-run`, including `pack`, `verify`, and `publish`. Dry runs SHALL validate available local inputs and preview operations without filesystem writes, dependency downloads, tool/test execution, credential operations, or registry calls. This requirement SHALL apply to future mutating commands as well.

#### Scenario: Preview packaging

- **WHEN** an author runs `pack --dry-run` with valid configuration
- **THEN** the CLI describes source capture, builds, declaration/assets, packing, and output paths
- **AND** it creates no staging directories, archives, artifacts, locks, or receipts and invokes no compiler or package manager

#### Scenario: Preview verification

- **WHEN** an author runs `verify --dry-run` against an existing valid bundle
- **THEN** the CLI lists the intended consumer installation and runtime/TypeScript checks
- **AND** it installs nothing, runs no checks or author code, and neither creates nor refreshes a verification receipt

### Requirement: Dry-run reports distinguish preview from execution

Dry-run reports SHALL identify planned operations and unresolved prerequisites without claiming unexecuted work passed. With `--json`, they SHALL use the shared envelope with `data.dryRun` true, ordered operations, and unexecuted checks marked `not-run`. A successful preview SHALL NOT satisfy verification or publication evidence requirements.

#### Scenario: Pipe a dry-run result

- **WHEN** a valid mutating command runs with both `--dry-run` and `--json`
- **THEN** stdout contains exactly one JSON envelope identifying a preview and its ordered operations
- **AND** skipped checks are marked `not-run` rather than successful

#### Scenario: Preview cannot qualify a release

- **WHEN** only dry-run verification has been performed for a bundle
- **THEN** actual publication remains blocked by missing successful verification evidence

### Requirement: Versioned JSON reports

For accepted operational invocations with `--json`, the CLI SHALL emit one JSON document and a newline on stdout with `schemaVersion`, `command`, `ok`, `data`, and `error`. Success and failure SHALL use the same envelope and preserve exit status. Progress, child-process logs, and terminal decoration SHALL NOT appear on stdout. Human-readable output SHALL remain the default.

#### Scenario: Pipe a successful result

- **WHEN** any operational command succeeds with `--json` while its subprocesses print progress
- **THEN** a JSON consumer can parse stdout directly and extract command-specific results from `data`
- **AND** `schemaVersion` is 1, `ok` is true, `error` is null, and exit status is 0
- **AND** subprocess/progress output is confined to stderr

#### Scenario: Report a command failure as JSON

- **WHEN** argument parsing succeeds with `--json` but configuration, building, or verification fails
- **THEN** stdout contains one JSON envelope with `ok` false and a stable error code, message, and structured details
- **AND** the exit status remains nonzero and any completed results remain in `data`

#### Scenario: Preserve schema compatibility

- **WHEN** a later release extends schema version 1 reports
- **THEN** documented existing fields retain their meanings and types
- **AND** incompatible changes require a different schema version

### Requirement: Read-only plan

The `plan` command SHALL report resolved module identity, npm identity, version, backend inputs, entry points, declaration sources, output location, required tools, and verification commands. It SHALL support human-readable and JSON output without building, changing source files, or contacting registries.

#### Scenario: Inspect a release plan

- **WHEN** a valid project runs `plan --json`
- **THEN** stdout contains a machine-readable plan with the resolved configuration
- **AND** no build, output deletion, login, or registry operation occurs

### Requirement: Two explicit ESM entry points

Unless `--dry-run` is selected, `pack` SHALL build configured JavaScript and Wasm-GC export packages in release mode and create one npm ESM package. Its root entry SHALL use generated JavaScript and its `/wasm` entry SHALL expose the author's Wasm API. Runtime backend selection SHALL be explicit, with no automatic fallback.

#### Scenario: Use generated JavaScript

- **WHEN** a consumer imports the installed package root
- **THEN** its author-defined API runs using the compiled JavaScript
- **AND** importing or calling it does not load the Wasm binary

#### Scenario: Use Wasm-GC

- **WHEN** a consumer imports the installed `/wasm` entry and initializes it
- **THEN** the packaged Wasm-GC binary is loaded with its configured imports and compile options
- **AND** unsupported runtime capabilities produce an actionable initialization error

### Requirement: Wasm asset loading

The Wasm entry SHALL support Node file loading and browser URL loading without paths into the author's checkout. Its loader SHALL accept caller-supplied bytes or a URL and host imports. JS string builtins and imported string constants SHALL be configured consistently with the selected export package.

#### Scenario: Load a relocated package

- **WHEN** the npm tarball is installed outside the source checkout
- **THEN** the default loader resolves the binary relative to the installed package
- **AND** Node and browser consumer checks can initialize the Wasm API

#### Scenario: Override asset delivery

- **WHEN** a consumer supplies Wasm bytes or an asset URL and required host imports
- **THEN** initialization uses those inputs instead of assuming the binary is hosted beside the application

### Requirement: TypeScript declarations for every public entry

The npm package SHALL include `.d.ts` declarations for both public entry points and every required local declaration dependency. The CLI SHALL accept supplied declarations and usable compiler declarations, map them through npm `exports` type conditions, and fail when declarations are absent or unresolved.

#### Scenario: Publish wrapper types

- **WHEN** the configured JavaScript and Wasm wrappers have separate author-supplied declarations
- **THEN** imports of the package root and `/wasm` resolve to their respective declarations
- **AND** the Wasm declaration describes its initialization API

#### Scenario: Preserve compiler declaration dependencies

- **WHEN** a selected compiler declaration imports a generated sibling such as `moonbit.d.ts`
- **THEN** the sibling is present at the referenced location in the tarball
- **AND** missing or escaping local references fail verification

#### Scenario: Missing Wasm declaration

- **WHEN** the JavaScript entry has declarations but the Wasm entry does not
- **THEN** packing fails and identifies the missing Wasm declaration

### Requirement: Controlled package contents

Packing SHALL include only declared assets and required generated artifacts, metadata, README, and license files. It SHALL reject output collisions, path traversal, symlink escapes, and output paths overlapping source inputs. Failed builds SHALL NOT reuse stale artifacts or replace the last successful bundle.

#### Scenario: Build fails after a prior success

- **WHEN** a new build fails and an earlier output bundle exists
- **THEN** the new invocation fails without producing a successful replacement bundle
- **AND** it does not package artifacts from the earlier build

#### Scenario: Asset escapes the project

- **WHEN** a configured asset resolves outside the selected module through `..` or a symlink
- **THEN** the command fails before copying it

### Requirement: Verify the installed tarball

Unless `--dry-run` is selected, `verify` SHALL install the packed npm tarball in an isolated consumer directory, check both runtime entry points, run strict TypeScript consumer checks without skipping library checks, and execute configured contract tests. Verification SHALL bind its result to the exact package contents, configuration, checks, and tool versions.

#### Scenario: TypeScript catches invalid usage

- **WHEN** the consumer checks include valid calls and expected errors for invalid argument types on both entries
- **THEN** valid usage compiles and every expected error is observed
- **AND** a declaration that weakens those arguments to `any` fails the checks

#### Scenario: Resolve declarations as consumers do

- **WHEN** verification runs the configured TypeScript consumer checks
- **THEN** the baseline checks exercise NodeNext and bundler module resolution
- **AND** declaration files are resolved from the installed package rather than source aliases

#### Scenario: Runtime wrapper is broken

- **WHEN** a declaration compiles but an author-supplied runtime contract check fails
- **THEN** verification fails and reports the failing entry point or check
- **AND** no publishable verification result is recorded

#### Scenario: Publish prebuilt artifacts

- **WHEN** the tarball is installed by a consumer without MoonBit
- **THEN** both entries work without compiling MoonBit or running install-time build scripts
