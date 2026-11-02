# Tasks

## 1. Windows host setup

- [x] 1.1 Add `windows-arm64` under `[tools."http:moonbit".platforms]` in `.config/mise/config.toml`, with the `windows-x64` URL and `format = "zip"`, plus a comment explaining the x64 emulation choice. On the Windows arm64 machine, delete the temporary `.config/mise/config.local.toml`, run `mise install`, and verify that it succeeds and that `mise exec -- moon version --all` reports `0.10.18+6c83a7f62`.
- [x] 1.2 Add `scripts/bootstrap/complete-moonbit.ps1` and `scripts/bootstrap/complete-moonbit.sh` as in design.md: link or install `moonx`, unpack and bundle the core library, run `moon update`, and fail on any error. Add a `postinstall` to the `http:moonbit` tool that picks the script with mise's `os()` template and resolves its path from the config root. Remove the "Complete the MoonBit toolchain" step and the `moon update` from `.github/actions/setup/action.yml`. Verify on the Windows machine: `mise uninstall http:moonbit` followed by `mise install` leaves `lib/core` bundled, `bin/moonx.exe` present and a registry index, and `mise run validate:versions` passes. Verify the failure path with a scratch config pointing at a missing core version: `mise install` exits nonzero and names the failed download.
- [x] 1.3 With `MOON_HOME` unset and an older MoonBit present in `~/.moon`, find out which core library and registry `mise exec -- moon` uses. If it is not the mise install, set `MOON_HOME` in mise's `[env]` from the tool's install path. Verify that `mise run lint:moonbit` compiles against the mise install's core, for example by temporarily giving the mise core a marker that a compile picks up, without changing `~/.moon`.
- [x] 1.4 Add `.gitattributes` with `* text=auto eol=lf`. Verify that `git add --renormalize .` stages nothing. Then, in a fresh clone made with `core.autocrlf=true` (and `core.longpaths=true` if the path is long), verify that `git ls-files --eol` shows `w/lf` for text files and that `mise run lint:yaml` and `mise run test:scripts` pass there.
- [x] 1.5 In `scripts/test.mbtx`, add the Windows skip list `("apps/pubman", "*")` and `("apps/zig-cross", "native")`. On `OS=Windows_NT`, leave those packages out and print one `⏭️  <member> (<target>) skipped: needs a Linux or macOS host` line each. Add a `scripts/features/test.feature` scenario showing that the list applies on Windows and has no effect elsewhere. Verify with `mise run test:scripts`. On the Windows machine, verify that `mise run test` exits 0 and prints the skip lines.
- [x] 1.6 Add an `OS=Windows_NT` guard as the first step of `scripts/test-doctor.mbtx`, `scripts/test-pubman.mbtx` and `scripts/test-consumer.mbtx`. Each prints `<task> needs a Linux or macOS host` and exits 1. Verify on the Windows machine that each `mise run` exits 1 with that message, and that `test:doctor` and `test:consumer` create nothing new under `_build`. Verify `mise run build:cross -- linux-x64` still exits 1 with zig-cross's message.
- [x] 1.7 From the real checkout path, run `moon test fixtures/pubman-consumer --target native` on the Windows machine. If it passes, nothing more is needed. If it fails, record the linker error in design.md, and either fix the cause if it is small or add `("fixtures/pubman-consumer", "native")` to the skip list. Verify that `mise run test` exits 0 on the Windows machine.
- [x] 1.8 Document Windows hosts:
  - README: supported hosts, x64 MoonBit under emulation on arm64, the skip list and host-limited tasks, and how to re-check-out an old CRLF checkout safely (commit or stash first).
  - AGENTS.md: the Toolchain section gets the `windows-arm64` mapping and the post-install bootstrap. The Task scripts section gets the bootstrap exception to the `.mbtx` rule.
  - `openspec/config.yaml` context: zig-cross stays Linux/macOS-only, and general repository tasks also run on Windows.
  
  Verify that `openspec validate --all --strict` passes and that each documented command runs as written on the Windows machine.
- [x] 1.9 On the Windows arm64 machine, run `mise run format` and `mise run check`. Verify that `check` exits 0 and that `git status` shows no stray generated files.

## 2. Feasibility gate

- [ ] 2.1 With Zig 0.17.0 and the runtime sources of both the pinned MoonBit 0.10.18 (`$(mise where http:moonbit)/lib/runtime`) and the separately installed assessed MoonBit 0.10.17, compile the six sync units (`runtime.c`, `env.c`, `sync_io.c`, `utf.c`, `backtrace.c`, `c_buffer.c`) with `zig cc -target aarch64-windows-gnu -D_CRT_RAND_S -c`. Link a small C program that calls `moonbit_make_string` against them. Verify that every compile and the link exit 0, that the output's PE machine is `0xAA64`, and, on a Windows arm64 machine, that the program runs and exits 0. If any step fails, stop and revise this change before continuing.

## 3. Target table and executable format

