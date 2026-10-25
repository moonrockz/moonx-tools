///|
let loader_source : String =
  #|export async function instantiate(options = {}) {
  #|  const url = options.url ? new URL(options.url, import.meta.url) : new URL('./library.wasm', import.meta.url);
  #|  try {
  #|    let bytes = options.bytes;
  #|    if (!bytes) {
  #|      if (url.protocol === 'file:' && typeof process !== 'undefined' && process.versions?.node) {
  #|        bytes = await (await import('node:fs/promises')).readFile(url);
  #|      } else {
  #|        const response = await fetch(url);
  #|        if (!response.ok) throw new Error(`HTTP ${response.status}`);
  #|        bytes = await response.arrayBuffer();
  #|      }
  #|    }
  #|    const { instance } = await WebAssembly.instantiate(bytes, options.imports ?? {}, COMPILE_OPTIONS);
  #|    return instance.exports;
  #|  } catch (cause) {
  #|    throw new Error(`Cannot initialize Wasm-GC asset ${url}. Requires Wasm-GC, configured JS string builtins and host imports. Supply bytes or url to relocate the asset. ${cause.message}`, { cause });
  #|  }
  #|}

///|
async fn extract_source(host : Host, archive : String, dest : String) -> Unit {
  let listing = host.checked("unzip", ["-Z1", archive], parent(archive))
  for line in listing.split("\n") {
    if line.is_empty() {
      continue
    }
    let name = line.trim_end(chars="/").to_owned()
    safe_relative(name)
    for part in name.split("/") {
      if [
          ".git", ".npmrc", ".env", "credentials.json", "node_modules", "_build",
          ".mooncakes",
        ].contains(part.to_owned()) ||
        part.has_prefix(".env.") {
        invalid("sensitive or generated source archive input: " + name)
      }
    }
  }
  let modes = host.checked("unzip", ["-Z", "-l", archive], parent(archive))
  for line in modes.split("\n") {
    if line.has_prefix("l") {
      invalid("source archive contains a symlink")
    }
  }
  host.mkdir(dest, recursive=true, allow_exist=false)
  ignore(host.checked("unzip", ["-q", archive, "-d", dest], parent(archive)))
}

///|
async fn find_files(dir : String, suffix : String) -> Array[String] {
  let result = []
  for name in @fs.readdir(dir, include_hidden=true, sort=true) {
    let path = dir + "/" + name
    match @fs.kind(path, follow_symlink=false) {
      Directory => result.append(find_files(path, suffix))
      Regular => if name.has_suffix(suffix) { result.push(path) }
      _ => invalid("non-regular file: " + path)
    }
  }
  result
}

///|
async fn unique_file(dir : String, suffix : String) -> String {
  let found = find_files(dir, suffix)
  if found.length() != 1 {
    failed("ARTIFACT_LAYOUT", "expected one " + suffix + " under " + dir)
  }
  found[0]
}

///|
async fn tool_identities(host : Host) -> Json {
  let m : Map[String, Json] = Map([])
  for
    item in [
      ("moon", ["version", "--all"]),
      ("node", ["--version"]),
      ("npm", ["--version"]),
      ("tsc", ["--version"]),
      ("playwright", ["--version"]),
    ] {
    m[item.0] = Json::string(host.checked(item.0, item.1, "/"))
  }
  m["pubman"] = Json::string(version)
  m["executionArtifact"] = Json::string(file_digest(absolute(@env.args()[0])))
  m["verificationImplementation"] = Json::string(
    digest(@utf8.encode(loader_source + browser_harness + implementation_id)),
  )
  Json::object(m)
}

///|
async fn copy_generated(host : Host, src : String, dest : String) -> Unit {
  for path in find_files(src, "") {
    if path.has_suffix(".js") ||
      path.has_suffix(".mjs") ||
      path.has_suffix(".d.ts") {
      copy_file(host, path, dest + path[src.length():].to_owned())
    }
  }
}

