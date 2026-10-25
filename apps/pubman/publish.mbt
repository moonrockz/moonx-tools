///|
let npm_registry : String = "https://registry.npmjs.org"

///|
fn transient(text : String) -> Bool {
  let text = text.to_lower()
  if [
      "401", "403", "409", "eauth", "eperm", "einvalid", "forbidden", "permission",
      "unauthorized", "duplicated", "e404",
    ].any(w => text.contains(w)) {
    return false
  }
  [
    "timeout", "timed out", "connection reset", "connection refused", "econnreset",
    "econnrefused", "eai_again", "502", "503", "504", "429",
  ].any(w => text.contains(w))
}

///|
/// A retry is safe only for a proven pre-upload refusal. Other transient
/// upload errors must first be reconciled against the registry.
fn safe_upload_retry(text : String) -> Bool {
  let text = text.to_lower()
  text.contains("connection refused") ||
  text.contains("econnrefused") ||
  text.contains("eai_again")
}

///|
async fn query(
  host : Host,
  cmd : String,
  args : Array[String],
  cwd : String,
) -> (Int32, String, String) {
  let mut result = host.call(cmd, args, cwd)
  for attempt in 0..<3 {
    if result.0 == 0 || !transient(result.1 + result.2) {
      break
    }
    eprintln("retrying registry query \{attempt+2}/4")
    @async.sleep([50, 200, 500][attempt])
    result = host.call(cmd, args, cwd)
  }
  result
}

///|
async fn check_registry_destinations() -> Unit {
  if @env.get_env_var("MOONCAKES_REGISTRY") is Some(r) &&
    r.trim_end(chars="/") != "https://mooncakes.io" {
    invalid("MOONCAKES_REGISTRY must select the public Mooncakes registry")
  }
  let home = @env.get_env_var("MOON_HOME").unwrap_or(
    @env.get_env_var("HOME").unwrap_or("") + "/.moon",
  )
  if @fs.exists(home + "/config.json") {
    let config = read_json(home + "/config.json")
    let api = opt_string(
      config,
      "api",
      opt_string(config, "registry", "https://mooncakes.io"),
    )
    if api.trim_end(chars="/") != "https://mooncakes.io" {
      invalid("Moon config.json redirects the public registry")
    }
    for
      (key, expected) in [
        ("index", "https://mooncakes.io/git/index"),
        ("download", "https://download.mooncakes.io"),
      ] {
      if opt_string(config, key, expected).trim_end(chars="/") != expected {
        invalid("Moon registry override: " + key)
      }
    }
  }
}

///|
fn npm_args(args : Array[String], name : String) -> Array[String] {
  if name.has_prefix("@") {
    args.push(
      "--" +
      name.split("/").next().unwrap_or("").to_owned() +
      ":registry=" +
      npm_registry,
    )
  }
  args
}

///|
async fn npm_destinations(host : Host, name : String, cwd : String) -> Unit {
  let keys = ["registry"]
  if name.has_prefix("@") {
    keys.push(name.split("/").next().unwrap_or("").to_owned() + ":registry")
  }
  for key in keys {
    let (code, out, err) = host.call("npm", ["config", "get", key], cwd)
    let value = out.trim().trim_end(chars="/").to_owned()
    if code != 0 {
      failed(
        "REGISTRY_CONFIG",
        "cannot inspect npm registry configuration: " + redact(err),
      )
    }
    if value != "undefined" && value != "null" && value != npm_registry {
      invalid(
        "npm registry override for " +
        key +
        ": only the public registry is supported",
      )
    }
  }
}

///|
async fn moon_exists(host : Host, b : Json, cwd : String) -> Bool {
  let (code, out, err) = query(
    host,
    "moon",
    [
      "view",
      string_field(b, "module") + "@" + string_field(b, "version"),
      "--json",
    ],
    cwd,
  )
  if code == 0 {
    let report = @json.parse(out)
    if field(report, "status") != "success" {
      failed("REGISTRY_QUERY", "Mooncakes did not return success")
    }
    let result = field(report, "result")
    if field(result, "module") != field(b, "module") ||
      field(field(result, "release"), "version") != field(b, "version") {
      failed("REGISTRY_IDENTITY", "Mooncakes returned another module/version")
    }
    return true
  }
  if (out + err).to_lower().contains("404 not found") {
    return false
  }
  failed(
    "REGISTRY_QUERY",
    "Mooncakes version query failed: " + redact(out + err),
  )
}

