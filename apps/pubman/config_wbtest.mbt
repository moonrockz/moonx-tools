///|
async fn config_fixture(root : String) -> String {
  let host = real_host(false)
  host.write_file(
    root + "/moon.mod",
    "name = \"owner/library\"\nversion = \"1.2.3-beta.1\"\nlicense = \"MIT\"\n",
  )
  host.write_file(root + "/moon.pkg", "")
  for pkg in ["js", "wasm"] {
    host.mkdir(root + "/" + pkg)
    host.write_file(root + "/" + pkg + "/moon.pkg", "")
  }
  for file in ["wrapper.mjs", "wasm.d.ts", "check.mjs", "check.mts"] {
    host.write_file(root + "/" + file, "")
  }
  let config : Json = {
    "schemaVersion": 1,
    "module": ".",
    "npm": { "name": "@owner/library", "access": "public", "tag": "beta" },
    "entries": {
      "js": {
        "package": "js",
        "wrapper": "wrapper.mjs",
        "declaration": { "backend": "js", "path": "js/js.d.ts" },
      },
      "wasm": {
        "package": "wasm",
        "wrapper": "wrapper.mjs",
        "declaration": "wasm.d.ts",
      },
    },
    "assets": [],
    "checks": {
      "node": ["check.mjs"],
      "browser": ["check.mjs"],
      "types": ["check.mts"],
    },
    "output": "_build/release",
  }
  write_json(host, root + "/pubman.json", config)
  root + "/pubman.json"
}

///|
fn replace_field(json : Json, key : String, value : Json) -> Json {
  guard json is Object(m) else { abort("object") }
  let copy = m.copy()
  copy[key] = value
  Json::object(copy)
}

///|
async test "release versions reject npm-normalized build metadata" {
  let host = real_host(false)
  let root = host.tmpdir(prefix="pubman-version-")
  defer @fs.rmdir(root, recursive=true)
  let path = config_fixture(root)
  for version in ["1.2.3+build.1", "1.2.3-beta.1+build.1"] {
    host.write_file(
      root + "/moon.mod",
      "name = \"owner/library\"\nversion = \"" + version + "\"\n",
    )
    let mut message = ""
    ignore(load_config(path)) catch {
      Failure(code, detail, status) => {
        assert_eq(code, "INVALID_INPUT")
        assert_eq(status, 2)
        message = detail
      }
      err => raise err
    }
    assert_true(message.contains("build metadata"))
    assert_false(@fs.exists(root + "/_build"))
  }
}

///|
async test "preview process/filesystem adapters reject effects and leave bytes unchanged" {
  let host = real_host(false)
  let root = host.tmpdir(prefix="pubman-config-")
  defer @fs.rmdir(root, recursive=true)
  let path = config_fixture(root)
  let c = load_config(path)
  let before = inventory(root)
  let denied : Host = {
    preview: true,
    mutation: action => failed("PREVIEW_MUTATION", action),
    run: async fn(cmd, _, _) {
      @async.sleep(0)
      failed("PREVIEW_PROCESS", cmd)
    },
  }
  for cmd in ["plan", "pack"] {
    let report = execute(
      { command: cmd, input: path, json: true, preview: cmd == "pack", },
      denied,
    )
    if cmd == "pack" {
      assert_eq(field(report, "dryRun"), true)
    }
  }
  let mut rejected = false
  ignore(pack(c, denied)) catch {
    _ => rejected = true
  }
  assert_true(rejected)
  assert_eq(inventory(root), before)
  assert_false(@fs.exists(c.output))
  // All write primitives, temporary directories, and locks share the policy.
  for
    kind in ["write", "mkdir", "create", "rename", "remove", "rmdir", "tmpdir"] {
    let mut rejected = false
    try {
      match kind {
        "write" => denied.write_file(root + "/new", "bad")
        "mkdir" => denied.mkdir(root + "/new")
        "create" => {
          let file = denied.create(root + "/new")
          file.close()
        }
        "rename" => denied.rename(path, path + ".moved")
        "remove" => denied.remove(path)
        "rmdir" => denied.rmdir(root)
        _ => ignore(denied.tmpdir(prefix="pubman-forbidden-"))
      }
    } catch {
      _ => rejected = true
    }
    assert_true(rejected)
  }
  assert_eq(inventory(root), before)
}

