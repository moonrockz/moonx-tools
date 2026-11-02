# Design

## Context

### zig-cross targets

zig-cross is a MoonBit CLI run with `moonx`. It builds for the `wasm` backend in CI (`moon run apps/zig-cross --target wasm`) and for `native` as a consumer would. It runs on Linux and macOS hosts and stops on Windows. Each target has an enum case in `target.mbt`, a Zig triple, and an expected executable header in `format.mbt`. Windows-specific guidance lives in `doctor.mbt`:

- `ZC_WINDOWS_MSVC_RUNTIME` is the fall-through branch for any target that is neither Linux nor darwin, so a new Windows target already reaches it.
- `ZC_WINDOWS_OSSTRING` is gated on `targets.contains(WindowsX64)` and hard-codes `["windows-x64"]`.
- `header_flags` returns no flags for any target that is not Linux or darwin, so Windows targets already get no header fix.

Only sync mode builds Windows targets today. `scripts/test-consumer.mbtx` builds the consumer fixture for all five cross targets with `ZIG_CROSS_RUNTIME=sync` on the Ubuntu and macOS CI runners, and zig-cross checks each header as part of that build.

Probe result (2026-10-31, Windows arm64 machine, Zig 0.17.0, MoonBit 0.10.15 runtime): `runtime.c`, `env.c`, `sync_io.c`, `utf.c` and `backtrace.c` compile with `-target aarch64-windows-gnu -D_CRT_RAND_S`. A small C program linked against them produced PE machine `0xAA64`, ran natively, and allocated and freed a MoonBit string. This was not the 0.10.17 pin, and `c_buffer.c` was not tested.

### Windows development hosts

Observed on 2026-10-31 on a Windows 11 arm64 machine (Snapdragon X Elite), Zig 0.17.0 arm64, mise 2026.10.13:

- `cli.moonbitlang.com` has no `moonbit-windows-aarch64.zip` or `moonbit-windows-arm64.zip` for 0.10.17. `install/powershell.ps1` downloads `moonbit-windows-x86_64.zip` on both `AMD64` and `ARM64`. An older x64 install in `~/.moon` already ran on this machine.
- A local `config.local.toml` that maps `windows-arm64` to the x64 zip made `mise install` succeed. A `postinstall` command on the `http:moonbit` tool ran during `mise install` with `MISE_TOOL_INSTALL_PATH` and `MISE_TOOL_VERSION` set. A prototype PowerShell script there created `bin/moonx.exe` as a hard link to `moon.exe`, downloaded `cores/core-<version>.zip`, and ran `moon bundle` for all targets and for wasm-gc. The result was a complete toolchain.
- `moon run scripts/<name>.mbtx` runs a task script without `moonx`. Compiling any script still needs the core library, so the completion step cannot itself be MoonBit.
- Git for Windows from Scoop sets `core.autocrlf=true` in its system gitconfig, and the repo has no `.gitattributes`. The checkout was CRLF. `lint:yaml` reported `new-lines` errors, `test:scripts` failed on `release.mbtx publish_list is not closed`, and `lint:moonbit` left four `pkg.generated.mbti` files behind. In an LF clone (`core.autocrlf=false`), all three passed or were clean.
- In the LF clone, with `MOON_HOME` set to the mise install and after `moon update`:
  - Passed: `validate:versions`, `validate:packages`, `lint:yaml`, `lint:moonbit`, `test:scripts`, `build:wasm`, `build:js`, `build:native`.
  - Native output was PE `0x8664`, because x64 moon finds the x64 MSVC tools.
- Failures, by suite:

| Suite | Target | Result | Cause |
|---|---|---|---|
| `apps/zig-cross` | wasm | 35/35 pass | |
| `apps/zig-cross` | native | 5 of 41 fail | Tests execute the `/bin/sh` wrappers or `chmod` a fake `uname` |
| `apps/pubman` | wasm, native | 13 of 21 fail | `@process.run` of POSIX tools, `@fs.realpath` and `@fs.open` errors, `@fs.symlink` needs a privilege |
| `fixtures/consumer` | all four targets | pass | |
| `fixtures/pubman-consumer` | wasm, wasm-gc, js | pass | |
| `fixtures/pubman-consumer` | native | link error | MSVC link of the blackbox test failed. The cause is unconfirmed; the clone path was about 150 characters long |
| `test:doctor` | | fails | First assertion fails. The script uses `/bin/sh` throughout |
| `test:consumer`, `test:native-zig` | | fail | zig-cross: "runs on Linux or macOS only" |

- `apps/zig-cross` and `apps/pubman` support only `native+wasm`, so `test.mbtx` already skips them for wasm-gc and js.

