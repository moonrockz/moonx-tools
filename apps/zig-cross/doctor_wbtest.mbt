///|
fn stock_environment(mode : String) -> Environment {
  {
    host_os: Some("Linux"),
    host_arch: Some("x86_64"),
    zig_cross: version_text(),
    moon: Some("0.1.20261023"),
    compiler: Some(assessed_compiler),
    zig: Some("0.17.0"),
    toolchain_root: Some("/toolchain"),
    runtime_fingerprint: Some(stock_runtime_fingerprint),
    runtime_mode: mode,
    darwin_sdk: None,
    toolchain_overrides: [],
  }
}

///|
test "doctor parser defaults deduplicates and rejects unsupported forms" {
  assert_eq(
    parse_args(["doctor", "--json", "host", "host", "linux-x64"]),
    Ok(Doctor(targets=[Host, LinuxX64], json=true)),
  )
  assert_eq(
    parse_args(["doctor", "windows-x64", "--json"]),
    Ok(Doctor(targets=[WindowsX64], json=true)),
  )
  guard parse_args(["doctor"]) is Ok(Doctor(targets~, json~)) else {
    abort("doctor")
  }
  assert_eq(targets.length(), 6)
  assert_false(json)
  assert_true(parse_args(["doctor", "--"]) is Err(_))
  assert_true(parse_args(["doctor", "--bogus", "--json"]) is Err(_))
  assert_true(parse_args(["doctor", "nope"]) is Err(_))
}

///|
test "version fields and compiler paths preserve spaced paths" {
  let text = "moon 0.1.20261023 (3778465 2026-10-23) /opt/tool chain/bin/moon\nmoonc v0.10.17+d971670cd (2026-10-23) /opt/tool chain/bin/moonc\n"
  assert_eq(version_field(text, "moon "), Some("0.1.20261023"))
  assert_eq(version_field(text, "moonc v"), Some(assessed_compiler))
  assert_eq(compiler_root(text), Some("/opt/tool chain"))
  assert_eq(compiler_root("moonc malformed"), None)
  assert_eq(version_field("not a version", "moon "), None)
}

///|
test "known full runtime findings match actual header selection" {
  let env = stock_environment("full")
  let result = report(env, [LinuxX64, DarwinArm64, WindowsX64])
  assert_eq(result.status, "error")
  assert_eq(result.findings.map(f => f.code), [
    "ZC_LINUX_NAME_MAX", "ZC_DARWIN_VNODE_HEADER", "ZC_WINDOWS_MSVC_RUNTIME", "ZC_WINDOWS_OSSTRING",
  ])
  assert_eq(result.findings[0].severity, "warning")
  assert_eq(result.findings[1].severity, "error")
  assert_eq(header_flags(LinuxX64, env), "-include limits.h")
  assert_eq(header_flags(DarwinArm64, env), "")
  let mac = { ..env, host_os: Some("Darwin"), darwin_sdk: Some("/SDK's path"), }
  assert_true(header_flags(Host, mac).contains("-idirafter"))
  assert_eq(report(mac, [Host]).status, "warning")
}

///|
test "explicit sync mode suppresses full runtime defects but retains Windows warning" {
  let env = stock_environment("sync")
  let result = report(env, [WindowsX64, LinuxX64])
  assert_eq(result.status, "warning")
  assert_eq(result.findings.map(f => f.code), [
    "ZC_COMPATIBILITY_MODE", "ZC_WINDOWS_OSSTRING",
  ])
  assert_true(result.findings[0].message.contains("thread pools"))
  assert_true(execution_allowed(env))
  assert_eq(header_flags(LinuxX64, env), "")
  assert_false(
    report(stock_environment("full"), [LinuxX64]).findings.any(f => {
      f.code == "ZC_COMPATIBILITY_MODE"
    }),
  )
}

///|
test "unknown and custom toolchains never inherit the whitelist" {
  let env = stock_environment("sync")
  for
    unknown in [
      { ..env, compiler: Some("0.10.99+future"), },
      { ..env, runtime_fingerprint: Some("custom"), },
      { ..env, moon: Some("custom"), },
      { ..env, zig: Some("0.18.0"), },
    ] {
    assert_false(execution_allowed(unknown))
    let result = report(unknown, [LinuxX64])
    assert_true(result.findings.any(f => f.code == "ZC_SYNC_UNAVAILABLE"))
    assert_false(result.findings.any(f => f.code == "ZC_LINUX_NAME_MAX"))
  }
  let result = report(
    { ..env, compiler: Some("custom"), runtime_mode: "full", },
    [LinuxX64],
  )
  assert_eq(result.status, "unknown")
  assert_true(execution_allowed(result.environment))
  assert_false(execution_allowed({ ..env, runtime_mode: "typo", }))
}

///|
test "report JSON has stable envelope and structured usage errors" {
  let result = report(stock_environment("full"), [], usage="bad target")
  let parsed = @json.parse(@json.to_json(result).stringify())
  guard parsed is Object(fields) else { abort("report object") }
  assert_true(fields["schema_version"] is Number(1, ..))
  assert_true(fields["status"] is String("error"))
  assert_eq(result.findings[0].code, "ZC_USAGE")
  assert_true(report_text(result).contains("bad target"))
}

///|
test "missing tools are errors and old pin is assessed without new runtime defects" {
  let env = stock_environment("full")
  let missing = report({ ..env, compiler: None, moon: None, zig: None, }, [Host])
  assert_eq(missing.status, "error")
  assert_eq(
    missing.findings.filter(f => f.code == "ZC_TOOL_MISSING").length(),
    3,
  )
  let old = {
    ..env,
    compiler: Some("0.10.15+943464bfa"),
    moon: Some("0.1.20261012"),
    runtime_fingerprint: Some(
      "0c0a95f4fa7e59715b57ec30962c34f642a5caff0b28535c5933278c691fd23c",
    ),
  }
  assert_eq(report(old, [LinuxX64]).status, "ok")
  assert_eq(report(old, [WindowsX64]).status, "warning")
}