///|
async fn npm_version(host : Host, b : Json, cwd : String) -> Json {
  let (code, out, err) = query(
    host,
    "npm",
    npm_args(
      [
        "view",
        string_field(b, "npm") + "@" + string_field(b, "version"),
        "--json",
        "--registry=" + npm_registry,
      ],
      string_field(b, "npm"),
    ),
    cwd,
  )
  if code == 0 {
    let info = @json.parse(out)
    if field(info, "name") != field(b, "npm") ||
      field(info, "version") != field(b, "version") {
      failed("REGISTRY_IDENTITY", "npm returned another package/version")
    }
    return info
  }
  if (out + err).contains("E404") {
    return Json::null()
  }
  failed("REGISTRY_QUERY", "npm version query failed: " + redact(out + err))
}

///|
fn npm_matches(info : Json, b : Json, tag : String) -> Bool raise {
  if info == Json::null() {
    return false
  }
  if field(field(info, "dist"), "integrity") != field(b, "integrity") {
    failed("CONTENT_CONFLICT", "npm version exists with different integrity")
  }
  if field(field(info, "dist-tags"), tag) != field(b, "version") {
    failed(
      "TAG_CONFLICT", "npm artifact matches, but requested tag points elsewhere; reconcile externally",
    )
  }
  true
}

///|
fn publish_tag(b : Json) -> String raise {
  let v = string_field(b, "version")
  let tag = opt_string(b, "tag", "")
  if v.split("+").next().unwrap_or("").contains("-") && tag.is_empty() {
    invalid("prereleases require an explicit npm tag")
  }
  let tag = if tag.is_empty() { "latest" } else { tag }
  if !identifiers(tag, false) || tag.has_prefix("-") || semver(tag) {
    invalid("invalid npm tag")
  }
  tag
}

///|
struct Publication {
  host : Host
  root : String
  bundle : Json
  digest : String
  outcomes : Map[String, Json]
}

///|
fn Publication::report(self : Publication) -> Json {
  {
    "dryRun": false,
    "bundle": self.root,
    "registries": Json::object(self.outcomes),
    "recovery": "Preserve this bundle and receipts. Resolve conflicts/uncertainty externally, then rerun pubman publish --bundle " +
    self.root,
  }
}

///|
async fn Publication::record(
  self : Publication,
  registry : String,
  status : String,
  message : String,
) -> Unit {
  let receipt : Json = {
    "schemaVersion": 1,
    "bundleDigest": self.digest,
    "status": status,
    "artifactDigest": string_field(
      field(self.bundle, "files"),
      if registry == "moon" {
        "source.zip"
      } else {
        "package.tgz"
      },
    ),
    "message": redact(message),
  }
  write_json(
    self.host,
    self.root + "/publication-" + registry + ".json",
    receipt,
  )
  self.outcomes[registry] = receipt
}

///|
async fn Publication::confirmed(self : Publication, registry : String) -> Bool {
  let path = self.root + "/publication-" + registry + ".json"
  if !@fs.exists(path) {
    return false
  }
  let receipt = read_json(path)
  if field(receipt, "bundleDigest") != Json::string(self.digest) ||
    field(receipt, "artifactDigest") !=
    field(
      field(self.bundle, "files"),
      if registry == "moon" {
        "source.zip"
      } else {
        "package.tgz"
      },
    ) {
    failed(
      "STALE_PUBLICATION", "publication receipt belongs to different artifacts",
    )
  }
  let status = string_field(receipt, "status")
  status == "published" || status == "already-published"
}