## Goals / Non-Goals

**Goals:**
- Add `windows-arm64` with the same wrappers, checks and warnings as `windows-x64`.
- Write the Windows checks once for both Windows targets, so a third one would need no further doctor changes.
- Prove in CI on both Linux and macOS hosts that a sync-mode consumer links for `windows-arm64` with the right header.
- Make `mise install` followed by `mise run check` work on a fresh Windows arm64 or x64 machine, with the gaps named and not hidden.
- Use one toolchain setup path for local machines and CI.

**Non-Goals:**
- Running the arm64 zig-cross output in CI. A runtime test there would still not cover the `OsString` limit, which is the real Windows risk.
- Porting the POSIX-dependent tests. The skip list makes the gap visible so later changes can remove entries one at a time.

## Decisions

### zig-cross target

**Target name `windows-arm64`.** It matches `linux-arm64` and `darwin-arm64`. `windows-aarch64` was rejected because no other target name uses `aarch64`.

**Triple `aarch64-windows-gnu`, not `aarch64-windows-msvc`.** The `-gnu` ABI uses Zig's bundled MinGW-w64 headers and libraries, as `windows-x64` does, so it needs no Windows SDK on the Linux or macOS host. The `-msvc` ABI needs the SDK and the MSVC CRT, which zig-cross cannot provide.

**One `is_windows(target)` predicate.** Add it to `target.mbt` and use it for the `ZC_WINDOWS_OSSTRING` gate and target list. The finding stays a single entry whose `targets` are the requested Windows targets in request order, as `ZC_COMPATIBILITY_MODE` already lists every requested name. The alternative, one `ZC_WINDOWS_OSSTRING` per target, would change the number of findings that agents see for `windows-x64` together with another Windows target. The fall-through branches for `ZC_WINDOWS_MSVC_RUNTIME` and `header_flags` already behave correctly. They stay as they are, and tests pin that behavior for `windows-arm64`.

**Expected header `Pe(0xAA64)`.** `0xAA64` is IMAGE_FILE_MACHINE_ARM64. ARM64EC (`0xA641`) and ARM64X binaries do not count as a match, since Zig does not produce them for this triple.

**Validation in existing scripts.** No new script or mise task for the target:
- `scripts/test-consumer.mbtx` adds `windows-arm64` to the sync build list. Both CI consumer jobs (Ubuntu, macOS) then link it and check its header through zig-cross itself.
- `scripts/test-doctor.mbtx` adds a fake `0xAA64` PE fixture under `windows-arm64` (build passes and warns with `ZC_WINDOWS_OSSTRING`) and a `0x8664` fixture under `windows-arm64` (build exits 1). This covers the mismatch case without a real toolchain.
- The Python PE check in `ci.yml` checks only `matrix.cross` (Linux targets today). Its `windows-` branch hard-codes `0x8664`. Change it to pick the machine by target, so it stays correct if a matrix entry ever uses a Windows target.

**Backends and hosts.** The target table is plain data used the same way on the `wasm` and `native` backends, so nothing is backend-specific. zig-cross hosts stay Linux and macOS. The new target is a cross target on both.

### Windows development hosts

**Map `windows-arm64` to the x64 archive.** Add `windows-arm64` under `[tools."http:moonbit".platforms]` with the same URL and `format = "zip"` as `windows-x64`. This follows MoonBit's own installer. The alternative, asking arm64 contributors for a local override, leaves `mise install` broken by default. Don't add a `macos-x64` entry: MoonBit publishes no `darwin-x86_64` archive for 0.10.17.

**Complete the toolchain in a mise `postinstall` hook.** The hook calls one of two bootstrap scripts in `scripts/bootstrap/`, chosen with mise's template `os()` function. Both scripts read `MISE_TOOL_INSTALL_PATH` and `MISE_TOOL_VERSION`.
- `complete-moonbit.ps1` (Windows) does what the prototype did: hard-link `moonx.exe`, download and unpack `cores/core-<version>.zip`, and run both `moon bundle` passes. It then runs `moon update` with `MOON_HOME` set to the install path, because a fresh home has no registry index and the task scripts' registry imports fail without it. Any failed step fails the script. It runs under Windows PowerShell 5.1 (`powershell -NoProfile -ExecutionPolicy Bypass -File`), so it needs no pwsh install. It does not call `install/powershell.ps1`, because that script rewrites the user's persistent `PATH`, unpacks under `$HOME`, and re-downloads the binaries.
- `complete-moonbit.sh` (Linux, macOS) runs `install/unix.sh` with `MOON_HOME` set to the install path, as CI's bash step does today, and then runs `moon update`.

