# Proposal

## Why

MoonBit libraries can serve MoonBit and JavaScript consumers, but each author currently has to assemble npm artifacts, TypeScript declarations, runtime wrappers, and a release process. We want a reusable tool that packages one library for Mooncakes and npm while keeping authors in control of the JavaScript API.

## What Changes

- Add `moonrockz/pubman`, a MoonBit CLI under `apps/pubman`, distributed through `moonx` and sharing this repository's version.
- Provide `plan`, `pack`, `verify`, and `publish` commands for one explicitly selected library module per invocation, including modules inside workspaces.
- Use `moonbitlang/core/argparse` for subcommands, flags, validation, and generated help. Do not implement a custom command-line parser.
- Include a global `--json` flag on every command from the first release, with a versioned result/error format, machine-readable stdout, and progress/subprocess logs on stderr for automation and piping.
- Require `--dry-run` on every mutating command, including `pack`, `verify`, and `publish`. Dry runs preview actions using local reads only, compose with `--json`, and do not create artifacts, execute consumer checks, write receipts, or contact registries.
- Build generated JavaScript and Wasm-GC from author-defined export packages. Produce one npm ESM package with a default JavaScript entry point and an explicit `/wasm` entry point.
- Require usable TypeScript `.d.ts` declarations for both entry points. Accept author-supplied declarations or compiler output that matches the public wrappers, include their referenced declaration files, and check installed TypeScript consumers.
- Generate npm metadata from explicit configuration and the selected module's metadata. Use the MoonBit module version for both registries.
- Package and verify before publication, then publish the exact verified npm tarball and the corresponding Mooncakes source snapshot. Report each registry's outcome and support conservative recovery after partial publication.
- Add a small consumer library fixture, offline failure tests, packed-package runtime/type checks, and repository release registration for the new CLI.

The first version excludes plain Wasm, automatic adapter or general-purpose declaration generation, CommonJS, automatic Wasm fallback, multi-module release graphs, arbitrary build hooks, private registries, private packages, version bumping, changelog generation, and CI workflow generation. Library authors supply export adapters, wrappers, declaration sources, and consumer contract checks. The tool's own release remains Mooncakes-only. Existing zig-cross commands and publication semantics do not change.

## Capabilities

### New Capabilities

- `npm-distribution`: Configuration, builds, npm ESM layout, JavaScript and Wasm-GC entry points, TypeScript declarations, and verification of packed artifacts.
- `dual-registry-publication`: Shared release identity, publication preflight, exact-artifact publication, dry runs, per-registry results, and partial-publication recovery.

### Modified Capabilities

None. The repository currently has no main specifications.

## Impact

- New module `apps/pubman`, fixture `fixtures/pubman-consumer`, and focused task automation in `scripts/*.mbtx`.
- Register both modules in `moon.work`; extend the existing version checker, tool release lists, CLI verification, README, and mise tasks as needed.
- Reuse the pinned MoonBit and Node/npm toolchain, including standard-library `moonbitlang/core/argparse`. Pin TypeScript and browser test tooling for installed-package verification; use the existing MoonBit async process/filesystem packages with pinned imports.
- CI gains focused packaging assurance; production credentials and registry writes remain confined to explicit publication commands. Repository CI tests use local artifacts and fake registry/process responses.
- Consumer projects gain a versioned `pubman.json` configuration. Running the tool does not require adopting this repository's release scripts or mise setup.
