# Tasks

## 1. Environment assessment and guidance definitions

- [x] 1.1 Add bounded environment probes for host, Moon/compiler versions, Zig, and relevant runtime layout; verify parsing against observed tool output and missing, malformed, and timed-out tool cases without launching project builds.
- [x] 1.2 Add a pure assessment model with stable finding codes, severity, targets, applicability, evidence, and actionable next steps; verify target-specific findings for assessed 0.10.15/0.10.17 toolchains and conservative unknown/custom-toolchain handling.
- [x] 1.3 Add text and schema-version-1 JSON renderers with deterministic ordering and status/exit mapping; verify JSON round trips, additive field compatibility, usage errors, and absence of terminal decoration or subprocess output.
- [x] 1.4 Document assessed environments, supported versus experimental remedies, SDK prerequisites, and the Windows platform/core limit in the app README; check every suggested command exists and each remedy states its applicability.

## 2. Discoverable diagnostic command

- [x] 2.1 Extend CLI parsing and dispatch for `doctor [<target>...] [--json]`, including default targets and duplicate handling; verify accepted forms, invalid targets/options/separators, and structured usage failures with focused CLI tests.
- [x] 2.2 Run the shared assessment without generating wrappers or building a project; verify human and JSON output from outside a project and confirm diagnostic exit statuses 0, 1, and 2 using controlled tool fixtures.
- [x] 2.3 Extend help and root/app usage examples with doctor, agent JSON consumption, and the Windows warning; verify `--help` stays usable without probing Moon or Zig.

## 3. Guidance in existing commands

- [x] 3.1 Reuse one assessment per build/exec invocation and emit relevant notices to stderr before child launch; verify deduplication, preservation of raw compiler output, and the existing stdout/stdin and child exit contracts.
- [x] 3.2 Add target-specific doctor hints after failed builds while retaining aggregate failure behavior and header checks; verify a failed fake compiler retains its diagnostics and a structurally successful Windows result still emits the semantic warning.
- [x] 3.3 Implement explicit version/fingerprint-bounded sync runtime isolation and feed actual selection to the shared model; verify exclusions, refusal for unknown/custom versions, cleanup, and no installed toolchain mutation.
- [x] 3.4 Document the stderr notices and failure recovery examples; verify the documented doctor invocation accepts the same target as the failed build.

## 4. Integration and upgrade acceptance

- [x] 4.1 Add focused CLI integration verification using MoonBit task automation with pinned imports if a runner is needed; verify clean JSON stdout, no diagnostic wrapper generation, missing tools, build-failure hints, and exec stream/exit preservation on Linux and macOS.
- [x] 4.2 Run zig-cross unit tests for its Wasm and native backends, `mise run test:native-zig`, and `mise run test:consumer` on the existing pin and upgraded candidate; record all five sync cross-target header checks, host execution, runtime/dependency coverage and expected excluded-API failure.
- [x] 4.3 Run `mise run format`, `mise run lint`, `mise run validate`, and `openspec validate --all --strict`; verify the diff covers the expanded upgrade and guidance scope.

## 5. Repository upgrade and delivery

- [x] 5.1 Verify latest stable in isolation, update all version pins/URLs and toolchain documentation, migrate script imports, and resolve repository-wide compiler fallout.
- [x] 5.2 Run full check, script tests, pubman Node/browser/TypeScript consumers and previews, plus doctor integration on Linux/macOS through existing CI/release gates. Exercise emitted next steps and record material limits.

## Workflow follow-up

- The implementation and release must verify actual mode selection and emitted remedies before completion.
- Archive this guidance change only after implementation and review.

Production delivery is tracked by the persistent native goal beyond this implementation checklist: land current-head CI, prepare/merge the normal release PR, verify both registry modules and installed help/doctor/build/exec, the production workflow, GitHub release and release:status agreement. Archiving implementation does not complete that goal.
