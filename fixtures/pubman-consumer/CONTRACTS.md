# Pinned compiler contracts

Measured with MoonBit `0.10.15+943464bfa`, moon `0.1.20261012` commit `748b63c`.

- `moon package --target-dir <dir>` produces
  `<dir>/publish/moonrockz-pubman-consumer-<version>.zip`. Entries are relative
  to the module, with no enclosing directory. The archive includes `moon.mod`,
  `moon.pkg`, shared library sources, adapter sources/manifests, README/license,
  configuration, wrappers and contract checks. `_build` is excluded. Pubman
  records the exact source file inventory and requires extraction/repackaging
  to preserve it. Extra declared inputs are captured independently.
- Workspace build paths include `moonrockz/pubman-consumer/`. Standalone builds
  from a source snapshot use `<target>/js/release/build/js/js.js` and
  `<target>/wasm-gc/release/build/wasm/wasm.wasm`. No module-name prefix exists
  in standalone output. The packer builds in temporary directories outside
  every workspace ancestor, with no `moon.work`, so sibling overrides cannot
  supply dependency sources.
- The JS compiler emits `js.d.ts` plus `moonbit.d.ts`. `js.d.ts` imports
  `./moonbit.d.ts`. Public aliases include `MoonBit.String` and `MoonBit.Int`.
  The `.d.ts` closure is copied beside `js/index.d.ts`, then checked by actual
  TypeScript consumers under both resolution modes.
- Wasm-GC with `use-js-builtin-string: true` accepts JS strings when
  instantiation passes `builtins: ["js-string"]` and
  `importedStringConstants: "_"`. Concrete Unicode calls pass on pinned Node
  24.14.1 and Playwright 1.64.1 Chromium revision 1248.
- The pinned `moon package` rejects nonzero major versions. Pubman preserves
  semver identity and reports that compiler/package validation failure rather
  than rewriting an author version.
- `moon publish` takes a source directory. Pubman extracts captured source,
  checks its file inventory and a ZIP round-trip, then invokes the installed
  CLI there. npm accepts the exact `.tgz` argument with lifecycle scripts disabled.

`test:pubman` exercises these contracts by packaging and installing the actual
artifacts. Missing declarations, declaration weakening and runtime disagreement
are tested against repacked variants without rebuilding the MoonBit library.
