///|
fn operations(command : String) -> Array[String] {
  match command {
    "pack" =>
      [
        "capture-source", "capture-inputs", "resolve-dependencies", "build-js", "build-wasm-gc",
        "assemble-typed-entries", "npm-pack", "commit-bundle",
      ]
    "verify" =>
      [
        "install-tarball", "node-contracts", "typescript-NodeNext", "typescript-Bundler",
        "browser-contracts", "write-verification-receipt",
      ]
    "publish" =>
      [
        "lock-bundle", "validate-verification", "registry-preflight", "extract-source",
        "compare-source-inventory", "publish-mooncakes", "write-mooncakes-receipt",
        "publish-npm-tarball", "write-npm-receipt",
      ]
    _ => []
  }
}

///|
async fn execute(r : Request, host : Host) -> Json {
  if r.command == "plan" || r.command == "pack" {
    let c = load_config(r.input) catch {
      Failure(_, _, _) as err => raise err
      err => invalid("configuration: " + err.to_string())
    }
    if r.command == "plan" {
      return c.plan()
    }
    if r.preview {
      return {
        "dryRun": true,
        "plan": c.plan(),
        "operations": json_strings(operations(r.command)),
        "checks": preview_checks("pack", Json::empty_object()),
        "prerequisites": [
          "compilation", "installed tools", "dependency resolution",
        ],
      }
    }
    return pack(c, host)
  }
  let (root, b) = bundle_read(r.input)
  if r.preview {
    if r.command == "publish" {
      ignore(publish_tag(b))
    }
    let prerequisites = if r.command == "publish" {
      [
        "current successful verification", "authentication for both registries",
        "version availability", "npm tag",
      ]
    } else {
      ["installed Node, TypeScript and Playwright", "installed Chromium"]
    }
    return {
      "dryRun": true,
      "bundle": root,
      "identity": b,
      "operations": json_strings(operations(r.command)),
      "checks": preview_checks(
        r.command,
        field(read_json(root + "/payload/config.json"), "checks"),
      ),
      "prerequisites": json_strings(prerequisites),
      "localVerification": if @fs.exists(root + "/verification.json") {
        read_json(root + "/verification.json")
      } else {
        Json::null()
      },
      "destinations": {
        "mooncakes": "https://mooncakes.io",
        "npm": "https://registry.npmjs.org",
      },
    }
  }
  if r.command == "verify" {
    verify_bundle(root, b, host)
  } else {
    publish_bundle(root, b, host)
  }
}

///|
fn preview_checks(command : String, checks : Json) -> Json raise {
  let names = if command == "pack" {
    [
      "source-inventory", "build-js", "build-wasm-gc", "declaration-closure", "npm-inventory",
    ]
  } else if command == "publish" {
    [
      "verification-evidence", "moon-auth", "npm-auth", "moon-availability", "npm-integrity-and-tag",
    ]
  } else {
    let all = ["typescript-NodeNext", "typescript-Bundler"]
    for kind in ["node", "browser"] {
      for file in strings(field(checks, kind)) {
        all.push(kind + ":" + file)
      }
    }
    all
  }
  Json::array(names.map(name => { "name": name, "status": "not-run" }))
}