///|
async test "configuration conflicts and unsafe outputs fail without executing" {
  let host = real_host(false)
  let root = host.tmpdir(prefix="pubman-config-")
  defer @fs.rmdir(root, recursive=true)
  let path = config_fixture(root)
  let original = read_json(path)
  let entries = field(original, "entries")
  let cases = [
    replace_field(original, "unknown", true),
    replace_field(original, "schemaVersion", 2),
    replace_field(
      original,
      "npm",
      replace_field(field(original, "npm"), "version", "9.9.9"),
    ),
    replace_field(original, "output", "../escape"),
    replace_field(original, "output", "js"),
    replace_field(
      original,
      "entries",
      replace_field(
        entries,
        "wasm",
        replace_field(field(entries, "wasm"), "target", "wasm"),
      ),
    ),
    replace_field(
      original,
      "entries",
      replace_field(
        entries,
        "wasm",
        replace_field(field(entries, "wasm"), "declaration", Json::null()),
      ),
    ),
    replace_field(original, "assets", [
      { "source": "wasm.d.ts", "destination": "js/index.d.ts" },
    ]),
    replace_field(original, "assets", [
      { "source": "../outside", "destination": "outside" },
    ]),
  ]
  for c in cases {
    write_json(host, path, c)
    let mut rejected = false
    ignore(load_config(path)) catch {
      _ => rejected = true
    }
    assert_true(rejected)
  }
  write_json(host, path, original)
  host.mkdir(root + "/_build/release", recursive=true)
  host.write_file(root + "/_build/release/unrelated", "preserve")
  let mut rejected = false
  ignore(load_config(path)) catch {
    _ => rejected = true
  }
  assert_true(rejected)
  assert_eq(
    @fs.read_file(root + "/_build/release/unrelated").text(),
    "preserve",
  )
  host.rmdir(root + "/_build", recursive=true)
  @fs.symlink(target="/etc/passwd", root + "/escape")
  rejected = false
  ignore(load_config(path)) catch {
    _ => rejected = true
  }
  assert_true(rejected)
}

///|
async test "declaration dependency closure diagnoses missing and escaping references" {
  let host = real_host(false)
  let root = host.tmpdir(prefix="pubman-dts-")
  defer @fs.rmdir(root, recursive=true)
  for spec in ["./moonbit.d.ts", "../escape.d.ts", "undeclared-library"] {
    host.write_file(
      root + "/index.d.ts",
      "import type * as T from \"" + spec + "\";\n",
    )
    let mut rejected = false
    check_references(root, Json::empty_object()) catch {
      _ => rejected = true
    }
    assert_true(rejected)
  }
  host.write_file(root + "/moonbit.d.ts", "export type Int = number;\n")
  host.write_file(
    root + "/index.d.ts",
    "export type { Int } from \"./moonbit.d.ts\";\n",
  )
  check_references(root, Json::empty_object())
}

