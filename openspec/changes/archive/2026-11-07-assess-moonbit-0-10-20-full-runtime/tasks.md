## 1. Assessment

- [x] 1.1 With MoonBit 0.10.20+65efd5b93 and Zig 0.17.0, cross-build `fixtures/consumer` and `apps/zig-cross` with the full runtime for linux-x64, linux-arm64, darwin-arm64 and darwin-x64, and verify the `NAME_MAX` and `sys/vnode.h` uses in the runtime sources
- [x] 1.2 Add a white-box test for the 0.10.20 full-runtime assessment and its sync refusal, then add 0.10.20 to `assessed_toolchains` with the fingerprint that doctor computes

## 2. Verification

- [x] 2.1 Run `mise run lint`, `mise run validate`, `mise run test`, `mise run build` and `mise run test:native-zig`
- [x] 2.2 Run `mise run test:consumer` with `ZIG_CROSS_SYNC_MOON_HOME` set to a MoonBit 0.10.17 home, and `mise run test:pubman`
