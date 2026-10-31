## 1. Reproduce

- [x] 1.1 Install MoonBit 0.10.18+6c83a7f62 in a temporary `MOON_HOME`; cross-build `apps/zig-cross` for linux-x64 and darwin-arm64 with zig-cross 0.3.1; verify `NAME_MAX` and `sys/vnode.h` errors in the runtime and the async stubs

## 2. Header fix

- [x] 2.1 Add tests for `header_flags`, the scoped wrapper line, the 0.10.18 assessment, the unverified notice and the vnode shim values (compiled with Zig for both macOS triples)
- [x] 2.2 Add `headers.mbt` (shim, source patterns, wrapper line), scope the flags in `cc_wrapper`, write the shim in `prepare`, and add 0.10.18 to `assessed_toolchains`; verify with `moon test apps/zig-cross --target native` and `--target wasm`

## 3. End-to-end checks

- [x] 3.1 With MoonBit 0.10.18, cross-build `apps/zig-cross` and `fixtures/consumer` for linux-x64, linux-arm64, darwin-arm64 and darwin-x64; run the darwin-arm64 binaries on the macOS host
- [x] 3.2 Add the full-runtime step to `scripts/test-consumer.mbtx` and the `cross-moonbit-0-10-18` CI job; run `mise run test:consumer`

## 4. Checks

- [x] 4.1 Run `mise run format`, `mise run lint`, `mise run validate` and `openspec validate --all --strict`; verify that all pass
- [x] 4.2 Run `mise run test`; verify that all tests pass
