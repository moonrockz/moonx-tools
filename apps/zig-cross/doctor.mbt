///|
/// Versions and paths refer to the tools selected by Moon, not whichever moonc is first on PATH.
priv struct Environment {
  host_os : String?
  host_arch : String?
  zig_cross : String
  moon : String?
  compiler : String?
  zig : String?
  toolchain_root : String?
  runtime_fingerprint : String?
  runtime_mode : String
  darwin_sdk : String?
  toolchain_overrides : Array[String]
} derive(ToJson)

///|
priv struct NextStep {
  kind : String
  command : String
  prerequisites : String
} derive(ToJson)

///|
priv struct Finding {
  code : String
  severity : String
  targets : Array[String]
  message : String
  applicability : String
  evidence : Array[String]
  next_steps : Array[NextStep]
} derive(ToJson)

///|
priv struct Report {
  schema_version : Int32
  environment : Environment
  targets : Array[String]
  status : String
  findings : Array[Finding]
} derive(ToJson)

///|
let assessed_compiler = "0.10.17+d971670cd"

///|
let stock_runtime_fingerprint = "067e9fd5378d52fea64a265b4a4f5b2e79a8f47c91e5fb987a20a0ce8530a6c7"

///|
fn requested_mode() -> String {
  @env.get_env_var("ZIG_CROSS_RUNTIME").unwrap_or("full")
}

///|
async fn probe(command : String, args : Array[String]) -> String? {
  try {
    let out = @shell.Cmd(command, args).output(
      timeout_ms=3000,
      max_output_bytes=65536,
    )
    if out.exit_code() == 0 {
      Some(out.stdout().trim().to_owned())
    } else {
      None
    }
  } catch {
    _ => None
  }
}

///|
fn version_field(output : String, prefix : String) -> String? {
  for line in output.split("\n") {
    if line.has_prefix(prefix) {
      return Some(
        line[prefix.length():].split(" ").next().unwrap_or("").to_owned(),
      )
    }
  }
  None
}

///|
fn compiler_root(output : String) -> String? {
  for line in output.split("\n") {
    if line.has_prefix("moonc ") {
      let path = line.split(") ").last().unwrap_or("").to_owned()
      if path.has_suffix("/bin/moonc") {
        let path = if path.has_prefix("~/") {
          @env.get_env_var("HOME").unwrap_or("") + path[1:].to_owned()
        } else {
          path
        }
        return Some(path[:path.length() - 10].to_owned())
      }
    }
  }
  None
}

///|
async fn runtime_fingerprint(root : String) -> String? {
  try {
    let dir = root + "/lib/runtime"
    let names = @fs.readdir(dir)
    names.sort()
    let mut manifest = ""
    for name in names {
      if name.has_suffix(".c") {
        let data = @fs.read_file(dir + "/" + name).binary()
        manifest += name +
          ":" +
          @crypto.bytes_to_hex_string(@crypto.sha256(data)) +
          "\n"
      }
    }
    Some(@crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(manifest))))
  } catch {
    _ => None
  }
}

///|
async fn detect_environment() -> Environment {
  let moon_output = probe("moon", ["version", "--all"]).unwrap_or("")
  let host_os = probe("uname", ["-s"])
  let sdk = if host_os == Some("Darwin") {
    probe("xcrun", ["--show-sdk-path"])
  } else {
    None
  }
  let sdk = match sdk {
    Some(path) =>
      if @fs.exists(path + "/usr/include/sys/vnode.h") {
        Some(path)
      } else {
        None
      }
    None => None
  }
  let root = compiler_root(moon_output)
  let fingerprint = match root {
    Some(path) => runtime_fingerprint(path)
    None => None
  }
  {
    host_os,
    host_arch: probe("uname", ["-m"]),
    zig_cross: version_text(),
    moon: version_field(moon_output, "moon "),
    compiler: version_field(moon_output, "moonc v"),
    zig: probe("zig", ["version"]),
    toolchain_root: root,
    runtime_fingerprint: fingerprint,
    runtime_mode: requested_mode(),
    darwin_sdk: sdk,
    toolchain_overrides: [
      "MOONC_OVERRIDE", "MOON_CORE_OVERRIDE", "MOON_OVERRIDE",
    ].filter(name => @env.get_env_var(name) is Some(_)),
  }
}

///|
fn sync_eligible(env : Environment) -> Bool {
  env.toolchain_overrides.is_empty() &&
  env.compiler == Some(assessed_compiler) &&
  env.moon == Some("0.1.20261023") &&
  env.zig == Some("0.17.0") &&
  env.runtime_fingerprint == Some(stock_runtime_fingerprint) &&
  (env.host_os == Some("Linux") || env.host_os == Some("Darwin"))
}

///|
fn step(command : String, prerequisites : String) -> NextStep {
  { kind: "command", command, prerequisites, }
}

///|
fn instruction(text : String) -> NextStep {
  { kind: "instruction", command: text, prerequisites: "", }
}