///|
async fn publish_state(p : Publication, host : Host) -> Unit {
  let b = p.bundle
  let tag = publish_tag(b)
  // All preflight, including both credentials, completes before either write.
  npm_destinations(host, string_field(b, "npm"), p.root)
  let npm_checked = npm_auth(p, host, oidc_available(@env.get_env_vars()))
  let (mc, mo, _) = query(host, "moon", ["whoami"], p.root)
  let owner = string_field(b, "module")
    .split("/")
    .next()
    .unwrap_or("")
    .to_owned()
  if mc != 0 || mo.trim() != "Logged in as " + owner {
    failed(
      "AUTH_REQUIRED", "moon login must provide the module owner's identity",
    )
  }
  let exists = moon_exists(host, b, p.root)
  let moon_confirmed = p.confirmed("moon")
  if exists && !moon_confirmed {
    failed(
      "MOONCAKES_UNCERTAIN", "Mooncakes version exists without matching successful receipt; reconcile externally",
    )
  }
  if moon_confirmed && !exists {
    failed(
      "REGISTRY_CONFLICT", "Mooncakes receipt exists but registry version is absent",
    )
  }
  let npm_info = npm_version(host, b, p.root)
  let npm_done = npm_matches(npm_info, b, tag)
  if !npm_done && !npm_checked {
    let (code, out, err) = npm_probe(p, host)
    if code != 0 {
      failed(
        "NPM_PREFLIGHT",
        "npm rejected the captured candidate before registry writes: " +
        redact(out + err),
      )
    }
  }
  if exists {
    p.record(
      "moon", "already-published", "confirmed by receipt and registry existence",
    )
  }
  if npm_done {
    p.record(
      "npm", "already-published", "confirmed exact integrity and requested tag",
    )
  }
  if !exists {
    let work = host.tmpdir(prefix="pubman-publish-")
    defer host.rmdir(work, recursive=true)
    let source = work + "/source"
    extract_source(host, p.root + "/payload/source.zip", source)
    if inventory(source) != read_json(p.root + "/payload/source-inventory.json") {
      failed("SOURCE_INVENTORY", "Mooncakes staging inventory differs")
    }
    // Inventory round-trip without a compiler or dependency resolver.
    ignore(
      host.checked("zip", ["-q", "-r", work + "/repacked.zip", "."], source),
    )
    extract_source(host, work + "/repacked.zip", work + "/repacked")
    if inventory(work + "/repacked") !=
      read_json(p.root + "/payload/source-inventory.json") {
      failed("SOURCE_INVENTORY", "Mooncakes repack differs")
    }
    // Record intent before upload so a crash cannot look like a safe first attempt.
    p.record(
      "moon", "uncertain", "upload starting; a missing success response requires external reconciliation",
    )
    for attempt in 0..<4 {
      let (code, out, err) = host.call(
        "moon",
        ["publish", "--frozen", "--target-dir", work + "/publish-output"],
        source,
      )
      let message = redact(out + err)
      eprintln(message.trim_end())
      if code == 0 {
        p.record("moon", "published", "Mooncakes accepted captured source")
        break
      }
      let after = moon_exists(host, b, p.root) catch { _ => true }
      if after || (transient(message) && !safe_upload_retry(message)) {
        p.record("moon", "uncertain", message)
        failed(
          "PUBLICATION_UNCERTAIN", "Mooncakes upload may have succeeded; preserve receipts and reconcile externally",
        )
      }
      if !transient(message) || attempt == 3 {
        p.record("moon", "failed", message)
        failed(
          "PUBLICATION_FAILED", "Mooncakes refused publication; correct authentication/content and rerun the same bundle",
        )
      }
      @async.sleep([50, 200, 500][attempt])
    }
  }
  if !npm_done {
    p.record(
      "npm", "uncertain", "upload starting; reconcile integrity and tag before retry",
    )
    for attempt in 0..<4 {
      let (code, out, err) = host.call(
        "npm",
        npm_args(
          [
            "publish",
            p.root + "/payload/package.tgz",
            "--ignore-scripts",
            "--access=public",
            "--registry=" + npm_registry,
            "--tag",
            tag,
          ],
          string_field(b, "npm"),
        ),
        p.root,
      )
      let message = redact(out + err)
      eprintln(message.trim_end())
      // Even success must confirm the registry artifact and tag.
      let after = npm_version(host, b, p.root) catch {
        _ => {
          p.record("npm", "uncertain", "cannot reconcile upload response")
          failed("PUBLICATION_UNCERTAIN", "npm response cannot be reconciled")
        }
      }
      if npm_matches(after, b, tag) {
        p.record(
          "npm",
          if code == 0 {
            "published"
          } else {
            "already-published"
          },
          "exact integrity and tag confirmed",
        )
        break
      }
      if !transient(message) || attempt == 3 {
        p.record("npm", if code == 0 { "uncertain" } else { "failed" }, message)
        failed(
          "PUBLICATION_FAILED", "npm not confirmed; preserve Mooncakes receipt and rerun the same bundle",
        )
      }
      @async.sleep([50, 200, 500][attempt])
    }
  }
}

