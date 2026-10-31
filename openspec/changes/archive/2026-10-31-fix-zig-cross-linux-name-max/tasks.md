## 1. Fix

- [x] 1.1 Change the white-box tests to expect `-DNAME_MAX=255` for linux-x64, linux-arm64 and `host` on Linux
- [x] 1.2 Change `header_flags` to give `-DNAME_MAX=255` for Linux targets, and change the doctor messages, the header comments and the README
- [x] 1.3 Compile every MoonBit 0.10.18 runtime C file and every moonbitlang/async 0.22.7 C stub with Zig 0.17.0 for x86_64/aarch64 linux-gnu and linux-musl with the new flag

## 2. Verification

- [x] 2.1 Run `mise run format`, `mise run lint`, `mise run validate` and `mise run check`
- [x] 2.2 Run `mise run test:native-zig` and `mise run test:consumer`
- [x] 2.3 CI `Test native (zig)` on Linux passes (glibc host with moonbitlang/async 0.22.7)
