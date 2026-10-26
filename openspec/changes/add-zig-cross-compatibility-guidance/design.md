# Design

## Context

See proposal.md for motivation and scope. `cli.mbt` parses only build, exec, help, and version. `main.mbt` writes wrappers in `prepare`, inherits child output, and reports only an exit code when Moon fails. The README describes Windows OsString limitations that help and build output omit.

Investigation on macOS arm64 with MoonBit 0.10.17+d971670cd and Zig 0.17.0 found new runtime source failures. Linux consumer builds succeed with limits.h injected; macOS builds succeed and run with SDK headers added. A six-file current-version runtime archive links the fixture for all five targets but has not passed general consumer validation. These findings do not establish a supported compatibility mode.

The executable supports Wasm and native backends and Linux/macOS hosts. A Wasm program must detect the host at runtime. Windows remains an output target, not a supported host.

## Goals / Non-Goals

Goals are a single source of compatibility guidance, stable agent-readable reports, and useful notices that preserve command behavior. Diagnosis must work outside a MoonBit project and without a build.

The expanded handoff authorizes runtime isolation and toolchain pins in this change. Patching installed sources and claiming Windows runtime correctness remain excluded. The compatibility evaluator receives actual `ZIG_CROSS_RUNTIME` selection.

## Decisions

### One assessment model, separate rendering

Add a small environment probe, pure compatibility assessment, and text/JSON renderers under `apps/zig-cross/`. Use existing async process facilities, env, and core JSON support rather than a new dependency. Record the host OS/architecture, zig-cross version, Moon build-tool and compiler versions, Zig version, selected targets, and active compatibility mode if one exists.

Use captured `moon version --all`, `zig version`, and runtime host probes with bounded execution times. Capture tool output so doctor JSON cannot contain their progress messages. Keep version parsing separate and test real observed formats and malformed output. Do not launch probes for help or version. Probe once per doctor/build/exec invocation, not per target. A doctor run does not invoke builds, generate wrappers, install tools, or edit toolchain sources.

Assessment accepts probe results and produces findings with `code`, `severity`, `targets`, `message`, `applicability`, `evidence`, and `next_steps`. Next steps distinguish executable commands from explanatory instructions and carry prerequisites. Source links identify upstream reports when available. Evidence reports what was observed or what a documented assessment covers; it must not claim a probe reproduced a compiler error when it did not.

README-only guidance was rejected because it does not reach an agent or user at the failing command. Independent strings in each command were rejected because they would drift.

### Conservative applicability

Create exact-version assessments for observed toolchains, including the pinned 0.10.15+943464bfa and investigated 0.10.17+d971670cd with Zig 0.17.0. Scope new-runtime findings to their relevant targets and the affected runtime layout. A known stock-toolchain assessment is labelled as such; if a custom runtime cannot be identified, report uncertainty rather than declaring its contents broken.

Initial finding codes include `ZC_WINDOWS_OSSTRING`, `ZC_LINUX_NAME_MAX`, `ZC_DARWIN_VNODE_HEADER`, `ZC_WINDOWS_MSVC_RUNTIME`, `ZC_TOOL_MISSING`, `ZC_TOOLCHAIN_UNVERIFIED`, and `ZC_COMPATIBILITY_MODE`. Their meaning remains stable even when explanatory wording changes.

Windows platform/core mismatch is a warning even when header verification succeeds. A stock runtime known to fail compilation is an error unless an implemented, validated workaround resolves that finding. Unknown versions yield an unverified finding and an existing validation command, not an inferred defect or an assurance of support. Mac SDK instructions state that they require accessible SDK headers; they are not advertised as a general Linux-host remedy. Restricted runtime selection remains experimental until implemented and tested; no nonexistent CLI flag is suggested.

Do not detect defects by treating an arbitrary downstream compiler message as a known error. Shared environment assessment supplies applicable context while raw compiler diagnostics remain available.

### Stable doctor interface

Accept `doctor [<target>...] [--json]`, with the JSON flag before or after target arguments. An empty target list selects the existing target list in its existing order. Remove duplicate targets while preserving their first occurrence. Reject unknown targets/options and argument separators with usage status 2.

Text output lists detected versions and each relevant finding with a concrete next step. JSON output is exactly one document with `schema_version: 1`, `environment`, `targets`, `status`, and `findings`. Status is `error` if any error exists, otherwise `warning` if any warning exists, otherwise `unknown` if any unverified finding exists, otherwise `ok`. Unknown and warning statuses exit 0, errors exit 1, and usage errors exit 2. A JSON usage error uses the same envelope with a stable `ZC_USAGE` finding and any unavailable environment fields set to null. Pre-scan doctor arguments for `--json` so malformed invocations keep structured stdout.

The schema permits additive fields; changing field types or meanings requires a new schema version. JSON never includes ANSI sequences, summary tables, or raw child output. Consumers inspect codes and statuses, not prose.

### Notices augment existing build and exec behavior

