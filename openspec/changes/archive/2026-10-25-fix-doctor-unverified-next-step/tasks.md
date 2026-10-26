## 1. Unverified validation command

- [x] 1.1 Add a doctor test for an unassessed toolchain with targets darwin-arm64, darwin-x64 and windows-x64 that expects `zig-cross build darwin-arm64 darwin-x64 windows-x64 -- <package-path>` and severity `unverified`; verify it fails before the fix
- [x] 1.2 Build the `ZC_TOOLCHAIN_UNVERIFIED` command from the finding targets and `<package-path>`, with prerequisites that do not name the moonx-tools fixture; verify with `moon test -p moonrockz/zig-cross` and with `moon run apps/zig-cross --target wasm -- doctor darwin-arm64 darwin-x64 windows-x64 --json` under `MOON_CORE_OVERRIDE`

## 2. Severity documentation

- [x] 2.1 List the finding severities and their status mapping in `apps/zig-cross/README.md`; verify the list matches the severities that `report` emits

## 3. Checks

- [x] 3.1 Run `mise run format`, `mise run lint`, `mise run validate` and `openspec validate --all --strict`; verify that all pass
- [x] 3.2 Run `mise run test`; verify that all tests pass

## Workflow follow-up

- Archive the change in this pull request after the checks pass.