///|
async fn publish_bundle(root : String, b : Json, host : Host) -> Json {
  let lock = host.create(root + "/.operation-lock", allow_existing=false)
  defer lock.close()
  defer host.remove(root + "/.operation-lock")
  let (_, fresh) = bundle_read(root)
  if fresh != b || !verification_valid(root, b, host) {
    failed(
      "VERIFICATION_REQUIRED", "pack and verify the exact bundle with current tools before publication",
    )
  }
  check_registry_destinations()
  let p : Publication = {
    host,
    root,
    bundle: b,
    digest: file_digest(root + "/bundle.json"),
    outcomes: {
      "moon": { "status": "pending" },
      "npm": { "status": "pending" },
    },
  }
  publish_state(p, host) catch {
    Failure(code, message, status) =>
      raise Partial(code, message, status, p.report())
    err =>
      raise Partial(
        "PUBLICATION_UNCERTAIN",
        redact(err.to_string()),
        1,
        p.report(),
      )
  }
  p.report()
}

///|
fn oidc_available(env : Map[String, String]) -> Bool {
  let token = env.get("NPM_ID_TOKEN").unwrap_or("") != ""
  (
    env.get("GITHUB_ACTIONS") == Some("true") &&
    (
      token ||
      (
        env.contains("ACTIONS_ID_TOKEN_REQUEST_URL") &&
        env.contains("ACTIONS_ID_TOKEN_REQUEST_TOKEN")
      )
    )
  ) ||
  (
    (
      env.get("GITLAB_CI") == Some("true") ||
      env.get("CIRCLECI") == Some("true")
    ) &&
    token
  )
}

///|
/// This is actual-publication preflight, never pubman's read-only preview.
/// npm 11.11 exchanges OIDC in its publish implementation, including when
/// upload is disabled. Delegate that exchange without persisting credentials.
async fn npm_probe(p : Publication, host : Host) -> (Int32, String, String) {
  let result = query(
    host,
    "npm",
    npm_args(
      [
        "publish",
        p.root + "/payload/package.tgz",
        "--dry-run",
        "--ignore-scripts",
        "--access=public",
        "--json",
        "--registry=" + npm_registry,
        "--tag",
        publish_tag(p.bundle),
        "--loglevel=verbose",
      ],
      string_field(p.bundle, "npm"),
    ),
    p.root,
  )
  if !result.1.is_empty() {
    eprintln(redact(result.1).trim_end())
  }
  if !result.2.is_empty() {
    eprintln(redact(result.2).trim_end())
  }
  result
}

///|
async fn npm_auth(p : Publication, host : Host, oidc : Bool) -> Bool {
  let (code, out, err) = query(
    host,
    "npm",
    ["whoami", "--registry=" + npm_registry],
    p.root,
  )
  if code == 0 && !out.trim().is_empty() {
    return false
  }
  if oidc {
    let (status, output, error) = npm_probe(p, host)
    if (output + error).contains("oidc Successfully retrieved and set token") {
      return status == 0
    }
  }
  failed(
    "AUTH_REQUIRED",
    "npm login/CI authentication is required: " + redact(err),
  )
}