///|
/// Inspect literal module references in JS/TS. TypeScript remains the final
/// authority on declaration resolution, including package dependencies.
async fn check_references(root : String, deps : Json) -> Unit {
  for file in find_files(root, "") {
    if !(file.has_suffix(".js") ||
      file.has_suffix(".mjs") ||
      file.has_suffix(".d.ts")) {
      continue
    }
    let text = @fs.read_file(file).text()
    // Tokenize quotes only. This handles import/export specifiers and reference
    // directives without treating comments or arbitrary JS as a manifest.
    for quote in ["\"", "'"] {
      let parts = text.split(quote).map(x => x.to_owned()).collect()
      for i = 1; i < parts.length(); i = i + 2 {
        let s = parts[i]
        let context = parts[i - 1].trim_end().to_owned()
        let reference = [
          "from", "import", "import(", "require(", "new URL(", "path=", "types=",
        ].any(marker => context.has_suffix(marker))
        if !reference {
          continue
        }
        if s.has_prefix("../") || s.has_prefix("./") {
          let target = future_path(parent(file) + "/" + s)
          if !inside(root, target) {
            invalid("escaping local reference: " + s)
          }
          let resolved = if @fs.exists(target) {
            true
          } else if s.has_suffix(".js") {
            @fs.exists(target[:target.length() - 3].to_owned() + ".d.ts")
          } else {
            false
          }
          if !resolved {
            invalid("missing local reference " + s + " in " + file)
          }
        } else if file.has_suffix(".d.ts") && !s.contains(" ") && !s.is_empty() {
          // Only strings in import/from/require and triple-slash references are dependencies.
          let context = parts[i - 1].trim_end().to_owned()
          if context.has_suffix("from") ||
            context.has_suffix("import") ||
            context.has_suffix("require(") {
            let parts = s.split("/").map(x => x.to_owned()).collect()
            let name = if s.has_prefix("@") && parts.length() >= 2 {
              parts[0] + "/" + parts[1]
            } else {
              parts[0]
            }
            if field(deps, name) == Json::null() {
              invalid("undeclared declaration dependency: " + name)
            }
          }
        }
      }
    }
  }
}

///|
async fn capture_inputs(host : Host, c : Config, dest : String) -> Unit {
  let paths = []
  for e in c.entries {
    paths.push(e.wrapper)
    if e.declaration is String(s) {
      paths.push(s)
    }
  }
  for a in c.assets {
    paths.push(string_field(a, "source"))
  }
  for k in ["node", "browser", "types"] {
    paths.append(strings(field(c.checks, k)))
  }
  for p in paths {
    if !@fs.exists(dest + "/" + p) {
      copy_file(host, contained(c.root, p), dest + "/" + p)
    }
  }
}

