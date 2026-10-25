# pubman

`moonrockz/pubman` packages one MoonBit library source release for Mooncakes and
one npm ESM package. The npm root runs generated JS. `/wasm` exposes the author's
asynchronous Wasm-GC API. Both public entries require TypeScript declarations.
Pubman itself is a Mooncakes CLI, with Linux/macOS hosts and native/Wasm CLI backends.

## Run locally

From this repository root:

```sh
moon run apps/pubman --target native -- plan --config fixtures/pubman-consumer/pubman.json --json
moon run apps/pubman --target native -- pack --config fixtures/pubman-consumer/pubman.json --dry-run --json
moon run apps/pubman --target native -- pack --config fixtures/pubman-consumer/pubman.json
moon run apps/pubman --target native -- verify --bundle fixtures/pubman-consumer/_build/pubman/release
moon run apps/pubman --target native -- publish --bundle fixtures/pubman-consumer/_build/pubman/release --dry-run --json
```

After the CLI is released, replace `moon run apps/pubman --target native --` with
`moonx moonrockz/pubman`. `--help` and `--version` need no project configuration.
`--json` works before or after each command. Use absolute `--config` or `--bundle`
paths when invoking from another directory. Config paths resolve from the file's
directory, regardless of the caller's working directory.

`plan` and every `--dry-run` use local reads only. Previews never build, download
dependencies, install consumers, run author code, create directories or locks,
write receipts, inspect credentials, or contact registries. They report operations
in execution order, outstanding prerequisites, `dryRun: true`, and `not-run`
checks. A preview cannot qualify a release. Missing or invalid local inputs still
fail. Tool availability and registry state remain untested in a preview.

## Configuration

See the complete [fixture configuration](../../fixtures/pubman-consumer/pubman.json).
Only schema version 1 and the following fields are accepted:

| Field | Meaning |
| --- | --- |
| `schemaVersion` | Required, `1`. |
| `module` | Module directory relative to this config. Defaults to `.` outside ambiguous workspace roots. |
| `npm.name`, `npm.access` | Explicit npm identity and required `"public"` access. No automatic scope inference. |
| `npm.version` | Optional assertion equal to the library's `moon.mod` version. |
| `npm.description` | Optional description override. |
| `npm.dependencies` | Optional map of public npm names to exact semver strings. |
| `npm.tag` | Optional distribution tag, required for prereleases. Stable versions default to `latest`. |
| `entries.js`, `entries.wasm` | Required export package, wrapper and declaration sources. |
| `assets` | Required array of `{ "source": "relative/file", "destination": "package/file" }`. |
| `checks` | Required nonempty `node`, `browser`, and `types` arrays of module-relative check files. |
| `output` | Tool-owned bundle path relative to config, default `_build/pubman/release`. |

Each entry has `package`, `wrapper`, and `declaration`. Optional `target` must be
`js` for the JS entry and `wasm-gc` for the Wasm entry. Optional Wasm `loader`
accepts `builtins: ["js-string"]` and `importedStringConstants: "_"`, matching
the author export package's string options. No other targets or loader fields
are supported. All wrappers, assets, packages and checks must resolve within the
selected module, including through symlinks. Source directory symlinks are rejected.
Destinations must be unique and contained in the npm package. `internal/` is reserved.
An output directory must be new or marked as pubman's own bundle. It must not
contain input files or overlap a source directory. Module-local output belongs
under `_build/`.

A declaration can be an author `.d.ts` path, such as `bindings/wasm.d.ts`, or a
compiler reference:

```json
{ "backend": "js", "path": "js/js.d.ts" }
```

Compiler paths are relative to the isolated target's `js/release/build/` or
`wasm-gc/release/build/`, not the workspace build directory. They need not exist
during planning. The compiler's JS declaration imports `moonbit.d.ts`; pubman
preserves it alongside the public declaration. Author declaration dependencies
must have explicit `assets` mappings preserving relative references. Missing or
escaping local imports fail packing. External declaration imports must name
`npm.dependencies`. TypeScript verifies full declaration resolution after installation.
Pubman never invents `any` declarations or generates adapters.

Pubman reads scalar `name`, `version`, `description`, `license`, `repository`,
`readme`, and `private` from current `moon.mod` syntax. Quoted strings support
escapes and comments. Unsupported metadata expressions, private modules, conflicting
versions and local path dependencies fail. Legacy JSON manifests are unsupported.
The selected library's version determines both registry versions; the tool's own
version is provenance only. Release versions with build metadata are rejected
because npm removes it and would change the shared registry identity. This
repository keeps all module versions equal to its root `moon.mod` through
`scripts/versions.mbtx`.

