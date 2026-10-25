///|
struct FakeRegistry {
  mut mode : String
  mut moon : Bool
  mut npm : Bool
  mut uploads : Int32
  mut queries : Int32
  calls : Array[String]
}

///|
fn FakeRegistry::new(mode : String) -> FakeRegistry {
  { mode, moon: false, npm: false, uploads: 0, queries: 0, calls: [], }
}

///|
fn FakeRegistry::host(self : FakeRegistry) -> Host {
  {
    preview: false,
    mutation: _ => (),
    run: async fn(cmd, args, cwd) {
      self.calls.push(cmd + " " + args.join(" ") + " cwd=" + cwd)
      if cmd == "unzip" || cmd == "zip" {
        return (real_host(false).run)(cmd, args, cwd)
      }
      if args[0] == "config" {
        return (
          0,
          if self.mode == "override" {
            "https://private.example"
          } else {
            "https://registry.npmjs.org"
          },
          "",
        )
      }
      if args[0] == "whoami" {
        if self.mode == "auth" || self.mode.has_prefix("oidc") {
          return (1, "", "401 token=npm_secret")
        }
        return (
          0,
          if cmd == "moon" {
            "Logged in as owner\n"
          } else {
            "owner\n"
          },
          "",
        )
      }
      if args[0] == "view" && cmd == "moon" {
        self.queries += 1
        return if self.moon {
          (
            0, "{\"status\":\"success\",\"result\":{\"module\":\"owner/library\",\"release\":{\"version\":\"1.0.0\"}}}",
            "",
          )
        } else {
          (1, "", "404 not found")
        }
      }
      if args[0] == "view" && cmd == "npm" {
        self.queries += 1
        if self.npm {
          let info : Json = {
            "name": "@owner/library",
            "version": "1.0.0",
            "dist": {
              "integrity": if self.mode == "content" {
                "sha512-wrong"
              } else {
                "sha512-exact"
              },
            },
            "dist-tags": {
              "latest": if self.mode == "tag" {
                "0.9.0"
              } else {
                "1.0.0"
              },
            },
          }
          return (0, info.stringify(), "")
        }
        return (1, "", "E404 not found")
      }
      if args[0] == "publish" && args.contains("--dry-run") {
        return if self.mode == "oidc-ok" {
          (0, "", "npm verbose oidc Successfully retrieved and set token")
        } else if self.mode == "oidc-denied" {
          (0, "", "This command requires you to be logged in (dry-run)")
        } else {
          (0, "{}", "")
        }
      }
      if args[0] == "publish" {
        self.uploads += 1
        if self.mode == "refused" {
          return (1, "", "ECONNREFUSED")
        }
        if cmd == "moon" {
          self.moon = true
          return if self.mode == "moon-lost" {
            (1, "", "timeout after upload")
          } else {
            (0, "accepted\n", "")
          }
        }
        if self.mode == "npm-fail" {
          return (1, "", "403 permission denied npm_secret")
        }
        self.npm = true
        return if self.mode == "npm-lost" {
          (1, "", "timeout after upload")
        } else {
          (0, "accepted\n", "")
        }
      }
      failed(
        "FAKE_COMMAND",
        "unexpected command: " + cmd + " " + args.join(" "),
      )
    },
  }
}

///|
async fn fake_publication(
  root : String,
  registry : FakeRegistry,
) -> Publication {
  let host = real_host(false)
  host.mkdir(root + "/payload", recursive=true)
  host.mkdir(root + "/source")
  host.write_file(
    root + "/source/moon.mod",
    "name = \"owner/library\"\nversion = \"1.0.0\"\n",
  )
  let inv = inventory(root + "/source")
  write_json(host, root + "/payload/source-inventory.json", inv)
  ignore(
    host.checked(
      "zip",
      ["-q", "-r", root + "/payload/source.zip", "."],
      root + "/source",
    ),
  )
  host.write_file(root + "/payload/package.tgz", "exact npm artifact")
  let b : Json = {
    "module": "owner/library",
    "npm": "@owner/library",
    "version": "1.0.0",
    "integrity": "sha512-exact",
    "files": {
      "source.zip": file_digest(root + "/payload/source.zip"),
      "package.tgz": file_digest(root + "/payload/package.tgz"),
    },
  }
  {
    host: registry.host(),
    root,
    bundle: b,
    digest: "same-bundle",
    outcomes: {
      "moon": { "status": "pending" },
      "npm": { "status": "pending" },
    },
  }
}

