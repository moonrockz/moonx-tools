## Why

`zig-cross doctor` 0.3.0 gives `zig-cross build linux-x64 -- fixtures/consumer` as the `ZC_TOOLCHAIN_UNVERIFIED` validation command ([#9](https://github.com/moonrockz/moonx-tools/issues/9)). That path exists only in moonx-tools, and the target is `linux-x64` even when doctor assessed other targets. An agent that runs the command as given builds the wrong target from a path that does not exist. Also, the finding severity `unverified` is in the JSON report but not in the README, which lists only the statuses.

## What Changes

- The `ZC_TOOLCHAIN_UNVERIFIED` command builds the targets of the finding from the documented `<package-path>` placeholder, for example `zig-cross build darwin-arm64 darwin-x64 windows-x64 -- <package-path>`.
- Its prerequisites tell the reader to replace the placeholder and to use the full runtime. They do not refer to the moonx-tools fixture.
- The README and the spec list the finding severities `error`, `warning` and `unverified`, and how each one sets the report status. The JSON values do not change.

Out of scope: other findings, the JSON schema version, build and exec behavior, and pubman. Documentation in moonrockz/moon-lander changes after the next zig-cross release.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `zig-cross-compatibility-guidance`: the unverified-toolchain scenario requires a command for the assessed targets with the `<package-path>` placeholder, and the structured report requirement lists the finding severities and their status mapping.

## Impact

- `apps/zig-cross/doctor.mbt` (next step of `ZC_TOOLCHAIN_UNVERIFIED`) and `apps/zig-cross/doctor_wbtest.mbt`.
- `apps/zig-cross/README.md` (severity list).
- JSON consumers: only the text of one `command` and its `prerequisites` changes. Fields, codes, severities and statuses stay the same in schema version 1.