## Wrappers and package files

Authors own the MoonBit export adapters and JS API. Use `pkgtype(kind:
"foreign_library")` and explicit exports in the export packages. The JS wrapper
imports `../internal/js/library.js`; the Wasm wrapper imports
`../internal/wasm/loader.mjs`. The fixture shows synchronous JS exports and an
`initialize()` promise returning the Wasm API. Declarations must describe these
public wrappers, not merely the compiler's raw exports.

The package contains `package.json`, `js/index.mjs`, `js/index.d.ts`,
`wasm/index.mjs`, `wasm/index.d.ts`, generated files under `internal/js/`,
`internal/wasm/library.wasm`, `internal/wasm/loader.mjs`, required compiler
declarations and explicit assets. Include README and license through `assets`.
`exports["."]` and `exports["./wasm"]` each put `types` before `import`.
There are no CommonJS entries, automatic fallback, lifecycle scripts, or
install-time MoonBit compilation. Root import does not load Wasm.

The generated loader exports `instantiate(options)`. Options accept `bytes`
with a BufferSource, `url` with a URL/string, and `imports` with a WebAssembly
imports object. By default it resolves the Wasm binary relative to itself.
Node file URLs use `node:fs/promises`; browser/network URLs use `fetch`. Bytes
avoid HTTP MIME requirements. Initialization forwards configured string compile
options. The author wrapper converts raw exports to its API; the loader does
no general MoonBit value marshalling. Failures identify the asset and required
runtime features. Bundlers/CDNs should provide bytes or a relocated URL.

`pack` first captures `moon package`'s source ZIP, then captures declared extra
inputs and checks. Both backend builds use fresh standalone snapshots outside
the workspace and fresh target directories. Dependencies resolve from registry
metadata, without sibling workspace overrides. Source extraction and repackaging
must preserve the file inventory. npm packing uses `--ignore-scripts`, and its
inventory must match the assembled package. Failed builds preserve the previous
good bundle. Pack and publication/verification locks prevent concurrent replacement.

A bundle contains:

- `.pubman-owned` and `bundle.json`, with shared identity, npm integrity and SHA-256 payload inventory.
- `payload/source.zip`, `payload/package.tgz`, and their source/npm inventories.
- `payload/config.json`, captured `payload/inputs/`, tool identities and resolved dependency trees.
- `verification.json` after verification, and `publication-moon.json` / `publication-npm.json` after publication attempts.

Keep the entire bundle, including receipts. Digests cover bytes, not timestamps.
Receipts use atomic file replacement. A stale `.operation-lock`, `.pack-lock`, or
`.new` file after a crashed process requires inspection before manual removal.
Never remove a lock while another command is active.

## Verification

Install `moon`, Node/npm, `tsc`, `playwright`, Chromium, `unzip`, `zip` and `tar`
before using the complete lifecycle. Repository mise pins Node 24.14.1, npm
11.11.0 through Node, TypeScript 5.9.3 and Playwright 1.58.2, with Chromium
145.0.7632.6 revision 1208. Install Chromium explicitly:

```sh
mise install
mise exec -- playwright install --with-deps chromium
mise run test:pubman
```

Verification never silently installs developer tools or browsers. It installs the
exact tarball outside the checkout with npm lifecycle scripts disabled. Node
checks are executable ESM files importing the installed public package names.
Browser checks are ESM files served with an import map for both entries and
executed in pinned Chromium. A thrown error fails verification. TypeScript files
exercise both entries, valid calls and `@ts-expect-error` negative calls. Checks
run under strict NodeNext and bundler resolution with `skipLibCheck: false` and
no source aliases. Keep their dependencies within the captured files/package.

The fixture exercises numeric operations, Unicode strings, the division-by-zero
sentinel, asynchronous initialization, default/relocated assets and host imports.
Tests also weaken declarations to `any`, remove declaration dependencies, and
introduce runtime/declaration disagreement; each must fail. TypeScript cannot
prove arbitrary runtime equivalence. Authors remain responsible for accurate
`.d.ts` files and contract coverage. Only pinned Node and Chromium are certified;
Bun, Deno, other browsers, Windows hosts, and bundler asset transforms are outside
this release's evidence.

Successful verification binds artifact/config/check bytes, the CLI executable's
hash, verification implementation and installed tool identities. Publish needs
that successful receipt and the same CLI artifact/tools. Changing any bound
input requires verification again. Verification failures record failed checks
and never authorize publication. Receipts are local release bookkeeping for
trusted local bundles, not attestations for untrusted downloads.