///|
async test "publication preflight refuses before any upload" {
  for mode in ["auth", "content", "tag", "existing-moon", "override"] {
    let root = real_host(false).tmpdir(prefix="pubman-fake-")
    defer @fs.rmdir(root, recursive=true)
    let registry = FakeRegistry::new(mode)
    if mode == "content" || mode == "tag" {
      registry.npm = true
    }
    if mode == "existing-moon" {
      registry.moon = true
    }
    let p = fake_publication(root, registry)
    let mut refused = false
    publish_state(p, registry.host()) catch {
      _ => refused = true
    }
    assert_true(refused)
    assert_eq(registry.uploads, 0)
  }
}

///|
async test "partial result resumes only unfinished registry and exact tarball" {
  let root = real_host(false).tmpdir(prefix="pubman-fake-")
  defer @fs.rmdir(root, recursive=true)
  let registry = FakeRegistry::new("npm-fail")
  let p = fake_publication(root, registry)
  let mut failed = false
  publish_state(p, registry.host()) catch {
    _ => failed = true
  }
  assert_true(failed)
  assert_eq(
    field(field(field(p.report(), "registries"), "moon"), "status"),
    "published",
  )
  assert_eq(
    field(field(field(p.report(), "registries"), "npm"), "status"),
    "failed",
  )
  assert_eq(registry.uploads, 2)
  registry.mode = "success"
  publish_state(p, registry.host())
  assert_eq(registry.uploads, 3)
  assert_eq(
    field(field(field(p.report(), "registries"), "moon"), "status"),
    "already-published",
  )
  assert_true(
    registry.calls.any(c => {
      c.contains(
        "npm publish " +
        root +
        "/payload/package.tgz --ignore-scripts --access=public --registry=https://registry.npmjs.org --tag latest",
      )
    }),
  )
  assert_false(
    registry.calls.any(c => {
      c.contains("moon build") ||
      c.contains("moon install") ||
      c.contains("moon package")
    }),
  )
  publish_state(p, registry.host())
  assert_eq(registry.uploads, 3)
}

///|
async test "lost responses reconcile npm and preserve Mooncakes uncertainty" {
  for mode in ["npm-lost", "moon-lost"] {
    let root = real_host(false).tmpdir(prefix="pubman-fake-")
    defer @fs.rmdir(root, recursive=true)
    let registry = FakeRegistry::new(mode)
    let p = fake_publication(root, registry)
    let mut failed = false
    publish_state(p, registry.host()) catch {
      _ => failed = true
    }
    assert_eq(failed, mode == "moon-lost")
    if mode == "moon-lost" {
      assert_eq(registry.uploads, 1)
      assert_eq(
        field(field(field(p.report(), "registries"), "moon"), "status"),
        "uncertain",
      )
      publish_state(p, registry.host()) catch {
        _ => ()
      }
      assert_eq(registry.uploads, 1)
    } else {
      assert_eq(registry.uploads, 2)
      assert_eq(
        field(field(field(p.report(), "registries"), "npm"), "status"),
        "already-published",
      )
    }
  }
}

///|
async test "bounded upload retries reconcile before retry" {
  let root = real_host(false).tmpdir(prefix="pubman-fake-")
  defer @fs.rmdir(root, recursive=true)
  let registry = FakeRegistry::new("refused")
  let p = fake_publication(root, registry)
  publish_state(p, registry.host()) catch {
    _ => ()
  }
  assert_eq(registry.uploads, 4)
  assert_eq(registry.queries, 6)
  assert_false(
    redact("permission denied npm_aSecretToken token=secret").contains("Secret"),
  )
}

///|
async test "npm OIDC is proven by the installed CLI before package uploads" {
  assert_false(oidc_available(Map([])))
  assert_true(
    oidc_available({
      "GITHUB_ACTIONS": "true",
      "ACTIONS_ID_TOKEN_REQUEST_URL": "https://example",
      "ACTIONS_ID_TOKEN_REQUEST_TOKEN": "secret",
    }),
  )
  assert_true(oidc_available({ "GITLAB_CI": "true", "NPM_ID_TOKEN": "token" }))
  for mode in ["oidc-ok", "oidc-denied"] {
    let root = real_host(false).tmpdir(prefix="pubman-oidc-")
    defer @fs.rmdir(root, recursive=true)
    let registry = FakeRegistry::new(mode)
    let p = fake_publication(root, registry)
    let mut authenticated = false
    try {
      authenticated = npm_auth(p, registry.host(), true)
    } catch {
      _ => ()
    }
    assert_eq(authenticated, mode == "oidc-ok")
    assert_eq(registry.uploads, 0)
    assert_true(
      registry.calls.any(c => {
        c.contains("--dry-run --ignore-scripts --access=public --json")
      }),
    )
  }
}