///|
async fn pack(c : Config, host : Host) -> Json {
  // Build outside every workspace ancestor. Staging output is on the same
  // filesystem as the destination to permit a final rename.
  host.mkdir(parent(c.output), recursive=true, allow_exist=true)
  let lock = host.create(c.output + ".pack-lock", allow_existing=false)
  defer lock.close()
  defer host.remove(c.output + ".pack-lock")
  let prior_guard = if @fs.exists(c.output) {
    Some(host.create(c.output + "/.operation-lock", allow_existing=false))
  } else {
    None
  }
  let mut prior_lock_path = c.output + "/.operation-lock"
  defer (if prior_guard is Some(file) {
    file.close()
    if @fs.exists(prior_lock_path) {
      host.remove(prior_lock_path)
    }
  })
  let work = host.tmpdir(prefix="pubman-build-")
  defer host.rmdir(work, recursive=true)
  let stage = c.output + ".staging-" + basename(work)
  host.mkdir(stage, allow_exist=false)
  let mut committed = false
  defer (if !committed { host.rmdir(stage, recursive=true) })
  let payload = stage + "/payload"
  host.mkdir(payload, recursive=true)
  let tools = tool_identities(host)
  ignore(
    host.checked("moon", ["package", "--target-dir", work + "/capture"], c.root),
  )
  let archive = unique_file(work + "/capture/publish", ".zip")
  copy_file(host, archive, payload + "/source.zip")
  let source = work + "/source"
  extract_source(host, payload + "/source.zip", source)
  let source_inventory = inventory(source)
  // Repack the extracted snapshot; the inventory must be exactly reusable.
  ignore(
    host.checked("moon", ["package", "--target-dir", work + "/repack"], source),
  )
  let repack = unique_file(work + "/repack/publish", ".zip")
  extract_source(host, repack, work + "/repacked")
  if inventory(work + "/repacked") != source_inventory {
    failed("SOURCE_INVENTORY", "source snapshot does not survive repackaging")
  }
  capture_inputs(host, c, payload + "/inputs")
  copy_file(host, c.config_path, payload + "/config.json")
  let pkg = work + "/npm"
  host.mkdir(pkg, recursive=true)
  let dependencies : Map[String, Json] = Map([])
  for e in c.entries {
    let snapshot = work + "/snapshot-" + e.target
    extract_source(host, payload + "/source.zip", snapshot)
    if @fs.exists(snapshot + "/moon.work") {
      invalid("source archive must not contain moon.work")
    }
    ignore(metadata(@fs.read_file(snapshot + "/moon.mod").text()))
    // Dependencies resolve in the standalone snapshot, never the original workspace.
    ignore(host.checked("moon", ["check"], snapshot))
    dependencies[e.target] = Json::string(
      host.checked("moon", ["tree"], snapshot),
    )
    let target = work + "/target-" + e.target
    ignore(
      host.checked(
        "moon",
        [
          "build",
          e.pkg,
          "--target",
          e.target,
          "--release",
          "--frozen",
          "--target-dir",
          target,
        ],
        snapshot,
      ),
    )
    let output = target + "/" + e.target + "/release/build/" + e.pkg
    let public_entry = if e.target == "js" { "js" } else { "wasm" }
    if e.target == "js" {
      let js = unique_file(output, ".js")
      copy_generated(host, output, pkg + "/internal/js")
      let copied = pkg + "/internal/js/" + basename(js)
      if basename(js) != "library.js" {
        host.rename(copied, pkg + "/internal/js/library.js")
      }
    } else {
      copy_file(
        host,
        unique_file(output, ".wasm"),
        pkg + "/internal/wasm/library.wasm",
      )
      host.write_file(
        pkg + "/internal/wasm/loader.mjs",
        loader_source.replace(old="COMPILE_OPTIONS", new=e.loader.stringify()),
      )
    }
    copy_file(
      host,
      payload + "/inputs/" + e.wrapper,
      pkg + "/" + public_entry + "/index.mjs",
    )
    match e.declaration {
      String(p) =>
        copy_file(
          host,
          payload + "/inputs/" + p,
          pkg + "/" + public_entry + "/index.d.ts",
        )
      Object(_) => {
        let declared = target +
          "/" +
          e.target +
          "/release/build/" +
          string_field(e.declaration, "path")
        if !@fs.exists(declared) {
          invalid("missing compiler declaration: " + declared)
        }
        copy_generated(host, parent(declared), pkg + "/" + public_entry)
        let copied = pkg + "/" + public_entry + "/" + basename(declared)
        if basename(declared) != "index.d.ts" {
          host.rename(copied, pkg + "/" + public_entry + "/index.d.ts")
        }
      }
      _ => invalid("missing declaration")
    }
  }
  for a in c.assets {
    copy_file(
      host,
      payload + "/inputs/" + string_field(a, "source"),
      pkg + "/" + string_field(a, "destination"),
    )
  }
  let deps = if field(c.npm, "dependencies") == Json::null() {
    Json::empty_object()
  } else {
    field(c.npm, "dependencies")
  }
  check_references(pkg, deps)
  let manifest : Json = {
    "name": field(c.npm, "name"),
    "version": field(c.meta, "version"),
    "type": "module",
    "description": opt_string(
      c.npm,
      "description",
      opt_string(c.meta, "description", ""),
    ),
    "license": field(c.meta, "license"),
    "repository": field(c.meta, "repository"),
    "types": "./js/index.d.ts",
    "exports": {
      ".": { "types": "./js/index.d.ts", "import": "./js/index.mjs" },
      "./wasm": { "types": "./wasm/index.d.ts", "import": "./wasm/index.mjs" },
    },
    "dependencies": deps,
  }
  write_json(host, pkg + "/package.json", manifest)
  let npm_inventory = inventory(pkg)
  let packed = @json.parse(
    host.checked(
      "npm",
      ["pack", "--json", "--ignore-scripts", "--pack-destination", payload],
      pkg,
    ),
  )
  let info = array(packed)[0]
  host.rename(
    payload + "/" + string_field(info, "filename"),
    payload + "/package.tgz",
  )
  let expected = match npm_inventory {
    Object(m) => m.keys().to_array()
    _ => []
  }
  let actual = array(field(info, "files")).map(f => string_field(f, "path"))
  if expected.length() != actual.length() ||
    expected.any(p => !actual.contains(p)) {
    failed("NPM_INVENTORY", "npm pack changed the declared file inventory")
  }
  write_json(host, payload + "/source-inventory.json", source_inventory)
  write_json(host, payload + "/npm-inventory.json", npm_inventory)
  write_json(host, payload + "/tools.json", tools)
  write_json(host, payload + "/dependencies.json", Json::object(dependencies))
  let integrity = "sha512-" +
    @base64.encode(
      Bytes::from_array(
        @crypto.sha512(@fs.read_file(payload + "/package.tgz").binary())[:],
      )[:],
    )
  let bundle : Json = {
    "schemaVersion": 1,
    "module": field(c.meta, "name"),
    "npm": field(c.npm, "name"),
    "version": field(c.meta, "version"),
    "integrity": integrity,
    "tag": field(c.npm, "tag"),
    "files": inventory(payload),
  }
  write_json(host, stage + "/bundle.json", bundle)
  host.write_file(stage + "/.pubman-owned", "pubman bundle v1\n")
  let backup = stage + ".previous"
  let prior = prior_guard is Some(_)
  if @fs.exists(c.output) != prior {
    failed(
      "OUTPUT_CHANGED", "output changed while packaging; refusing replacement",
    )
  }
  if prior &&
    @fs.read_file(c.output + "/.pubman-owned").text() != "pubman bundle v1\n" {
    failed("OUTPUT_CHANGED", "output ownership changed while packaging")
  }
  if prior {
    host.rename(c.output, backup, replace=false)
    prior_lock_path = backup + "/.operation-lock"
  }
  errdefer (if prior && !committed {
    host.rename(backup, c.output, replace=false)
    prior_lock_path = c.output + "/.operation-lock"
  })
  host.rename(stage, c.output, replace=false)
  committed = true
  if prior {
    host.rmdir(backup, recursive=true)
  }
  { "dryRun": false, "bundle": c.output, "identity": bundle }
}