- [ ] 3.1 Add `WindowsArm64` to `Target` in `apps/zig-cross/target.mbt`: name `windows-arm64`, `parse`, triple `aarch64-windows-gnu`, and `windows-arm64` in `all_target_names()` after `windows-x64`. Add an `is_windows(target)` predicate that is true for both Windows targets. Extend `target_wbtest.mbt` for the name, parse, triple and predicate. Verify with `moon test apps/zig-cross --target wasm`, and with `--target native` on a Linux or macOS host or in CI.
- [ ] 3.2 Return `Pe(0xAA64)` from `expected_format(WindowsArm64)` in `apps/zig-cross/format.mbt`. In `format_wbtest.mbt`, add a matching `0xAA64` header and a `0x8664` header that fails `check_format(WindowsArm64, ...)` with an expected/found message. Verify with `moon test apps/zig-cross --target wasm`.
- [ ] 3.3 Add `cc_wrapper(WindowsArm64)` and `ar_wrapper(WindowsArm64)` tests that assert `-target aarch64-windows-gnu -D_CRT_RAND_S`, the simdutf/libbacktrace filtering, and no header fix flags. Verify with `moon test apps/zig-cross --target wasm` for the text assertions. Tests that execute the wrappers run with `--target native` on a Linux or macOS host or in CI.
- [ ] 3.4 Add `windows-arm64` to the targets line in `apps/zig-cross/cli.mbt`. Update the expected unknown-target message in `cli_wbtest.mbt`, and add a parse test for `doctor` with no targets that expects seven targets. Verify with `moon test apps/zig-cross --target wasm`.
- [ ] 3.5 In `apps/zig-cross/README.md` and `README.md`, update:
  - the Targets table (triple `aarch64-windows-gnu`, `PE, machine 0xAA64`) and the target lists
  - the "six targets" doctor text (now seven) and the "all five targets" validation text (now six)
  - the Windows note, to say it covers both Windows targets
  
  Verify by grepping both READMEs for `windows-x64` and checking that each list also names `windows-arm64`.

## 4. Windows guidance

- [ ] 4.1 In `apps/zig-cross/doctor.mbt`, gate `ZC_WINDOWS_OSSTRING` on any requested target where `is_windows` is true, and set its targets to the requested Windows target names in request order. In `doctor_wbtest.mbt`, add tests for:
  - `[WindowsArm64]` alone
  - `[WindowsX64, WindowsArm64, LinuxX64]`, which gives one finding with both Windows names
  - sync mode keeping the warning for `windows-arm64`
  
  Verify with `moon test apps/zig-cross --target wasm` that existing `windows-x64` tests still pass.
- [ ] 4.2 Add doctor tests pinning the fall-through behavior for `windows-arm64`. In full runtime mode with an assessed toolchain, it gets a `ZC_WINDOWS_MSVC_RUNTIME` error with a `ZIG_CROSS_RUNTIME=sync zig-cross build windows-arm64 -- <package-path>` next step and status `error`, and `header_flags(WindowsArm64, ...)` is empty. Verify with `moon test apps/zig-cross --target wasm`.
- [ ] 4.3 In `scripts/test-doctor.mbtx`, after the host guard:
  - add a fake PE fixture with machine `0xAA64` under `windows-arm64`: the build exits 0 and stderr contains `ZC_WINDOWS_OSSTRING`
  - add a fake PE fixture with machine `0x8664` under `windows-arm64`: the build exits 1
  - add a sync-mode `doctor windows-arm64 --json` check for `ZC_COMPATIBILITY_MODE` and `ZC_WINDOWS_OSSTRING`
  
  Verify with `mise run test:doctor` on a Linux or macOS host or in the CI consumer jobs.

## 5. Consumer and zig-cross CI validation

- [ ] 5.1 Add `windows-arm64` to the sync-mode consumer build in `scripts/test-doctor.mbtx`, invoked by `scripts/test-consumer.mbtx`, and rename the step "All six cross target headers with the explicit sync runtime". Verify with `mise run test:consumer` with `ZIG_CROSS_SYNC_MOON_HOME` pointing to the assessed 0.10.17 home on a Linux or macOS host or in the CI sync-runtime jobs: the summary shows a passing `windows-arm64` row.
- [ ] 5.2 Change the `windows-` branch of the PE check in `.github/workflows/ci.yml` to expect `0xAA64` for `windows-arm64` and `0x8664` for `windows-x64`. Verify by running the embedded Python against the arm64 binary from 5.1 with target `windows-arm64`. It should print `OK windows-arm64: PE machine 43620`.

## 6. Windows CI job

- [ ] 6.1 Make `.github/actions/setup/action.yml` work on Windows runners: use `shell: pwsh` steps when `runner.os == 'Windows'` to install mise, put its shims and the MoonBit bin directory on `GITHUB_PATH`, and set `MOON_HOME`. Add a `windows-host` job on `windows-11-arm` with a 30-minute timeout that runs `mise run lint`, `validate`, `test:scripts`, `test` and `build`, and add it to `ci-ok`'s `needs`. Verify on a pushed branch that the job passes and its log shows the skip lines. If the runner image cannot run it, switch to `windows-latest` and record why in design.md.
- [ ] 6.2 Verify that the Ubuntu and macOS jobs pass with the toolchain completed by the post-install hook and without the removed bash step.

## 7. Integration checks

- [ ] 7.1 Run `mise run format`, then verify that `git diff --stat` shows no unexpected formatting churn.
- [ ] 7.2 Run `mise run lint` and `mise run validate` and verify that both pass.
- [ ] 7.3 Run `mise run check` and `mise run test:scripts` on the Windows arm64 machine and verify that both pass.
- [ ] 7.4 Run `openspec validate --all --strict` and verify that it passes.
- [ ] 7.5 Push the branch and verify that every CI job passes and `ci-ok` is green: lint, build, test, the consumer jobs and the MoonBit 0.10.17 sync-runtime jobs on `ubuntu-latest` and `macos-latest` with the `windows-arm64` sync build, pinned MoonBit 0.10.18, native-zig, scripts, and `windows-host`.

## Workflow follow-up

- Archive the change with `openspec-archive-change` after review and merge.
- Record the new target and Windows host support in the next release's CHANGELOG highlights (`mise run release:prepare`).