///|
fn finding(
  code : String,
  severity : String,
  targets : Array[String],
  message : String,
  applicability : String,
  evidence : Array[String],
  next_steps : Array[NextStep],
) -> Finding {
  { code, severity, targets, message, applicability, evidence, next_steps, }
}

///|
fn report(
  env : Environment,
  targets : Array[Target],
  usage? : String,
) -> Report {
  let names = targets.map(t => t.name())
  let findings : Array[Finding] = []
  if usage is Some(message) {
    findings.push(
      finding("ZC_USAGE", "error", names, message, "invalid arguments", [], [
        step("zig-cross --help", "none"),
      ]),
    )
  } else {
    for
      (name, version) in [
        ("Moon/compiler", env.compiler),
        ("Moon build tool", env.moon),
        ("Zig", env.zig),
      ] {
      if version is None || version == Some("") {
        findings.push(
          finding(
            "ZC_TOOL_MISSING",
            "error",
            names,
            "Cannot probe \{name}; it is missing, failed, or exceeded the 3-second probe limit.",
            "tool probe failed",
            [],
            [
              instruction(
                "Install the complete MoonBit toolchain and Zig 0.17.0; correct PATH, then rerun doctor.",
              ),
            ],
          ),
        )
      }
    }
    if env.host_os != Some("Linux") && env.host_os != Some("Darwin") {
      findings.push(
        finding(
          "ZC_HOST_UNSUPPORTED",
          "error",
          names,
          "zig-cross requires a Linux or macOS host.",
          "host probe",
          [],
          [instruction("Run zig-cross on Linux or macOS.")],
        ),
      )
    }
    if env.runtime_mode != "full" && env.runtime_mode != "sync" {
      findings.push(
        finding(
          "ZC_RUNTIME_MODE_INVALID",
          "error",
          names,
          "Unknown ZIG_CROSS_RUNTIME value: \{env.runtime_mode}",
          "explicit environment selection",
          [],
          [instruction("Unset ZIG_CROSS_RUNTIME or set it to full or sync.")],
        ),
      )
    }
    let eligible = sync_eligible(env)
    let old = env.toolchain_overrides.is_empty() &&
      env.compiler == Some("0.10.15+943464bfa") &&
      env.moon == Some("0.1.20261012") &&
      env.zig == Some("0.17.0") &&
      env.runtime_fingerprint ==
      Some("0c0a95f4fa7e59715b57ec30962c34f642a5caff0b28535c5933278c691fd23c")
    if !eligible && !old {
      findings.push(
        finding(
          "ZC_TOOLCHAIN_UNVERIFIED",
          "unverified",
          names,
          "This version, host, or runtime fingerprint has not been assessed. Compatibility is unverified.",
          "no exact stock-toolchain assessment",
          [],
          [
            step(
              "zig-cross build linux-x64 -- fixtures/consumer", "Run in moonrockz/moonx-tools; for your project use its package path and requested target.",
            ),
          ],
        ),
      )
    }
    if env.runtime_mode == "sync" {
      if eligible {
        findings.push(
          finding(
            "ZC_COMPATIBILITY_MODE",
            "warning",
            names,
            "Experimental sync runtime selected: runtime.c, env.c, sync_io.c, utf.c, backtrace.c, c_buffer.c. Excludes event loop, async filesystem, networking, processes, TLS, thread pools and watchers. Required excluded symbols fail at link time; no stubs are supplied.",
            "explicit ZIG_CROSS_RUNTIME=sync; exact version and runtime SHA-256 match",
            [stock_runtime_fingerprint],
            [
              instruction(
                "For excluded APIs, unset ZIG_CROSS_RUNTIME and build on the target OS with a native compiler supported by MoonBit; do not route that build through zig-cross.",
              ),
            ],
          ),
        )
      } else {
        findings.push(
          finding(
            "ZC_SYNC_UNAVAILABLE",
            "error",
            names,
            "Sync runtime refused: requires stock MoonBit \{assessed_compiler}, Moon 0.1.20261023, Zig 0.17.0 and a supported host.",
            "explicit sync selection failed eligibility",
            [],
            [
              instruction(
                "Install the assessed complete toolchain, or unset ZIG_CROSS_RUNTIME and use a native compiler on the target OS.",
              ),
            ],
          ),
        )
      }
    } else if eligible {
      for target in targets {
        let os = if target == Host {
          env.host_os.unwrap_or("")
        } else {
          target.name()
        }
        let (code, message) = if os.has_prefix("linux") || os == "Linux" {
          (
            "ZC_LINUX_NAME_MAX", "The full runtime dir.c uses NAME_MAX without limits.h with Zig. Header injection fixes this observed Linux compilation failure.",
          )
        } else if os.has_prefix("darwin") || os == "Darwin" {
          (
            "ZC_DARWIN_VNODE_HEADER", "The full runtime requires sys/vnode.h, absent from Zig headers. SDK headers via -idirafter are needed; -isysroot alone is insufficient. This is not a Linux-host remedy.",
          )
        } else {
          (
            "ZC_WINDOWS_MSVC_RUNTIME", "The full runtime contains MSVC-only Windows sources and additional MinGW incompatibilities. Compiler flags alone do not fix it.",
          )
        }
        let header_fix = header_flags(target, env)
        let active = !header_fix.is_empty()
        findings.push(
          finding(
            code,
            if active {
              "warning"
            } else {
              "error"
            },
            [target.name()],
            if active {
              "Active header workaround: " + header_fix + ". " + message
            } else {
              message
            },
            "fingerprinted stock 0.10.17 full runtime with Zig 0.17.0; assessed compilation, not reproduced by doctor",
            [
              "https://github.com/moonbitlang/moon/blob/3778465a252d2838357dddf25dc0ebf3ff3ba40f/crates/moonutil/src/toolchain.rs#L62",
            ],
            if active {
              [
                step(
                  "zig-cross build \{target.name()} -- <package-path>",
                  "Replace <package-path>; the detected header fix is automatically applied by this wrapper.",
                ),
              ]
            } else {
              [
                step(
                  "ZIG_CROSS_RUNTIME=sync zig-cross doctor \{target.name()}",
                  "Experimental; only consumers using the synchronous runtime subset.",
                ),
                step(
                  "ZIG_CROSS_RUNTIME=sync zig-cross build \{target.name()} -- <package-path>",
                  "Replace <package-path>; no excluded runtime APIs.",
                ),
                instruction(
                  "For full runtime APIs, use the target OS and a supported native compiler. Linux custom wrappers can add -include limits.h; macOS custom wrappers require an installed SDK and -idirafter <SDK>/usr/include. Validate your own build.",
                ),
              ]
            },
          ),
        )
      }
    }
    if targets.contains(WindowsX64) {
      findings.push(
        finding(
          "ZC_WINDOWS_OSSTRING",
          "warning",
          ["windows-x64"],
          "Cross-built Windows code using OsString can mishandle arguments, environment variables and paths. A valid PE header does not prove runtime correctness.",
          "Moon platform cfg and bundled core follow the Linux/macOS host; remains unverified for unknown versions",
          ["https://github.com/moonbitlang/moon/issues/2320"],
          [
            instruction(
              "Build Windows binaries that use OsString on Windows with the native toolchain until upstream target-platform support is fixed.",
            ),
          ],
        ),
      )
    }
  }
  let status = if findings.any(f => f.severity == "error") {
    "error"
  } else if findings.any(f => f.severity == "warning") {
    "warning"
  } else if findings.any(f => f.severity == "unverified") {
    "unknown"
  } else {
    "ok"
  }
  { schema_version: 1, environment: env, targets: names, status, findings, }
}

