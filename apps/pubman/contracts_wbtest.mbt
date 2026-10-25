///|
test "argparse declares required inputs and all mutating previews" {
  for c in commands {
    let flag = if c.mutates { ["--dry-run"] } else { [] }
    let argv = [c.name, "--" + c.input, "input", "--json"]
    argv.append(flag)
    let r = request(argv)
    assert_eq(r.command, c.name)
    assert_eq(r.input, "input")
    assert_eq(r.preview, c.mutates)
    assert_true(r.json)
    let before = ["--json", c.name, "--" + c.input, "input"]
    before.append(flag)
    assert_true(request(before).json)
    let mut rejected = false
    ignore(request([c.name, "--wrong"])) catch {
      _ => rejected = true
    }
    assert_true(rejected)
    rejected = false
    ignore(request([c.name])) catch {
      _ => rejected = true
    }
    assert_true(rejected)
    rejected = false
    ignore(request([c.name, "--" + c.input])) catch {
      _ => rejected = true
    }
    assert_true(rejected)
  }
}

///|
test "manifest strings, comments, and unsupported expressions" {
  let m = metadata(
    (
      #|// name = "wrong/name"
      #|name = "owner/library" /* version = "bad" */
      #|version = "1.2.3-beta.1+build"
      #|description = "A \"quoted\" name // not a comment\n世界"
      #|license = "MIT"
      #|import { "owner/dependency@1.0.0", }
    ),
  )
  assert_eq(string_field(m, "name"), "owner/library")
  assert_eq(
    string_field(m, "description"),
    "A \"quoted\" name // not a comment\n世界",
  )
  assert_true(semver(string_field(m, "version")))
  for
    text in [
      "name = foo()", "version = [\"1\"]", "name = \"owner/lib\"\nname = \"other/lib\"",
      "import { \"x/y\": { path: \"../local\" } }",
    ] {
    let mut rejected = false
    ignore(metadata(text)) catch {
      _ => rejected = true
    }
    assert_true(rejected)
  }
  for v in ["1.2.3", "0.0.0", "1.2.3-beta.1", "1.2.3-beta-x+build.01"] {
    assert_true(semver(v))
  }
  for v in ["1.2", "01.2.3", "1.2.3-", "1.2.3-01", "1.2.3+", "1.2.3/a"] {
    assert_false(semver(v))
  }
}

///|
test "paths and package identities" {
  for
    p in [
      "../secret", "/tmp/secret", "a/../secret", "a//b", "a\\b", ".", "a/./b",
    ] {
    let mut rejected = false
    safe_relative(p) catch {
      _ => rejected = true
    }
    assert_true(rejected)
  }
  assert_true(valid_name("@scope/package", true))
  assert_true(valid_name("owner/module", false))
  for name in ["Scope/Pkg", "../escape", "a/b/c", "a@bad", "@scope", ""] {
    assert_false(valid_name(name, true))
  }
}

///|
async test "preview host rejects every subprocess" {
  let host = real_host(true)
  let mut rejected = false
  ignore(host.call("moon", ["build"], "/")) catch {
    Failure(code, _, _) => {
      assert_eq(code, "PREVIEW_MUTATION")
      rejected = true
    }
    _ => ()
  }
  assert_true(rejected)
}

///|
test "retry classification" {
  assert_true(transient("503 temporarily unavailable"))
  assert_true(transient("ECONNRESET"))
  assert_false(transient("401 authentication timeout"))
  assert_false(transient("403 permission denied timeout"))
  assert_false(transient("409 content conflict timeout"))
  assert_false(safe_upload_retry("timeout after upload"))
  assert_true(safe_upload_retry("ECONNREFUSED"))
  let b : Json = { "version": "1.0.0-beta.1", "integrity": "sha512-test" }
  let mut rejected = false
  ignore(publish_tag(b)) catch {
    _ => rejected = true
  }
  assert_true(rejected)
  assert_eq(publish_tag({ "version": "1.0.0" }), "latest")
  assert_true(
    npm_matches(
      {
        "dist": { "integrity": "sha512-test" },
        "dist-tags": { "beta": "1.0.0-beta.1" },
      },
      b,
      "beta",
    ),
  )
}
