# Verification record

## Windows arm64 host

Verified on the contributor checkout at `C:/Users/damre/code/repos/github/moonrockz/moonx-tools`.

- 1.1: deleted `.config/mise/config.local.toml`. `mise install` passed; `mise exec -- moon version --all` reported `0.10.18+6c83a7f62`.
- 1.2: uninstalled the selected 0.10.18 version and installed it again. The hook created `bin/moonx.exe`, core bundles for wasm, wasm-gc, js and native, and `registry/index`. `mise run validate:versions` passed. A scratch http-tool config used the real binary archive with version `0.0.0-missing-core`; installation exited 1 and printed the failed core URL.
- 1.3: with MOON_HOME unset, the selected compiler used the stale registry in the older 0.10.15 home. The mise environment now sets MOON_HOME after tools load. After `moon clean`, temporarily moving the mise core's `prelude.mi` made `mise run lint:moonbit` fail with the mise install's absolute path. Restoring it made lint pass. The older home was untouched.
- 1.4: committed all work before adding attributes. `git add --renormalize .` staged nothing. Committed attributes before re-checkout. A fresh clone with autocrlf and longpaths enabled had LF text files; `lint:yaml` and all five script test suites passed there.
- 1.5: the new feature failed on the Windows pubman case before the skip predicate was implemented. `test:scripts` then passed; `test` passed on all four backends with the required skip lines.
- 1.6: each host guard exited 1 with its task name and host requirement. Comparing file inventories before and after showed no new `_build` files. `build:cross -- linux-x64` exited 1 with zig-cross's existing host error.
- 1.7: `moon test fixtures/pubman-consumer --target native` passed from the real checkout path. No extra skip was added.
- 1.8 and 1.9: documented setup, check and LF refresh commands were exercised. Strict validation, format and the full check passed. MoonBit 0.10.18's new default interface generation required `moon check --no-mbti`; lint still uses `--deny-warn` and leaves no generated files.

## Feasibility gate

For both 0.10.18+6c83a7f62 and the separately installed assessed 0.10.17+d971670cd, Zig 0.17.0 compiled `runtime.c`, `env.c`, `sync_io.c`, `utf.c`, `backtrace.c` and `c_buffer.c` with `cc -target aarch64-windows-gnu -D_CRT_RAND_S -I <home>/include -c`. Every compile and the link exited 0. Both outputs had PE machine 0xAA64 and ran on this Windows arm64 host with exit 0.

The linked program was:

```c
#include "moonbit.h"
int main(void) {
  moonbit_string_t s = moonbit_make_string(3, 65);
  if (!s || s[0] != 65) return 1;
  moonbit_decref(s);
  return 0;
}
```

This direct C probe does not expand sync eligibility to 0.10.18.

## Target and guidance tests

New target/format/CLI tests first failed because WindowsArm64 was absent. After implementation, 39 wasm tests passed. New doctor tests then failed on the missing arm64 warning and the x64-only target list. After the shared predicate was applied, all 42 wasm tests passed, including both existing x64 behavior and new arm64 behavior.

## Integration

On Windows arm64, `mise run format`, `lint`, `validate`, `check`, `test:scripts` and `openspec validate --all --strict` passed after implementation. Formatting changes were limited to touched code. CI-dependent verification is recorded below after the jobs finish.
Native target and wrapper execution passed in [CI job 125044809351](https://github.com/moonrockz/moonx-tools/actions/runs/41372134626/job/125044809351), with 72/72 workspace native tests passing.

[Windows host CI job 125044655130](https://github.com/moonrockz/moonx-tools/actions/runs/41372134626/job/125044655130) passed on windows-11-arm. Its log shows pubman skips for all four backends, the zig-cross native skip, passing remaining tests and all builds. No runner fallback was needed.

[Ubuntu sync job 125044809263](https://github.com/moonrockz/moonx-tools/actions/runs/41372134626/job/125044809263) passed the matching/mismatched arm64 PE fixtures, sync doctor assertions, six-target consumer build and embedded Python check. Its summary has a passing windows-arm64 row; Python prints `OK windows-arm64: PE machine 43620`.

The first consumer jobs exposed a gate fixture that still listed the old job set. The fixture now includes windows-host and checks success, failure, cancellation, skip and missing results separately for both consumer and Windows jobs. Running the checked-in jq gate against all ten cases locally passed. The actual gate was not weakened.

[macOS sync job 125044809326](https://github.com/moonrockz/moonx-tools/actions/runs/41372134626/job/125044809326) also passed all six headers and printed the expected arm64 Python result. Both Unix hosts completed the toolchain through the post-install hook.

[CI run 41372356316](https://github.com/moonrockz/moonx-tools/actions/runs/41372356316) passed all 17 jobs, including ci-ok and windows-host, after the gate fixture fix.

[Ubuntu sync consumer job 125046505090](https://github.com/moonrockz/moonx-tools/actions/runs/41372690218/job/125046505090) then passed the full `mise run test:consumer` entry point with the separate assessed home, a passing windows-arm64 summary row, and the embedded Python check. All 27 task verifications have now passed. The final PR head must independently have all checks green before merge.

The final implementation head 2aa8bbb passed all 17 jobs in [CI run 41373132277](https://github.com/moonrockz/moonx-tools/actions/runs/41373132277), including Windows host and ci-ok. [Release dry-run 41373132224](https://github.com/moonrockz/moonx-tools/actions/runs/41373132224) also passed validation and skipped publication. [Implementation PR #18](https://github.com/moonrockz/moonx-tools/pull/18) was squash-merged as f2f08c7 before this archive follow-up.