## Publication and recovery

Actual publication is an explicit operation:

```text
pubman publish --bundle /absolute/path/to/verified/bundle --json
```

This command writes to both public registries. The repository fixture and CI
never run it against live registries. Authentication belongs to the installed
CLIs: `moon login` or CI Moon credentials, and npm login/token/OIDC setup.
Pubman does not store credentials. For OIDC, actual publication delegates a
non-uploading preflight to pinned npm with lifecycle scripts disabled, and
requires npm's successful token-exchange diagnostic. A dry-run warning about
missing credentials never counts as authentication. Pubman previews never run
this preflight. Moon's saved username must match the module
owner. Public registry configuration, both authentication identities, version
availability, npm integrity and tag selection are checked before the first upload.
Inherited private registry overrides are rejected. All npm uploads specify the
public registry, public access and `--ignore-scripts`.

Mooncakes publishes first, from a fresh extraction of the captured source ZIP.
Inventory checks repackage it without invoking a build. npm uploads the exact
verified tarball. Neither step republishes the mutable checkout. The registry
CLIs still perform their own validation. Each confirmed operation gets its own
receipt. Both must be confirmed for exit 0.

A Mooncakes success followed by npm refusal produces a nonzero partial report:
`registries.moon.status` is `published`, `registries.npm.status` is `failed`.
Correct the npm problem and rerun the same bundle. Mooncakes is skipped only
when the matching successful receipt and registry existence agree. An existing
Mooncakes version without that receipt is uncertain and requires external
reconciliation. A lost Mooncakes upload response is never accepted merely
because the version now exists.

npm reconciliation compares exact `dist.integrity` and the requested tag. A
matching artifact/tag can confirm a lost response without another upload. A
conflicting tag or integrity stops the run; pubman never repairs tags, unpublishes,
or replaces versions. Transient read queries and safe/reconciled uploads have
at most four attempts. Authentication, permission and content failures stop
immediately. Unprovable upload outcomes remain `uncertain`. Preserve every file
and follow the recovery instruction in the report.

## Report contract

Accepted `--json` invocations emit one JSON document and a newline on stdout:

```json
{"schemaVersion":1,"command":"pack","ok":false,"data":{},"error":{"code":"INVALID_INPUT","message":"missing wasm declaration","details":{}}}
```

`error` is null on success. Errors always have a stable string `code`, string
`message`, and object `details`. `data` is an object; partial failures retain
completed results. `plan` reports module/npm identities, version, entry and
asset mappings, checks, output and required tools. Pack reports `bundle` and
`identity`; verify reports `bundle` and `verification` with ordered checks;
publish reports `bundle`, per-registry outcomes and `recovery`. Preview reports
include `dryRun`, ordered `operations`, `prerequisites`, and `not-run` checks.
`localVerification` is null when absent; its presence alone does not qualify a
preview. Registry statuses are `pending`, `published`, `already-published`,
`failed` or `uncertain`. Operation/check arrays retain execution order; JSON
object property order has no consumer guarantee. Additive fields are allowed in
schema 1. Incompatible changes require a new schema version.

Exit 0 means the requested operation or local preview succeeded, 2 means invalid
invocation/configuration, and 1 means I/O/build/verification/publication failure.
Argparse syntax errors are the exception to JSON output: contextual diagnostics
go to stderr, stdout remains empty, and exit is 2. Help/version use argparse's
normal informational output. All progress and subprocess logs go to stderr.
Human mode formats the same report data.

Stable errors include `INVALID_INPUT`, `IO_ERROR`, `MISSING_TOOL`,
`SUBPROCESS_FAILED`, `OUTPUT_CHANGED`, `NPM_PREFLIGHT`, `ARTIFACT_LAYOUT`, `SOURCE_INVENTORY`, `NPM_INVENTORY`,
`INSTALLED_INVENTORY`, `BUNDLE_TAMPERED`, `STALE_EVIDENCE`, `VERIFICATION_FAILED`,
`VERIFICATION_REQUIRED`, `REGISTRY_CONFIG`, `REGISTRY_QUERY`, `REGISTRY_IDENTITY`,
`REGISTRY_CONFLICT`, `AUTH_REQUIRED`, `CONTENT_CONFLICT`, `TAG_CONFLICT`,
`STALE_PUBLICATION`, `MOONCAKES_UNCERTAIN`, `PUBLICATION_FAILED`, and
`PUBLICATION_UNCERTAIN`. Diagnostics redact environment-provided credential
values and common token patterns.
