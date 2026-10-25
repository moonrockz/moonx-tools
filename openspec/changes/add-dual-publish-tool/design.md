# Design

## Context

See proposal.md for the motivation and agreed scope. The repository has one public CLI, `apps/zig-cross`, with async filesystem/process access and `native+wasm` host support. `scripts/publish.mbtx` and `scripts/release.mbtx` maintain matching public-module lists. `scripts/versions.mbtx` synchronizes versions across `moon.work`. CI already separates lint, backend builds/tests, script tests, and a Linux/macOS consumer category.

The installed toolchain reports `moon 0.1.20261012` and npm `11.11.0`; mise pins MoonBit `0.10.15+943464bfa` and Node `24.14.1`. Local CLI help confirms per-package builds, `--target-dir`, `moon package`, and `moon publish`. Moon publication accepts a directory, not an npm-style source archive argument. Online documentation is newer than some pinned compiler behavior, so fixture-backed toolchain contracts must precede packaging implementation.

References inspected during planning:

- [MoonBit package configuration](https://docs.moonbitlang.com/en/stable/toolchain/moon/package.html), for backend exports, ESM format, and Wasm-GC string options.
- [MoonBit FFI](https://docs.moonbitlang.com/en/stable/language/ffi.html), for explicit foreign-library exports and managed value boundaries.
- [MoonBit CLI quickstart](https://docs.moonbitlang.com/en/stable/tutorial/cli-quickstart.html), for standard-library `argparse`; also inspect the pinned toolchain's local `argparse` interface, README, and global-option tests.
- [npm pack](https://docs.npmjs.com/cli/v11/commands/npm-pack/) and [npm publish](https://docs.npmjs.com/cli/v11/commands/npm-publish/), for tarball packaging, lifecycle suppression, immutable versions, and integrity metadata.

## Goals / Non-Goals

**Goals:** Make the distribution process reusable without imposing a JavaScript API design; verify the files consumers actually receive; preserve one source/version identity across both registries; make partial publication visible and recoverable.

**Non-Goals:** Build an FFI generator, infer arbitrary MoonBit types as JavaScript objects, manage user credentials, or replace project release management. Initial compatibility is the pinned toolchain and current `moon.mod` / `moon.pkg` manifests. Older JSON manifests, unreleased local path dependencies, and broad compiler-version compatibility are deferred.

## Decisions

### 1. A standalone MoonBit CLI with a small command lifecycle

Use `apps/pubman`, module `moonrockz/pubman`, with `supported_targets = "native+wasm"`. Linux and macOS are supported hosts, matching the existing CLI. The library outputs are JavaScript and Wasm-GC, independent of the backend used to execute the CLI. No Zig dependency or native cross-compilation is introduced; Windows hosting is deferred.

Import `moonbitlang/core/argparse` from the pinned standard library and declare the command tree, flags, options, and contextual help there. The pinned package provides `Command`, `FlagArg`, `OptionArg`, explicit-argv parsing, and inherited global flags. Define `--json` once as a global flag, accepted before or after the subcommand. Declare `--dry-run` on every command that can change local or remote state, starting with `pack`, `verify`, and `publish`. Convert argparse matches into typed application requests and keep application/configuration validation separate. Do not introduce a custom argv tokenizer, option scanner, or fallback parser, and do not copy zig-cross's hand-written parser. The standard-library version follows the MoonBit toolchain pin.

Proposed interface:

```sh
moonx moonrockz/pubman plan --config pubman.json --json
moonx moonrockz/pubman pack --config pubman.json
moonx moonrockz/pubman pack --config pubman.json --dry-run --json
moonx moonrockz/pubman verify --bundle _build/pubman/release
moonx moonrockz/pubman verify --bundle _build/pubman/release --dry-run --json
moonx moonrockz/pubman publish --bundle _build/pubman/release --dry-run
moonx moonrockz/pubman publish --bundle _build/pubman/release
moonx moonrockz/pubman --json pack --config pubman.json
moonx moonrockz/pubman verify --bundle _build/pubman/release --json
```

`plan` performs local reads only. Without `--dry-run`, `pack` builds and packages without publishing, `verify` tests a bundle and records evidence, and `publish` requires successful verification and rechecks its evidence before publishing. All commands support `--json`, `--help`, and useful exit codes: 0 success, 2 invalid invocation/configuration, 1 build/check/publication failure.

Every mutating command must have a side-effect-free `--dry-run` path from v1. `verify` counts as mutating because it installs a temporary consumer, runs author code, and writes a verification receipt. `plan` is inherently read-only and does not need a dry-run mode. The same rule applies to any future command that writes local files, caches, credentials, receipts, tags, or registry state.

Build an operation description shared by preview and execution before entering any mutation path. A dry run reads and validates available local configuration/bundle files and describes the ordered operations, inputs, outputs, publication destinations, and prerequisites. It must branch before creating staging/temporary directories, acquiring file locks, resolving/downloading dependencies, invoking compiler/package/registry commands, running consumer tests, or writing reports/receipts to disk. Do not delegate dry-run behavior to child tools, whose own dry-run modes can still run lifecycle hooks or write caches.

| Command | Dry-run preview |
| --- | --- |
| `pack` | Source capture, backend builds, declaration/asset mappings, npm packing, and output bundle location. Compiler-generated files are planned references, not falsely reported missing before a build. |
| `verify` | Consumer installation, Node/browser/TypeScript checks, and intended receipt. No checks execute and no verification evidence is created. |
| `publish` | Both intended registry operations, artifact identities, and existing local evidence. No registry/authentication calls or source extraction occur. Missing verification is reported as a prerequisite, not performed implicitly. |

Combine `--dry-run` and `--json` using the normal envelope, with `data.dryRun: true`, an ordered `operations` list, prerequisites, and skipped checks explicitly marked `not-run`. Successful preview means its local validation and planning succeeded; it does not certify compilation, verification, credentials, registry availability, or publication. Actual invalid local inputs still fail with the normal error/exit-code contract. A preview never creates or refreshes successful verification/publication receipts. CI must run real local `pack` and `verify` before testing the publication preview.

Human-readable output remains the default. `--json` is a standard option on every operational command from v1, not an optional future addition. Use a shared report model and formatter so both output modes describe the same outcome. Once argparse has accepted the invocation, emit exactly one JSON document followed by a newline on stdout, for success or failure. Do not use NDJSON, ANSI decoration, progress lines, or subprocess output on that stream. Capture child stdout/stderr as needed for parsing and send human logs to stderr, even when `npm`, `moon`, or a consumer check prints to stdout.

The JSON envelope has `schemaVersion: 1`, `command`, `ok`, `data`, and `error` fields. `error` is null on success; failures contain a stable code, message, and structured details. `data` holds command-specific results, including artifact locations/integrities, verification checks, or per-registry publication outcomes; partial failures retain completed results. Document command data fields, ordering guarantees for lists, nullable fields, and stable error codes. Additive fields are permitted within schema v1; incompatible changes require a new schema version. JSON formatting does not change exit status.

Argparse syntax errors are a documented exception: emit the parser diagnostic/contextual help to stderr, leave stdout empty, exit 2, and perform no work. This avoids a separate ad hoc argv scan to recover output mode from an invalid invocation. Configuration and operational failures after successful parsing use the JSON error envelope when selected. Help/version requests use argparse's standard informational behavior and do not perform packaging or publication.

Keeping packaging separate permits CI artifact inspection and reuse. A single command that silently rebuilt and published would make the verified candidate harder to identify.

### 2. Explicit versioned configuration

Use `pubman.json` with `schemaVersion: 1`. Resolve relative paths against its directory and require packaged inputs to remain inside the selected module after canonicalization. `module` selects a module even inside a workspace; default it to the configuration directory only when unambiguous.

The configuration groups are:

| Group | Contract |
| --- | --- |
| `module` | Selected module directory. Read its name, version, description, license, repository, and visibility. |
| `npm` | Explicit npm name, optional matching version assertion, description overrides, public access, declared runtime dependencies, and tag. No lifecycle scripts. |
| `entries.js` | MoonBit export package, ESM wrapper source, public declaration source. |
| `entries.wasm` | MoonBit export package, ESM wrapper source, public declaration source, loader options. |
| `assets` | Explicit source-to-package mappings for helper modules, declaration dependencies, README, and license. |
| `checks` | Node/browser contract test sources and TypeScript consumer sources for both entries. |
| `output` | Tool-owned bundle location, defaulting beneath `_build/pubman/`. |

Declaration sources distinguish author files from compiler artifacts. Compiler artifact references identify a backend and relative output path, so generated declaration paths do not have to exist during `plan`. A selected declaration closure must resolve within the npm package or through declared npm dependencies. Validate unknown fields and destination collisions. Do not copy arbitrary source trees or derive npm scope from the Mooncakes username.

Use a proper manifest reader for the documented scalar metadata subset, including string escaping and comments. Unsupported metadata expressions receive explicit diagnostics; do not copy the release scripts' line matching into a general-purpose parser. Prefer a reusable compatible MoonBit parser if available without expanding scope. There is no requirement to edit or reformat the author's manifests.

### 3. Author-owned API adapters and required declarations

Authors implement MoonBit export packages and ESM wrappers. Root wrapper imports refer to a stable packaged location, `../internal/js/library.js`. The Wasm wrapper imports `../internal/wasm/loader.mjs`. These are documented paths inside the package, independent of compiler build-directory names.

Generated npm layout:

```text
package.json
README.md
LICENSE
js/index.mjs
js/index.d.ts
wasm/index.mjs
wasm/index.d.ts
internal/js/library.js
internal/js/<referenced generated files>
internal/wasm/library.wasm
internal/wasm/loader.mjs
<explicit additional assets>
```

Generate `type: module`, root `types`, and `exports` entries for `.` and `./wasm`, each with its own `types` condition preceding `import`. Do not assert `sideEffects: false` or equivalence of the two APIs without an author guarantee. Consumers may have a synchronous root API and an asynchronous Wasm initializer.

Require declarations for both entries. Compiler-generated `.d.ts` can be selected when it accurately describes the wrapper. Otherwise authors supply `.d.ts`; this is especially relevant to the Wasm initialization API. Preserve relative declaration dependencies such as `moonbit.d.ts`, and validate them with TypeScript. Do not synthesize `any` declarations to satisfy packaging. This delivers TypeScript support without claiming to generate correct types for arbitrary exported MoonBit values.

### 4. Generic Wasm loader, no value marshalling generator

Emit a small ESM loader used by the author wrapper. It accepts optional bytes or a URL, a host import object, and configured Wasm compile options. The default URL is relative to the packaged binary. Node file URLs use a conditional dynamic import of Node filesystem APIs; browser URLs use `fetch`. Byte loading avoids depending on correct Wasm HTTP MIME types.

The loader forwards JS string builtins and imported-string-constant settings to instantiation when configured; these must match the export package. It does not inspect or convert arbitrary Wasm-GC structs, enums, `Result`, or arrays. Authors supply accessor functions, handles, or JS-friendly representations. Errors identify the asset and required runtime features without an automatic JS fallback.

Supported runtime evidence initially covers pinned Node and a pinned Chromium browser. Bun, Deno, other browsers, and bundler-specific asset transformations are not certified by this first release. Callers can provide bytes or an asset URL for their bundler/CDN arrangement.

### 5. Capture publishable source before building

First run `moon package` for the selected module, capture its actual source archive, and extract it into an isolated build directory. Build the two configured packages from that snapshot with fresh target directories and frozen dependency resolution after obtaining declared registry dependencies. Reject local path dependencies and missing source files. Resolve dependency versions explicitly and record them with the bundle.

Packaging wrappers/checks that Moon's archive excludes are captured separately as declared inputs. A fixture verifies that both compiled backends use the captured MoonBit source. Workspace sibling code must not accidentally substitute for released registry dependencies.

Use fresh staging directories for every pack. Locate the configured package's output under its dedicated target tree and require an unambiguous result. Copy generated files with preserved relative declaration/import relationships. Call `npm pack --json --ignore-scripts` on the assembled package, inspect its file inventory, and store the tarball integrity. Commit a successful bundle to the final output location only after packing succeeds; keep an earlier good bundle intact on failure.

A bundle contains the npm tarball, Mooncakes source archive, captured config/check inputs, artifact inventory/digests, dependency and tool versions, and later verification/publication receipts. Hash byte contents, not mtimes. Source/archive entries and output locations receive traversal and symlink checks. Never recursively delete an unowned directory.

For Mooncakes publication, extract the stored source archive into fresh staging and invoke `moon publish` there. Repackage/check the staging file inventory against the captured snapshot before publication. This addresses Moon's directory-based publish interface without publishing a changed working checkout.

### 6. Installed-package verification is the release gate

Install the exact npm tarball with lifecycle scripts disabled in a temporary consumer outside the source checkout. Resolve only from the installed package, with no source path aliases or workspace node_modules fallback. Check the root and `/wasm` exports and their declared assets.

Require author contract checks that exercise meaningful API calls for each backend. Node and browser checks use packaged files. The repository's fixture covers strings including non-ASCII text, numeric values, results/errors exposed through author wrappers, Wasm initialization, and override bytes/URLs. These checks demonstrate wrapper correctness that declarations alone cannot prove.

Compile positive and negative TypeScript consumers for both entries under strict NodeNext and bundler resolution, with library checking enabled. Negative cases use expected errors so an argument accidentally typed as `any` fails. TypeScript cannot prove runtime/declaration equivalence; the paired runtime checks cover concrete advertised behavior.

The CLI invokes installed tools and never silently downloads developer tools. Pin TypeScript and browser tooling for this repository; report prerequisites for downstream projects. Browser/Node harness JavaScript is consumer test code; task orchestration remains MoonBit `.mbtx` scripts.

Verification records hashes of the bundle and check sources, CLI/check implementation identity, configured options, and tool versions. Changing any invalidates the receipt. Publication rehashes inputs, requires compatible recorded tool versions, and locks the bundle against concurrent writers. Local receipts are release bookkeeping, not attestations for untrusted downloaded bundles.

### 7. Conservative dual-registry publication

Publish only to the public Mooncakes and npm registries in v1. Explicitly configure npm public access and validate destinations so an inherited `.npmrc` cannot redirect publication. Use existing Moon credentials, npm login/token/OIDC support, and non-writing authentication checks. Do not implement a credential store. Preflight identity/version availability on both registries before any write; races remain possible and must yield partial results.

Publish Mooncakes first, then npm. The npm write uses the verified `.tgz` with lifecycle scripts disabled. A prerelease requires an explicit npm tag. Do not automatically repair tags or unpublish on failure. There is no transaction spanning the two registries.

Record each operation atomically with source/archive or tarball digests. A successful Mooncakes response plus a matching local receipt and registry existence permits skipping that step on a rerun. Without a receipt or independently verified content equality, an existing Mooncakes version is a conflict or uncertain outcome. The existing zig-cross script's duplicate-text shortcut is not copied into this tool.

For npm, compare registry `dist.integrity` to the exact tarball and check the requested tag. A matching artifact can reconcile a lost upload response. A tag pointing elsewhere is a reported conflict, not silent success. Preserve completed steps on failure and show a same-bundle rerun command. If a crash loses the Mooncakes success receipt, stop for external reconciliation rather than guessing.

Use bounded transient retry delays consistent with the existing publisher, but reconcile possibly accepted uploads before retrying them. Permanent authentication, permission, package, and content-conflict errors never retry. JSON and human reports contain `pending`, `published`, `already-published`, `failed`, or `uncertain` outcomes and actionable explanations; redact credential-bearing diagnostics.

### 8. Focused repository and release integration

Add the new CLI and consumer fixture to `moon.work` and version checks. Register only the CLI in the public publish/release lists. Extend release CLI verification to check the published pubman version/help; publish the tool itself only to Mooncakes and keep the fixture unpublished.

Add one focused `test:pubman` MoonBit task under the existing consumer category, run on Linux and macOS. It owns one local pack plus installed Node/browser/TypeScript checks and fake-registry scenarios. Keep existing backend and zig-cross tests intact. Release validation requires this task for the same candidate/toolchain before the new CLI is published. Release PR path selection must include the new CLI, fixture, task, and pinned test tools.

Build the fixture once per host in this task and reuse its exact bundle across verification and dry-run publication. Do not rebuild for every test harness. Do not add a full browser or compiler matrix. Required fixture checks must not become acceptable skipped work in the existing aggregate gate. No live consumer-library publication is part of CI.

Execution assessment, following build-master:

| Decision | Risk / deadline / owner | Evidence and confidence |
| --- | --- | --- |
| Add checks to existing consumer category | Broken npm artifacts or types; detect before merge and release; tool maintainer owns failures | Existing CI category inspected; high confidence in placement, runtime estimate unmeasured |
| Reuse verified bundle in publish | Publishing different bytes; block every publication; CLI owns receipt validation | npm accepts tarballs; Moon requires isolated source staging; medium confidence until fixture contracts pass |
| Avoid registry writes in CI | Accidental package release; block CI writes; maintainer owns credentialed release execution | Existing release uses separate privileged steps; high confidence in boundary |

Weighted assessment of feedback speed and execution efficiency remains unknown until the focused task is measured, so no total score or time-saving claim is assigned. Compare expanding every backend job with the selected single consumer task during implementation; both need the same artifact checks, while the selected task avoids repeated packaging.

## Risks / Trade-offs

- Compiler output and manifest changes can invalidate assumptions. Support the pinned compiler first and fail clearly for unsupported contracts; fixture the actual archive and emitted declaration layout.
- Declaration correctness exceeds file presence. Require strict consumer examples and paired runtime behavior checks; document their coverage limit.
- Browser feature support differs. Verify pinned Chromium and provide explicit runtime errors and asset overrides, without claiming every engine works.
- Local dependencies may build successfully but be unavailable to Mooncakes consumers. Reject unreleased path dependencies in v1 and build from an isolated source snapshot.
- Registry writes cannot be atomic. Persist per-registry outcomes, reconcile npm integrity, and require external reconciliation for unprovable Mooncakes duplicates.
- A minimal v1 requires author setup. Document a complete small fixture before adding adapter generation or scaffolding commands.

## Migration Plan

1. Implement and qualify the new CLI against the pinned toolchain and local fixture without registry writes.
2. Register its own Mooncakes release alongside zig-cross under the repository's shared version, preserving the fixture as unpublished.
3. Use a real library as a follow-up adoption change with explicit configuration, adapters, `.d.ts`, and consumer checks. Review `plan`, `pack`, `verify`, and dry-run outputs before any requested live publication.
4. Roll back adoption by removing that library's configuration and invocation. Published registry versions remain immutable; correct published defects with a new version. Repository rollout does not require converting zig-cross to this tool.