///|
async test "verify and publish previews cannot write locks receipts or invoke tools" {
  let host = real_host(false)
  let root = host.tmpdir(prefix="pubman-preview-")
  defer @fs.rmdir(root, recursive=true)
  host.mkdir(root + "/payload")
  host.write_file(root + "/.pubman-owned", "pubman bundle v1\n")
  write_json(host, root + "/payload/config.json", {
    "schemaVersion": 1,
    "checks": { "node": ["node.mjs"], "browser": ["browser.mjs"] },
  })
  write_json(host, root + "/bundle.json", {
    "schemaVersion": 1,
    "module": "owner/library",
    "npm": "@owner/library",
    "version": "1.0.0",
    "files": inventory(root + "/payload"),
  })
  let before = inventory(root)
  let denied : Host = {
    preview: true,
    mutation: action => failed("PREVIEW_MUTATION", action),
    run: async fn(cmd, _, _) {
      @async.sleep(0)
      failed("PREVIEW_PROCESS", cmd)
    },
  }
  for cmd in ["verify", "publish"] {
    let preview = execute(
      { command: cmd, input: root, json: true, preview: true, },
      denied,
    )
    assert_eq(field(preview, "dryRun"), true)
    assert_eq(field(preview, "localVerification"), Json::null())
    assert_true(
      array(field(preview, "checks")).all(c => field(c, "status") == "not-run"),
    )
    assert_eq(inventory(root), before)
  }
}

///|
async test "check failures retain the completed check results" {
  let results : Array[Json] = [{ "name": "passed", "status": "passed" }]
  let host : Host = {
    preview: false,
    mutation: _ => (),
    run: async fn(_, _, _) {
      @async.sleep(0)
      (1, "noisy stdout", "contract mismatch")
    },
  }
  let mut failed = false
  run_check(host, "node", [], "/", results, "node", "root") catch {
    _ => failed = true
  }
  assert_true(failed)
  assert_eq(results.length(), 2)
  assert_eq(field(results[1], "status"), "failed")
}

///|
async test "concurrent publication and replacement cannot acquire the bundle" {
  let host = real_host(false)
  let root = host.tmpdir(prefix="pubman-lock-")
  defer @fs.rmdir(root, recursive=true)
  let path = config_fixture(root)
  host.mkdir(root + "/_build/release", recursive=true)
  host.write_file(root + "/_build/release/.pubman-owned", "pubman bundle v1\n")
  host.write_file(root + "/_build/release/sentinel", "previous good bundle")
  let lock = host.create(
    root + "/_build/release/.operation-lock",
    allow_existing=false,
  )
  defer lock.close()
  let before = inventory(root)
  let c = load_config(path)
  let mut refused = false
  ignore(pack(c, host)) catch {
    _ => refused = true
  }
  assert_true(refused)
  assert_eq(inventory(root), before)
  for action in ["verify", "publish"] {
    refused = false
    try {
      if action == "verify" {
        ignore(verify_bundle(c.output, Json::empty_object(), host))
      } else {
        ignore(publish_bundle(c.output, Json::empty_object(), host))
      }
    } catch {
      _ => refused = true
    }
    assert_true(refused)
    assert_eq(inventory(root), before)
  }
}

///|
async test "a failed fresh build preserves the previous bundle and cannot pack stale output" {
  let host = real_host(false)
  let root = host.tmpdir(prefix="pubman-build-failure-")
  defer @fs.rmdir(root, recursive=true)
  let path = config_fixture(root)
  // Minimal source packages allow source checking/capture; the backend build is injected to fail.
  host.write_file(
    root + "/moon.mod",
    "name = \"owner/library\"\nversion = \"0.1.2\"\nlicense = \"MIT\"\nreadme = \"README.md\"\nrepository = \"https://example.com/repo\"\n",
  )
  host.write_file(root + "/README.md", "Build failure contract")
  host.write_file(root + "/lib.mbt", "pub fn value() -> Int { 1 }\n")
  let c = load_config(path)
  host.mkdir(c.output, recursive=true)
  host.write_file(c.output + "/.pubman-owned", "pubman bundle v1\n")
  host.write_file(c.output + "/sentinel", "previous good bundle")
  let before = inventory(c.output)
  let calls : Array[String] = []
  let injected : Host = {
    preview: false,
    mutation: _ => (),
    run: async fn(cmd, args, cwd) {
      calls.push(cmd + " " + args.join(" "))
      if args[0] == "--version" || args[0] == "version" {
        return (0, "pinned-tool", "")
      }
      if cmd == "moon" && args[0] == "build" {
        return (1, "", "fresh build failed")
      }
      (host.run)(cmd, args, cwd)
    },
  }
  let mut failed = false
  ignore(pack(c, injected)) catch {
    _ => failed = true
  }
  assert_true(failed)
  assert_true(calls.any(c => c.has_prefix("moon build")))
  assert_false(calls.any(c => c.has_prefix("npm pack")))
  assert_eq(inventory(c.output), before)
}