Reuse the assessment before `prepare` and before launching child commands. Emit each applicable warning/error or active-mode notice once per target to stderr, then retain existing command behavior. Full-runtime assessment is advisory and preserves the child result. Explicit sync selection with an ineligible version or fingerprint, and invalid runtime-mode values, fail before child execution. Doctor itself reports error status for known blockers.

After a build failure, add `zig-cross doctor <target>` as an executable next step alongside the existing failure summary. Preserve inherited stdout/stderr and do not capture or rewrite compiler logs. Preserve the existing mapping of child statuses in exec and the existing build aggregate exit status. Render active-mode notices from actual mode selection data; do not invent an active mode from version detection alone.

An automatic retry or automatic runtime mutation was rejected because this guidance change must not alter build semantics. General JSON build output is also out of scope; structured diagnosis supplies the agent interface.

## Risks / Trade-offs

- Known-version guidance can become stale. Keep applicability exact, identify evidence, and report uncertainty for unassessed or customized toolchains.
- Preflight probes add startup time. Probe only necessary tools once, bound execution time, and do not run builds during assessment.
- Added stderr notices are observable. Keep them short and relevant, deduplicate them, and preserve child streams and statuses.
- A matching executable header can be mistaken for runtime validation. Keep Windows semantics warnings visible after structurally successful builds.
- Basic fixtures do not prove restricted-runtime compatibility. Label the approach experimental and require real consumer verification before advertising a supported mode.

## Migration Plan

Deliver diagnostics, runtime selection and the pin upgrade in one coherent implementation PR. Test parsing, assessments, JSON, help, and stream/exit contracts on the existing pin and repeat relevant tests on the candidate compiler. Run integration checks on Linux and macOS with the Wasm CLI and native host execution. Target assessments cover both Linux architectures, both Darwin architectures, Windows x64, and host.

Use `ZIG_CROSS_RUNTIME=sync` only with exact compiler/build-tool versions and a SHA-256 fingerprint of the shipped runtime C sources. Copy the six current-version synchronous runtime units into a temporary toolchain view; symlink all other toolchain components to their matching installed originals. Point child Moon invocations at this view with `MOON_TOOLCHAIN_ROOT`, remove it after the child exits, and leave `MOON_HOME` and global installation untouched. Preserve native compiler/linker failures for dependencies that require the excluded event loop, networking, process, TLS, thread pool or watcher APIs. The mode is experimental, explicitly selected, and never defaults on for known or unknown versions. Doctor checks eligibility without creating the view. Full runtime remains default and reports its known Zig blockers. Keep object filtering for compatibility with the older assessed toolchain; retain `_CRT_RAND_S`.

Before release, test all five target headers with sync mode, host execution, a synchronous runtime/dependency consumer, an excluded async-runtime consumer failure, unchanged global runtime fingerprints, doctor human/JSON and actual emitted recovery commands. Existing Linux/macOS consumer jobs own integration checks; the release validation job requires the same candidate qualification. No new CI job is needed. To roll back guidance, remove the additive doctor interface and notices without modifying compiler selection, runtime sources, or output paths.

Header workarounds are automatically selected only for the exact assessed new stock runtime and Zig version. Linux targets add `-include limits.h`; Darwin targets add the detected macOS SDK include directory via `-idirafter` only when the SDK provides sys/vnode.h. These real flags and their prerequisites are rendered as warning findings. Missing Darwin SDK or Windows full-runtime blockers remain errors in doctor.

## Qualification evidence

Local macOS arm64 qualification on 2026-10-25 passed `mise run check`, `test:native-zig`, `test:scripts`, `test:consumer`, `test:doctor` and `test:pubman`. The installed Node, Chromium, NodeNext and Bundler consumers and read-only native/Wasm previews passed. zig-cross has 28 Wasm and 31 native tests. All five sync-mode consumer headers passed; both Darwin executables ran and printed `hello from consumer`, x64 through Rosetta. The isolated dependency fixture exercises environment/arguments/entropy, UTF conversion, synchronous stat and C-buffer APIs. An excluded thread-pool symbol fails at link time with raw diagnostics and a doctor hint. JSON reports and help, known/unknown/custom assessment, timeout/missing/noisy probes, usage statuses, child streams/status, PE warnings and view cleanup are covered by focused tests.

A fresh isolated 0.10.15 toolchain passed the zig-cross Wasm/native tests and original consumer task. Its original unfenced scripts are used for baseline checks because frontmatter imports require the upgraded toolchain. The current version's import migration is intentional.

CI runs the expanded consumer task on Linux and macOS, retaining the independent architecture assertion. This existing merge gate owns cross-target and diagnostic integration; release validation runs the same task for the exact candidate. The added work is the bounded probe/stream suite and five small fixture builds, not another runner matrix. Expected added runtime is under a minute after tool installation, to be checked in CI. The existing release verify stage additionally parses the installed doctor's schema/status after publication. No assurance is deferred to an ungated nightly or manual job.

Production landing, release PR and publication verification remain mandatory in the persistent native goal after this implementation record is archived. Windows runtime execution is not established; the OsString warning remains a shipping constraint.