This is an exception to the AGENTS.md rule that task automation is written in `.mbtx`. These scripts run before any MoonBit can compile, because the core library is what they install. AGENTS.md says so next to the rule. The CI setup action drops its "Complete the MoonBit toolchain" step and its `moon update`. It keeps exporting `MOON_HOME` and the bin path from `mise where http:moonbit`.

Alternatives:
- A separate `mise run setup` task. Contributors would have to remember to run it, and CI and local machines would drift.
- Keeping the bash step in CI and documenting a manual PowerShell step. Two setup paths to keep in sync.

**`MOON_HOME`.** CI sets `MOON_HOME` to the mise install. Locally it was unset. With it unset, a script compiled and ran, but it is not yet proven which core library was used, the mise one or the 0.10.15 one in `~/.moon`. Task 1.3 checks this. If `moon` does not find its own core, set `MOON_HOME` in mise's `[env]` from the tool's install path.

**`.gitattributes`: `* text=auto eol=lf`.** The index is already LF (`i/lf` everywhere), so adding the file renormalizes nothing in git. Existing Windows checkouts keep CRLF files until they are checked out again. The README says how to do that without losing local changes: commit or stash, then `git rm --cached -r -q . && git reset --hard`. Binary files stay binary under `text=auto`.

**Windows skip list in `scripts/test.mbtx`.** A literal list of `(member, target)` pairs that need a Linux or macOS host: `("apps/pubman", "*")` and `("apps/zig-cross", "native")`. On Windows (`OS=Windows_NT`), `test.mbtx` leaves these packages out and prints `⏭️  <member> (<target>) skipped: needs a Linux or macOS host` for each one. On other hosts, the list has no effect. A feature scenario in `scripts/features/` covers the list for both hosts.

The skip is per suite, not per test, so the white-box tests stay unchanged. The alternative, an early `return` inside each POSIX test on Windows, would let those tests report "passed" without running.

**Host guards in `test-doctor.mbtx`, `test-pubman.mbtx` and `test-consumer.mbtx`.** Each checks `OS=Windows_NT` first, prints `<task> needs a Linux or macOS host`, and exits 1. `test:native-zig` and `build:cross` call zig-cross directly, and its existing check already does this.

**Windows CI job.** A `windows-host` job on `windows-11-arm` uses the setup action with a PowerShell-compatible path (`shell: pwsh` steps on Windows), then runs `mise run lint`, `validate`, `test:scripts`, `test` and `build`. `ci-ok` lists it in `needs`. The runner's preinstalled MSVC is the native C compiler, as on the local machine. The job runs the same tasks a contributor runs, not a separate script.

**Project context.** Update the `context` in `openspec/config.yaml` and AGENTS.md. zig-cross still runs only on Linux and macOS, but the repository's general tasks also support Windows hosts, with the skip list.

## Risks / Trade-offs

- [The 0.10.17 sync runtime, or `c_buffer.c`, does not link for `aarch64-windows-gnu`] → Task 2.1 compiles and links the pinned runtime directly with `zig cc` before any zig-cross code changes. It works on this Windows machine and does not need zig-cross. If it fails, stop and revise this change instead of shipping a target that cannot build.
- [Users read a passing header check as a working arm64 binary] → `ZC_WINDOWS_OSSTRING` names `windows-arm64`, and the README states that Windows targets are checked for linking and headers only.
- [The default `doctor` report gains a seventh target] → This adds to the report and does not change any existing finding. Agents that compare full target lists see one more name. The proposal records this.
- [The MoonBit 0.10.18 cross job in CI does not build Windows] → It covers the full runtime, which Windows cannot build. Leave it unchanged.
- [mise's `os()` template or `postinstall` behaves differently on Linux and macOS runners] → Task 1.2 verifies a fresh `mise install` on this machine. Task 6.2 verifies the Ubuntu and macOS CI jobs once the bash step is gone. Any failure shows in `ci-ok`.
- [The `windows-11-arm` runner image lacks MSVC, or `mise` cannot run there] → Task 6.1 runs the job on a branch before it becomes required. If the image falls short, fall back to `windows-latest`. It runs the same x64 toolchain, but without emulation.
- [x64 emulation makes the Windows job slow] → On this machine, native builds took about 60 seconds. The job gets the same 30-minute timeout as the consumer jobs.
- [The skip list hides a regression in pubman or zig-cross on Windows] → Every skip is printed by name, and both suites still run on Linux and macOS in CI. Porting either suite removes its entry.
- [The `pubman-consumer` native link failure is not caused by the long path] → Task 1.7 runs that test from the real checkout path. If it still fails, add `("fixtures/pubman-consumer", "native")` to the skip list with the linker error recorded, or fix the cause if it is small.