///|
fn report_text(report : Report) -> String {
  let env = report.environment
  let mut text = "zig-cross doctor: \{report.status}\nHost: \{env.host_os.unwrap_or("unknown")} \{env.host_arch.unwrap_or("unknown")}\nMoon: \{env.moon.unwrap_or("unknown")}\nCompiler: \{env.compiler.unwrap_or("unknown")}\nZig: \{env.zig.unwrap_or("unknown")}\nRuntime: \{env.runtime_mode}\nTargets: \{report.targets.join(", ")}\n"
  for f in report.findings {
    text += "[\{f.code}] \{f.severity} (\{f.targets.join(", ")}): \{f.message}\n"
    text += "  Applies: \{f.applicability}\n"
    for next in f.next_steps {
      text += "  Next: \{next.command}\n  Requires: \{next.prerequisites}\n"
    }
  }
  text
}

///|
async fn emit_notices(report : Report) -> Unit {
  for f in report.findings {
    @stdio.stderr.write(
      "zig-cross [\{f.code}] \{f.targets.join(", ")}: \{f.message}\n",
    )
    for next in f.next_steps {
      @stdio.stderr.write("  Next: \{next.command}\n")
    }
  }
}

///|
fn shell_quote(value : String) -> String {
  "'" + value.replace(old="'", new="'\"'\"'") + "'"
}

///|
fn header_flags(target : Target, env : Environment) -> String {
  if env.runtime_mode != "full" || !sync_eligible(env) {
    return ""
  }
  if target == LinuxX64 ||
    target == LinuxArm64 ||
    (target == Host && env.host_os == Some("Linux")) {
    "-include limits.h"
  } else if target == DarwinArm64 ||
    target == DarwinX64 ||
    (target == Host && env.host_os == Some("Darwin")) {
    match env.darwin_sdk {
      Some(sdk) => "-idirafter " + shell_quote(sdk + "/usr/include")
      None => ""
    }
  } else {
    ""
  }
}

///|
fn execution_allowed(env : Environment) -> Bool {
  env.runtime_mode == "full" ||
  (env.runtime_mode == "sync" && sync_eligible(env))
}
