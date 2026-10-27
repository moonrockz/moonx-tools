# Tasks

## 1. Establish pinned-toolchain contracts and CLI structure

- [x] 1.1 Add `apps/pubman` as a `native+wasm` CLI, import `moonbitlang/core/argparse` from the pinned standard library, and register workspace/shared version metadata; verify local version/help on both supported CLI backends and run `mise run validate`.
- [x] 1.2 Add the unpublished `fixtures/pubman-consumer` library with a shared core and JS/Wasm-GC export packages; verify MoonBit library imports/tests and focused release builds on the pinned compiler, with backend restrictions that preserve existing workspace checks.
- [x] 1.3 Capture pinned `moon package` archive contents, isolated module build output paths, emitted JS declaration dependencies, and Wasm-GC string options as fixture contracts; verify extraction/repackaging preserves the source file inventory and that isolated builds cannot use workspace sibling overrides.
- [x] 1.4 Declare the command tree, options, generated help, global `--json`, and `--dry-run` on every mutating command with `argparse`, mapping matches to typed requests without a custom argv parser; verify pubman-specific required inputs, unknown flags, help/version, exit codes, `--json` placement, and combined dry-run/JSON options on both supported CLI backends.
- [x] 1.5 Implement and document the shared versioned JSON envelope and human formatter; verify all four commands emit exactly one parseable JSON document for accepted success/failure invocations, preserve partial results and exit codes, isolate noisy subprocess logs on stderr, and leave stdout empty on argparse syntax errors.
- [x] 1.6 Introduce shared operation descriptions and a preview-only execution policy for all mutating commands; verify an enumerated command-contract test fails when any mutating command lacks `--dry-run`, and fake filesystem/process/registry adapters reject all mutation attempts during previews.

## 2. Implement configuration and read-only planning

- [x] 2.1 Define the versioned `pubman.json` format and manifest metadata reader; verify module selection, scalar string/comment handling, metadata/version conflicts, private-module rejection, prerelease syntax, unsupported fields/targets, and missing inputs with focused tests.
- [x] 2.2 Validate canonical source/destination paths, symlink containment, output ownership, and package destination collisions; verify traversal, source-overlap, and unrelated-directory deletion attempts fail before build/copy operations.
- [x] 2.3 Implement `plan` with resolved tool requirements, artifact/declaration sources, entry points, version, output, and consumer checks; verify fake process/filesystem observations show no builds, registry access, or writes and a consumer can extract planned values from the shared JSON envelope in a pipeline.
- [x] 2.4 Document the configuration using the consumer fixture, including compiler versus author declaration sources and supported hosts; verify the documented plan resolves correctly from a workspace root and from outside the fixture directory.

## 3. Pack JavaScript, Wasm-GC, and TypeScript artifacts

- [x] 3.1 Capture the Mooncakes source archive and declared extra inputs, reject local path dependencies, resolve registry dependencies, and build both configured export packages from fresh isolated snapshot directories; verify build failures cannot reuse stale output or replace an earlier successful bundle, and `pack --dry-run` previews the operations/output without directories, tool calls, downloads, or artifacts.
- [x] 3.2 Add the author-defined ESM wrappers and required `.d.ts` fixture declarations, including an initialization API for Wasm; verify the root wrapper loads compiled JS without touching the Wasm asset and both APIs perform concrete string/numeric/error operations.
- [x] 3.3 Generate the generic Wasm loader with Node file loading, browser fetching, bytes/URL overrides, host imports, and string compile options; verify packaged-relative loading, non-ASCII strings, missing assets/imports, and unsupported-runtime diagnostics using focused Node/browser checks.
- [x] 3.4 Assemble npm metadata and both typed `exports`, preserve required JS/declaration dependencies, and enforce explicit asset inventory; verify a missing Wasm declaration, missing `moonbit.d.ts`, escaping local reference, and output collision each fail with a specific diagnostic.
- [x] 3.5 Create the npm tarball with lifecycle scripts disabled and persist the source archive, inputs, checks, inventory, tool/dependency versions, and digests as a release bundle; verify tarball contents and prove no install-time MoonBit build or accidental credential/source-file inclusion.
- [x] 3.6 Document wrapper import locations, declarations, asset overrides, bundle files, and `pack` usage in the tool README; verify every documented packaging example against the fixture.

## 4. Verify installed consumers and bind the evidence