///|
async test "verification evidence binds receipt bytes and tool identities without rebuilding" {
  let host = real_host(false)
  let root = host.tmpdir(prefix="pubman-evidence-")
  defer @fs.rmdir(root, recursive=true)
  write_json(host, root + "/bundle.json", { "schemaVersion": 1 })
  let b : Json = { "files": { "check.mts": "captured-digest" } }
  let calls : Array[String] = []
  let identities : Host = {
    preview: false,
    mutation: _ => (),
    run: async fn(cmd, args, _) {
      @async.sleep(0)
      calls.push(cmd + " " + args.join(" "))
      (0, "pinned-version", "")
    },
  }
  assert_false(verification_valid(root, b, identities))
  let proof = evidence(root, b, identities)
  write_json(host, root + "/verification.json", {
    "ok": false,
    "evidence": proof,
  })
  assert_false(verification_valid(root, b, identities))
  write_json(host, root + "/verification.json", {
    "ok": true,
    "evidence": proof,
  })
  assert_true(verification_valid(root, b, identities))
  assert_true(verification_valid(root, b, identities))
  let changed : Host = {
    preview: false,
    mutation: _ => (),
    run: async fn(_, _, _) {
      @async.sleep(0)
      (0, "changed-tool", "")
    },
  }
  assert_false(verification_valid(root, b, changed))
  write_json(host, root + "/bundle.json", {
    "schemaVersion": 1,
    "changed": true,
  })
  assert_false(verification_valid(root, b, identities))
  assert_false(
    calls.any(c => {
      c.contains("build") || c.contains("install") || c.contains("publish")
    }),
  )
}

///|
async test "unsafe source ZIP entries fail before extraction or filesystem writes" {
  for
    entry in [
      "../escape", "/absolute", "a\\escape", "_build/output", ".npmrc", "symlink",
    ] {
    let writes : Array[String] = []
    let calls : Array[String] = []
    let host : Host = {
      preview: false,
      mutation: action => writes.push(action),
      run: async fn(_, args, _) {
        @async.sleep(0)
        calls.push(args.join(" "))
        if args[0] == "-Z1" {
          (0, entry + "\n", "")
        } else {
          (0, "lrwxrwxrwx symlink\n", "")
        }
      },
    }
    let mut rejected = false
    extract_source(host, "/unused/source.zip", "/unused/extracted") catch {
      _ => rejected = true
    }
    assert_true(rejected)
    assert_true(writes.is_empty())
    assert_false(calls.any(c => c.has_prefix("-q")))
  }
}

///|
async test "private modules and ambiguous module defaults fail local validation" {
  let host = real_host(false)
  let root = host.tmpdir(prefix="pubman-metadata-")
  defer @fs.rmdir(root, recursive=true)
  let path = config_fixture(root)
  let manifest = @fs.read_file(root + "/moon.mod").text()
  host.write_file(root + "/moon.mod", manifest + "private = true\n")
  let mut rejected = false
  ignore(load_config(path)) catch {
    _ => rejected = true
  }
  assert_true(rejected)
  host.write_file(root + "/moon.mod", manifest)
  host.write_file(root + "/moon.work", "members = [\".\", \"../sibling\"]\n")
  let raw = read_json(path)
  write_json(host, path, replace_field(raw, "module", Json::null()))
  rejected = false
  ignore(load_config(path)) catch {
    _ => rejected = true
  }
  assert_true(rejected)
}
