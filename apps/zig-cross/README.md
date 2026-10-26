# zig-cross

`zig-cross` cross-compiles MoonBit native binaries with [zig](https://ziglang.org). It builds for Linux, macOS and
Windows from one machine. It runs with `moonx`, so you do not install it.

Maintained in [moonrockz/moonx-tools](https://github.com/moonrockz/moonx-tools). Moved from
[moonrockz/smithy](https://github.com/moonrockz/smithy) `apps/zig-cross`; package name `moonrockz/zig-cross`,
Existing build/exec commands, target names and output paths are preserved.

## Requirements

- Zig 0.17.0 on `PATH`: `mise use zig@0.17.0`.
- The `moon` command.
- Linux or macOS as the build machine. The tool stops on Windows.

## Usage

```sh
moonx moonrockz/zig-cross@<version> doctor linux-x64 darwin-arm64
moonx moonrockz/zig-cross@<version> build linux-x64 -- apps/myapp
ZIG_CROSS_RUNTIME=sync moonx moonrockz/zig-cross@<version> build darwin-arm64 -- apps/myapp
moonx moonrockz/zig-cross@<version> exec host -- moon test --target native
moonx moonrockz/zig-cross@<version> --help
```

`build [--target-dir DIR] <target>... [-- <path>...]`

1. It writes the wrappers `cc` and `ar` to `DIR/zig/<target>`. `DIR` is `_build/cross` by default.
2. It runs `moon build --target native --release --target-dir DIR/<target> [paths]` with `MOON_CC` and `MOON_AR`
   set to the wrappers.
3. It reads the header of each `*.exe` under `DIR/<target>/native/release/build`. A binary with the wrong
   architecture is a failure.
4. It prints a table (target, path, size, result). It exits with 1 when one target fails.

`exec <target> -- <command> <arg>...` runs a command with `MOON_CC` and `MOON_AR` set to the wrappers of one
target. Use `host` to compile the tests of a package with zig.

## Targets

| Name           | Zig triple            | Header check          |
| -------------- | --------------------- | --------------------- |
| `linux-x64`    | `x86_64-linux-musl`   | ELF, machine 62       |
| `linux-arm64`  | `aarch64-linux-musl`  | ELF, machine 183      |
| `darwin-arm64` | `aarch64-macos`       | Mach-O, cputype 16777228 |
| `darwin-x64`   | `x86_64-macos`        | Mach-O, cputype 16777223 |
| `windows-x64`  | `x86_64-windows-gnu`  | PE, machine 0x8664    |
| `host`         | none (the host)       | none                  |

## Do not ship a cross-built Windows binary

A `windows-x64` binary that zig cross-builds is wrong for MoonBit code that uses `OsString`: arguments,
environment variables and paths. The `core` library is prebuilt for the host. Its `#cfg(platform="windows")`
setting is resolved from the host OS, not from the target. A Windows binary built on Linux or macOS therefore
reads its arguments wrongly. Build Windows binaries on Windows until moon can set the target platform
([moonbitlang/moon#2320](https://github.com/moonbitlang/moon/issues/2320)).

`zig-cross` itself runs on Linux/macOS only.

## What the wrappers change, and why

Two upstream bugs make a plain `MOON_CC="zig cc -target ..."` fail.

- Every wrapper adds `-D_CRT_RAND_S`. The MoonBit runtime file `env.c` includes `<stdlib.h>` before it defines
  `_CRT_RAND_S`, so `rand_s` is not declared on Windows. The flag defines it before the first include.
  Upstream: [moonbitlang/moonbit-native-runtime#2](https://github.com/moonbitlang/moonbit-native-runtime/issues/2).
- A cross wrapper drops `-DMOONBIT_USE_SIMDUTF` and the arguments that end in `/moonbit_simdutf.o`,
  `/simdutf.o` and `/libbacktrace.a`. moon links these prebuilt objects for the machine that runs moon. They have
  the wrong architecture for the target. The `ar` wrapper drops the two simdutf objects. The `host` wrapper
  drops nothing. Upstream: [moonbitlang/moon#2320](https://github.com/moonbitlang/moon/issues/2320).
- The `host` wrapper adds `-lunwind` on Linux, for link steps only. A debug build there compiles `backtrace.c`,
  which needs the unwinder. gcc links its unwinder by itself, but `zig cc` does not. macOS needs nothing.

## Diagnose before upgrading or building

`doctor [<target>...] [--json]` runs outside a project without building, writing wrappers or changing a toolchain. No targets selects all six targets, including `host`. Repeated targets are removed. Tool probes capture output and time out after three seconds each. Help and version do not probe tools.

```sh
moonx moonrockz/zig-cross@<version> doctor
moonx moonrockz/zig-cross@<version> doctor windows-x64 --json > report.json
ZIG_CROSS_RUNTIME=sync moonx moonrockz/zig-cross@<version> doctor windows-x64 --json
```

For agents, stdout is one JSON document with `schema_version: 1`, `environment`, `targets`, `status` and `findings`. Environment includes host, Moon/compiler/Zig versions, detected toolchain root, runtime fingerprint, runtime mode and detected macOS SDK and toolchain override names. Each finding has a stable `code`, `severity`, affected `targets`, `message`, `applicability`, `evidence` and `next_steps`. Steps distinguish `command` from `instruction` and state prerequisites. Replace placeholders such as `<package-path>` before running commands. When using `moonx`, replace the `zig-cross` executable in a suggested command with `moonx moonrockz/zig-cross@<version>`.

Statuses are `error`, `warning`, `unknown` or `ok`, in that precedence. Finding severities are `error`, `warning` or `unverified`. The status is `error` if a finding is `error`, else `warning` if a finding is `warning`, else `unknown` if a finding is `unverified`, else `ok`. Errors exit 1; other reports exit 0. Invalid arguments exit 2 and retain JSON output when `--json` is present. Treat prose as explanatory and consume codes/statuses. Additive fields are allowed within schema version 1.

Build and exec emit applicable findings once per invocation to stderr. Child stdin/stdout/stderr and exit mapping remain inherited. A failed build adds `zig-cross doctor <failed-target>` without replacing compiler diagnostics. For example:

```sh
moonx moonrockz/zig-cross@<version> doctor darwin-arm64
ZIG_CROSS_RUNTIME=sync moonx moonrockz/zig-cross@<version> doctor darwin-arm64
ZIG_CROSS_RUNTIME=sync moonx moonrockz/zig-cross@<version> build darwin-arm64 -- apps/myapp
```

## MoonBit 0.10.17 compatibility

Assessed stock versions are MoonBit `0.10.17+d971670cd`, Moon `0.1.20261023`, Zig `0.17.0`, on Linux and macOS hosts. The previous `0.10.15+943464bfa` runtime also has an exact assessment. Runtime C contents are checked by SHA-256, using a manifest of `name:sha256` lines sorted in MoonBit String order, length then code units. Unknown versions or customized runtimes produce `ZC_TOOLCHAIN_UNVERIFIED`; they do not inherit a whitelist or an assertion of failure.

The new Moon tool [detects cross-target compilers and avoids host-only objects](https://github.com/moonbitlang/moon/pull/2321), but also compiles every shipped runtime C file. The wrappers retain the older object filtering for 0.10.15 compatibility and `_CRT_RAND_S` for MinGW. Full runtime remains the default:

- Linux targets, including `host` on Linux, receive `-include limits.h` for `dir.c`'s `NAME_MAX`. `ZC_LINUX_NAME_MAX` reports the active fix.
- Darwin targets on macOS receive `-idirafter <SDK>/usr/include` when `xcrun --show-sdk-path` locates an SDK containing `sys/vnode.h`. `ZC_DARWIN_VNODE_HEADER` reports the selected flags. An SDK is required; `-isysroot` alone did not work. This remedy cannot provide SDK headers on Linux.
- Windows full-runtime sources contain explicit MSVC-only checks and further MinGW incompatibilities. `ZC_WINDOWS_MSVC_RUNTIME` reports the blocker. Do not fake `_MSC_VER` or suppress compiler errors.

Header fixes apply only to the exact assessed new runtime with Zig 0.17.0. Doctor reports what it detected and what the wrapper will select; it does not compile a probe project. Custom native compiler wrappers can apply the stated flags, but require their own validation.

### Explicit experimental synchronous runtime

Set `ZIG_CROSS_RUNTIME=sync` for consumers whose required runtime symbols fit this subset:

`runtime.c`, `env.c`, `sync_io.c`, `utf.c`, `backtrace.c`, `c_buffer.c`.

The selection requires the exact new compiler/build-tool/Zig versions and stock runtime fingerprint. An unknown/custom runtime is refused before child execution. `ZIG_CROSS_RUNTIME=full`, or an unset variable, uses full runtime. Other values fail with `ZC_RUNTIME_MODE_INVALID`.

zig-cross copies these six files from the detected current installation into a temporary toolchain view, symlinks the matching compiler/core/headers and other libraries, and sets `MOON_TOOLCHAIN_ROOT` for the child. It cleans up the view after the child exits. It does not edit the global installation, change `MOON_HOME`, use old runtime sources or supply substitute stubs. Run build processes synchronously inside `exec`; background children cannot retain the temporary view after exec exits.

`ZC_COMPATIBILITY_MODE` identifies actual sync selection and its limits. The mode excludes the runtime's event loop, asynchronous filesystem, networking, processes, TLS, thread pools and watchers. A dependency requiring those excluded symbols fails at link time, with raw linker output and a doctor hint. To use those APIs, unset `ZIG_CROSS_RUNTIME` and build on the target OS with a native compiler supported by MoonBit. That native build should invoke Moon directly, outside zig-cross.

Validation covers the consumer's ELF/Mach-O/PE headers for all five targets, a dependency exercising synchronous runtime and environment/UTF APIs on the host, host execution, and expected failure for an excluded symbol. Header/link success alone does not establish behavior for every library or OS. Linux/macOS integration is gated in CI. Windows is link/header checked only and retains `ZC_WINDOWS_OSSTRING`; use a Windows-native build for programs using OsString.