- [x] 4.1 Pin TypeScript and browser verification tooling, and implement isolated npm tarball installation without lifecycle scripts or source aliases; verify consumer checks still work when the original build/source tree is unavailable.
- [x] 4.2 Implement strict TypeScript checks for both public entries under NodeNext and bundler resolution, with library checking enabled; verify valid calls compile, invalid calls trigger expected errors, and deliberately weakened `any` parameters or unresolved declaration imports fail.
- [x] 4.3 Execute author Node/browser contract checks against installed package files and capture failures per entry; verify meaningful JS/Wasm operations, asynchronous Wasm initialization, asset relocation/overrides, and runtime/declaration disagreement cases.
- [x] 4.4 Persist verification evidence bound to artifact/config/check bytes and tool identities; verify missing, failed, tampered, or stale evidence blocks publish, successful checks produce a reusable receipt without rebuilding, and `verify --dry-run` previews checks without installing consumers, running author code, or creating/updating receipts.
- [x] 4.5 Document verification prerequisites and its limits, including author responsibilities for `.d.ts` accuracy and runtime contracts; verify a clean configured environment can run the documented `verify` command.

## 5. Publish to both registries and recover conservatively

- [x] 5.1 Add injectable process/registry adapters for non-writing identity/auth/version queries and explicit public registry destinations; verify absent credentials, incompatible names/versions, existing-content conflicts, inherited registry overrides, and missing prerelease tags stop before any registry write.
- [x] 5.2 Implement immutable-bundle publication with exclusive locking, Mooncakes source extraction/inventory checks, and exact npm tarball upload with lifecycle scripts disabled; verify captured argv/cwd and hashes show no rebuild or mutable-checkout publication.
- [x] 5.3 Implement credential-free, read-only `publish --dry-run`; verify it previews both registries and outstanding prerequisites without local verification, source extraction, staging/lock/receipt writes, registry/authentication calls, login, publication, or tag/configuration changes, and reports `dryRun: true` with unexecuted checks marked `not-run` under `--json`.
- [x] 5.4 Persist per-registry publication receipts atomically and implement same-bundle resume; verify Mooncakes success/npm failure, confirmed reruns, npm integrity reconciliation, tag mismatch, lost responses, missing Mooncakes receipts, and concurrent bundle publication.
- [x] 5.5 Add bounded transient retries, permanent-failure classification, recovery reports using the shared JSON/human report model, and diagnostic redaction; verify retry counts, ambiguous-upload reconciliation before retries, stable error codes, per-registry partial results, nonzero exit status, and no token disclosure with fake responses.
- [x] 5.6 Document credentials delegated to the installed CLIs, publication order, preserved bundle/receipt requirements, and uncertain-outcome recovery; verify examples against fake-registry success/partial/failure transcripts without a live publication.

## 6. Integrate repository assurance and tool release

- [x] 6.1 Add `scripts/test-pubman.mbtx` with pinned imports and a `test:pubman` mise task that builds one fixture bundle per host and reuses it across real installed Node/browser/type verification and dry-run tests for every mutating command; verify previews leave no changed/new/deleted local files or receipts, make no registry calls, and cannot substitute for actual verification, then measure task runtime without production credentials.
- [x] 6.2 Place the focused task in existing Linux/macOS consumer CI and same-candidate release validation, pin required test tools, and extend release path selection; verify workflow lint and failure propagation, including that skipped/missing required packaging checks cannot yield a green aggregate result.
- [x] 6.3 Register only the new CLI in matching publish/release lists and extend published CLI version/help verification while keeping both fixtures unpublished; verify release/script tests and dry-run planning preserve zig-cross behavior and the shared-version invariant.
- [x] 6.4 Update root/tool/fixture documentation for the new CLI and verified compatibility scope; verify all local non-publishing examples, and record actual focused-task timing without claiming unmeasured CI savings.
- [x] 6.5 Run `mise run format`, `mise run lint`, `mise run validate`, `mise run check`, `mise run test:scripts`, `mise run test:consumer`, `mise run test:pubman`, and `openspec validate --all --strict`; verify all required checks pass and no credentials, build outputs, or fixture package releases are staged.

## Workflow follow-up

- Review and archive the completed change through the OpenSpec archive workflow after implementation verification.
- Adopt the tool in a real library through a separate change; live publication requires that library's explicit release instruction and prepared artifact review.
