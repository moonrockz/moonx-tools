# Pubman consumer fixture

This unpublished `moonrockz/pubman-consumer` module supplies one shared library,
a JS export adapter, a Wasm-GC export adapter, author wrappers and consumer checks.
It shares the repository version but is absent from every publication list.
The npm name `@moonrockz/pubman-consumer` is a local test identity, never a release.

`greet` preserves Unicode, `add` adds two Int values, and `quotient` returns `-1`
for division by zero. The JS entry is synchronous. The Wasm entry exports
`initialize(options): Promise<API>`, with bytes/URL/import overrides. JS types
come from the compiler, including `moonbit.d.ts`. The Wasm initializer declaration
is author-written because the compiler exports alone do not describe it.

From the repository root:

```sh
moon test fixtures/pubman-consumer
moon build fixtures/pubman-consumer/js --target js --release
moon build fixtures/pubman-consumer/wasm --target wasm-gc --release
moon run apps/pubman --target native -- plan --config fixtures/pubman-consumer/pubman.json --json
mise exec -- playwright install --with-deps chromium
mise run test:pubman
```

The focused task builds one actual bundle, verifies the installed tarball with
the source moved away, then reuses it for previews and negative consumer variants.
It runs fake-registry recovery tests without production credentials. Node and
Chromium perform real string/numeric/error operations. Strict NodeNext and
bundler consumers include expected type errors for both entries.

Pinned compiler observations are in [CONTRACTS.md](CONTRACTS.md). See the
[tool README](../../apps/pubman/README.md) for configuration and recovery rules.
A macOS arm64 development run took 12.47 seconds wall time, 11.45 user and
3.94 system seconds, with warm compiler/dependency/browser caches. This is one
local measurement, not a Linux/CI estimate or a claim of CI time savings.
