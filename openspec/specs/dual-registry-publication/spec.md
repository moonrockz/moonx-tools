# dual-registry-publication Specification

## Purpose

Publish one MoonBit library release to Mooncakes and npm with matching versions, verified package contents, and explicit recovery behavior when only part of publication succeeds.

## Requirements

### Requirement: Shared release identity

The tool SHALL use the selected MoonBit module's version for its Mooncakes publication and generated npm package. A release bundle SHALL identify the module and npm names, source snapshot, configuration, tool versions, and artifact digests. It SHALL reject conflicting versions rather than rewriting source metadata.

#### Scenario: Version disagreement

- **WHEN** configured npm metadata declares a version different from the selected module
- **THEN** planning fails with both values in the diagnostic
- **AND** neither manifest is rewritten

#### Scenario: Tool version differs from library version

- **WHEN** the CLI's own version differs from the selected library version
- **THEN** the release bundle uses the library version for both registries
- **AND** the CLI version is recorded separately as build provenance

### Requirement: Verification before publication

The `publish` command SHALL require a release bundle whose files and verification inputs match a successful verification result. Missing, failed, or stale verification SHALL block all registry writes. It SHALL recheck bundle integrity and reject concurrent publication of the same bundle.

#### Scenario: Tarball modified after verification

- **WHEN** the npm tarball changes after verification
- **THEN** publication fails before either registry is modified
- **AND** the diagnostic directs the author to pack and verify again

#### Scenario: Verification definition changed

- **WHEN** the configured declarations, checks, or tool versions differ from those recorded by verification
- **THEN** the old verification result cannot authorize publication

### Requirement: Registry preflight

Before its first registry write, actual publication SHALL validate public package identities, version availability, registry destinations, npm tag selection, and available authentication for both registries. Existing versions SHALL be treated as conflicts unless matching publication evidence establishes an already-completed operation.

#### Scenario: npm version already exists

- **WHEN** the npm version exists with a different tarball integrity value
- **THEN** publication fails as a conflict before Mooncakes publication

#### Scenario: Missing authentication

- **WHEN** either registry's required authentication is unavailable
- **THEN** publication fails before writing to either registry
- **AND** the tool reports which existing login or CI credential setup is required

#### Scenario: Prerelease tag is unspecified

- **WHEN** a prerelease version is published without an explicitly selected npm tag
- **THEN** the tool rejects the request instead of implicitly changing `latest`

### Requirement: Publish verified contents

Publication SHALL send the exact verified tarball to npm and the bundled source snapshot to Mooncakes, without rebuilding from a mutable checkout or running package lifecycle build scripts. It SHALL use installed registry CLIs and existing authentication, without persisting credentials in the bundle or command reports.

#### Scenario: Checkout changes after packing

- **WHEN** an unrelated working checkout changes after a bundle was packed and verified
- **THEN** publishing that bundle uses its captured source and npm artifacts
- **AND** it does not rebuild or package the current checkout

### Requirement: Read-only publication dry run

The `publish --dry-run` command SHALL inspect available local bundle/evidence files and preview both registry operations and prerequisites. It SHALL require no production credentials and SHALL NOT execute verification, extract source, write files/receipts/locks, contact registries, log in, or modify registry state. Missing verification SHALL be reported as a prerequisite rather than executed implicitly.

#### Scenario: CI dry run

- **WHEN** CI runs publication in dry-run mode without registry credentials
- **THEN** it inspects local inputs and reports both intended publications
- **AND** fake filesystem/process/registry observations show no writes, extraction, tests, or registry calls

#### Scenario: Missing verification during preview

- **WHEN** a bundle has no successful verification receipt and the author runs `publish --dry-run --json`
- **THEN** the preview reports verification as an outstanding prerequisite with unexecuted checks marked `not-run`
- **AND** it does not run checks, write a receipt, or imply the bundle is qualified for publication

### Requirement: Report and resume partial publication

Publication SHALL record a result for each registry and exit nonzero unless both are confirmed complete. A resumed run SHALL skip a completed registry only with matching artifact evidence and registry existence. Uncertain outcomes SHALL remain explicit; recovery SHALL NOT unpublish, replace versions, or silently accept duplicates.

#### Scenario: Mooncakes succeeds and npm fails

- **WHEN** Mooncakes publication succeeds and npm publication fails
- **THEN** the command records Mooncakes as published and npm as failed or uncertain
- **AND** a resumed invocation with the same bundle and confirmed receipt skips Mooncakes and attempts only the unfinished npm operation

#### Scenario: Ambiguous Mooncakes publication

- **WHEN** the network fails after a possible Mooncakes acceptance and no successful publication receipt exists
- **THEN** the tool reports an uncertain outcome
- **AND** discovering the version exists does not by itself establish matching contents or permit automatic continuation

#### Scenario: Existing npm artifact matches

- **WHEN** npm already holds the bundle's exact tarball integrity and package identity
- **THEN** the tool records that npm publication is complete without uploading again
- **AND** a mismatched requested tag is reported rather than silently considered complete

### Requirement: Bounded retry and useful diagnostics

Registry commands SHALL retry only classified transient failures with bounded attempts. Authentication, permission, content conflict, and invalid package failures SHALL stop immediately. Human-readable and JSON reports SHALL identify registry outcomes and recovery actions without exposing credentials.

#### Scenario: Permission denied

- **WHEN** a publish attempt fails with an authentication or permission error
- **THEN** the tool makes no automatic retry of that operation
- **AND** the failure report identifies the registry and required corrective action

#### Scenario: Automate recovery from a partial release

- **WHEN** `publish --json` completes one registry operation and fails the other
- **THEN** stdout contains the shared versioned JSON envelope with `ok` false, a stable error code, and both registry outcomes in `data`
- **AND** the exit status is nonzero and diagnostics/retry progress remain on stderr

#### Scenario: Lost response requires reconciliation

- **WHEN** an upload times out after it might have reached a registry
- **THEN** the tool checks existing publication evidence before any retry
- **AND** it reports uncertainty when matching contents cannot be established
