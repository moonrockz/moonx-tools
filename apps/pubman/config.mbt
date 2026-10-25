///|
enum Token {
  Word(String)
  Quoted(String)
  Mark(String)
} derive(Eq)

///|
/// Lex Moon manifest scalars and balanced containers. Strings use JSON escapes;
/// comments never contribute metadata. This deliberately does not evaluate expressions.
fn manifest_tokens(text : String) -> Array[Token] raise {
  let out = []
  let mut i = 0
  while i < text.length() {
    let c = text.code_unit_at(i).to_int()
    if c == 32 || c == 9 || c == 10 || c == 13 {
      i += 1
      continue
    }
    if text[i:].has_prefix("//") || c == 35 {
      while i < text.length() && text.code_unit_at(i).to_int() != 10 {
        i += 1
      }
      continue
    }
    if text[i:].has_prefix("/*") {
      let mut nesting = 1
      i += 2
      while i < text.length() && nesting > 0 {
        if text[i:].has_prefix("/*") {
          nesting += 1
          i += 2
        } else if text[i:].has_prefix("*/") {
          nesting -= 1
          i += 2
        } else {
          i += 1
        }
      }
      if nesting != 0 {
        invalid("unterminated manifest comment")
      }
      continue
    }
    if c == 34 {
      let start = i
      i += 1
      let mut closed = false
      while i < text.length() {
        if text.code_unit_at(i).to_int() == 92 {
          i += 2
          continue
        }
        if text.code_unit_at(i).to_int() == 34 {
          i += 1
          closed = true
          break
        }
        i += 1
      }
      if !closed {
        invalid("unterminated manifest string")
      }
      out.push(Quoted(str(@json.parse(text[start:i]))))
      continue
    }
    if "{}[](),=:@".contains(text[i:i + 1].to_owned()) {
      out.push(Mark(text[i:i + 1].to_owned()))
      i += 1
      continue
    }
    let start = i
    while i < text.length() {
      let c = text.code_unit_at(i).to_int()
      if c <= 32 || "{}[](),=:@\"".contains(text[i:i + 1].to_owned()) {
        break
      }
      i += 1
    }
    if i == start {
      invalid("unsupported manifest token")
    }
    out.push(Word(text[start:i].to_owned()))
  }
  out
}

///|
fn metadata(text : String) -> Json raise {
  let ts = manifest_tokens(text)
  let m : Map[String, Json] = Map([])
  let mut depth = 0
  for i in 0..<ts.length() {
    match ts[i] {
      Mark("{" | "[" | "(") => depth += 1
      Mark("}" | "]" | ")") => depth -= 1
      Word("path") => invalid("local path dependencies are unsupported")
      Word(key) if depth == 0 && i + 2 < ts.length() && ts[i + 1] == Mark("=") =>
        if [
            "name", "version", "description", "license", "repository", "readme",
            "private",
          ].contains(key) {
          if m.contains(key) {
            invalid("duplicate module metadata: " + key)
          }
          let value = match ts[i + 2] {
            Quoted(s) => Json::string(s)
            Word("true") => Json::boolean(true)
            Word("false") => Json::boolean(false)
            _ => invalid("unsupported metadata expression for " + key)
          }
          if i + 3 < ts.length() {
            match ts[i + 3] {
              Word(next) if (i + 4 < ts.length() && ts[i + 4] == Mark("=")) ||
                ["import", "options", "targets"].contains(next) => ()
              _ => invalid("unsupported metadata expression for " + key)
            }
          }
          if key == "private" {
            if value != true && value != false {
              invalid("private metadata must be boolean")
            }
          } else if !(value is String(_)) {
            invalid("metadata must be a string: " + key)
          }
          m[key] = value
        }
      _ => ()
    }
  }
  if depth != 0 {
    invalid("unbalanced manifest containers")
  }
  Json::object(m)
}

///|
fn valid_name(name : String, npm : Bool) -> Bool {
  if name.is_empty() || name.length() > 214 {
    return false
  }
  let body = if npm && name.has_prefix("@") {
    name[1:].to_owned()
  } else {
    name
  }
  let parts = body.split("/").map(x => x.to_owned()).collect()
  if (!npm && parts.length() != 2) ||
    (npm && parts.length() != (if name.has_prefix("@") { 2 } else { 1 })) {
    return false
  }
  for part in parts {
    if part.is_empty() || part.has_prefix(".") || part.has_prefix("_") {
      return false
    }
    for c in part.to_array() {
      if !((c >= 'a' && c <= 'z') ||
        (c >= '0' && c <= '9') ||
        c == '-' ||
        c == '_' ||
        c == '.') {
        return false
      }
    }
  }
  true
}

///|
fn semver(value : String) -> Bool {
  let parts = value.split("+").map(x => x.to_owned()).collect()
  if parts.length() > 2 {
    return false
  }
  let base = parts[0].split("-").map(x => x.to_owned()).collect()
  let nums = base[0].split(".").map(x => x.to_owned()).collect()
  if nums.length() != 3 {
    return false
  }
  for n in nums {
    if n.is_empty() || (n.length() > 1 && n.has_prefix("0")) {
      return false
    }
    for c in n.to_array() {
      if c < '0' || c > '9' {
        return false
      }
    }
  }
  if base.length() > 1 && !identifiers(base[1:].join("-"), true) {
    return false
  }
  if parts.length() == 2 && !identifiers(parts[1], false) {
    return false
  }
  true
}

///|
fn identifiers(s : String, prerelease : Bool) -> Bool {
  for p in s.split(".") {
    if p.is_empty() {
      return false
    }
    let mut numeric = true
    for c in p.to_owned().to_array() {
      if !(c >= '0' && c <= '9') {
        numeric = false
      }
      if !((c >= 'a' && c <= 'z') ||
        (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9') ||
        c == '-') {
        return false
      }
    }
    if prerelease && numeric && p.length() > 1 && p.has_prefix("0") {
      return false
    }
  }
  true
}

///|
struct Entry {
  pkg : String
  wrapper : String
  declaration : Json
  target : String
  loader : Json
}

///|
struct Config {
  raw : Json
  config_path : String
  root : String
  meta : Json
  npm : Json
  entries : Array[Entry]
  assets : Array[Json]
  checks : Json
  output : String
}

///|
async fn load_config(path : String) -> Config {
  let config_path = @fs.realpath(absolute(path))
  let raw = read_json(config_path)
  keys(raw, [
    "schemaVersion", "module", "npm", "entries", "assets", "checks", "output",
  ])
  if field(raw, "schemaVersion") != 1 {
    invalid("pubman schemaVersion must be 1")
  }
  if field(raw, "module") == Json::null() &&
    @fs.exists(parent(config_path) + "/moon.work") {
    invalid(
      "module selection is ambiguous in a workspace; set module explicitly",
    )
  }
  let root = @fs.realpath(
    parent(config_path) + "/" + opt_string(raw, "module", "."),
  )
  let meta = metadata(@fs.read_file(root + "/moon.mod").text())
  let name = string_field(meta, "name")
  let v = string_field(meta, "version")
  if !valid_name(name, false) || !semver(v) {
    invalid("invalid MoonBit name/version")
  }
  if v.contains("+") {
    invalid("release versions cannot contain build metadata; npm removes it")
  }
  if field(meta, "private") == true {
    invalid("private modules cannot be published")
  }
  let npm = field(raw, "npm")
  keys(npm, ["name", "version", "description", "access", "dependencies", "tag"])
  if !valid_name(string_field(npm, "name"), true) {
    invalid("invalid npm package name")
  }
  if opt_string(npm, "version", v) != v {
    invalid(
      "npm version " +
      string_field(npm, "version") +
      " conflicts with module " +
      v,
    )
  }
  if string_field(npm, "access") != "public" {
    invalid("only public npm access is supported")
  }
  if field(npm, "dependencies") is Object(deps) {
    for name, v in deps {
      if !valid_name(name, true) || !semver(str(v)) {
        invalid(
          "runtime dependencies require public npm names and exact semver versions",
        )
      }
    }
  } else if field(npm, "dependencies") != Json::null() {
    invalid("dependencies must be an object")
  }
  let exports = field(raw, "entries")
  keys(exports, ["js", "wasm"])
  let entries = []
  for backend in ["js", "wasm"] {
    let j = field(exports, backend)
    keys(j, ["package", "wrapper", "declaration", "target", "loader"])
    let target = if backend == "js" { "js" } else { "wasm-gc" }
    if opt_string(j, "target", target) != target {
      invalid("supported targets are js and wasm-gc")
    }
    let pkg = string_field(j, "package")
    safe_relative(pkg)
    ignore(contained(root, pkg + "/moon.pkg"))
    let wrapper = string_field(j, "wrapper")
    ignore(contained(root, wrapper))
    let decl = field(j, "declaration")
    match decl {
      String(p) => {
        if !p.has_suffix(".d.ts") {
          invalid("declaration must end with .d.ts")
        }
        ignore(contained(root, p))
      }
      Object(_) => {
        keys(decl, ["backend", "path"])
        if string_field(decl, "backend") != target {
          invalid("compiler declaration backend mismatch")
        }
        let p = string_field(decl, "path")
        safe_relative(p)
        if !p.has_suffix(".d.ts") {
          invalid("compiler declaration must end with .d.ts")
        }
      }
      _ => invalid("missing " + backend + " declaration")
    }
    let loader = if field(j, "loader") == Json::null() {
      Json::empty_object()
    } else {
      field(j, "loader")
    }
    keys(loader, ["builtins", "importedStringConstants"])
    if field(loader, "importedStringConstants") != Json::null() {
      ignore(string_field(loader, "importedStringConstants"))
    }
    if field(loader, "builtins") != Json::null() {
      for b in strings(field(loader, "builtins")) {
        if b != "js-string" {
          invalid("unsupported Wasm builtin")
        }
      }
    }
    entries.push({ pkg, wrapper, declaration: decl, target, loader, })
  }
  let assets = array(field(raw, "assets"))
  let destinations = [
    "package.json", "js/index.mjs", "js/index.d.ts", "wasm/index.mjs", "wasm/index.d.ts",
    "internal/js/library.js", "internal/wasm/library.wasm", "internal/wasm/loader.mjs",
  ]
  for a in assets {
    keys(a, ["source", "destination"])
    ignore(contained(root, string_field(a, "source")))
    let dest = string_field(a, "destination")
    safe_relative(dest)
    for prior in destinations {
      if dest == prior || inside(dest, prior) || inside(prior, dest) {
        invalid("package destination collision: " + dest)
      }
    }
    if dest.has_prefix("internal/") {
      invalid("internal destinations are reserved")
    }
    destinations.push(dest)
  }
  let checks = field(raw, "checks")
  keys(checks, ["node", "browser", "types"])
  for kind in ["node", "browser", "types"] {
    let files = strings(field(checks, kind))
    if files.is_empty() {
      invalid("at least one " + kind + " consumer check is required")
    }
    for f in files {
      ignore(contained(root, f))
    }
  }
  let output_rel = opt_string(raw, "output", "_build/pubman/release")
  safe_relative(output_rel)
  let output = future_path(parent(config_path) + "/" + output_rel)
  // Outputs may live under _build, but must never contain selected source inputs.
  if output == root || inside(output, root) || output == parent(config_path) {
    invalid("output overlaps module")
  }
  if inside(root, output) && !inside(root + "/_build", output) {
    invalid("output within module must be under _build")
  }
  if @fs.exists(output) &&
    (
      !@fs.exists(output + "/.pubman-owned") ||
      @fs.read_file(output + "/.pubman-owned").text() != "pubman bundle v1\n"
    ) {
    invalid("output directory is not owned by pubman")
  }
  let input_paths = [config_path, root + "/moon.mod"]
  for e in entries {
    input_paths.push(contained(root, e.wrapper))
    if e.declaration is String(p) {
      input_paths.push(contained(root, p))
    }
  }
  for a in assets {
    input_paths.push(contained(root, string_field(a, "source")))
  }
  for k in ["node", "browser", "types"] {
    for p in strings(field(checks, k)) {
      input_paths.push(contained(root, p))
    }
  }
  if input_paths.any(p => p == output || inside(output, p)) {
    invalid("output overlaps source inputs")
  }
  validate_source_tree(root, root)
  { raw, config_path, root, meta, npm, entries, assets, checks, output, }
}

///|
fn Config::plan(self : Config) -> Json {
  {
    "module": self.root,
    "moon": self.meta,
    "npm": self.npm,
    "version": field(self.meta, "version"),
    "resolvedEntries": Json::array(
      self.entries.map(e => {
        "backend": e.target,
        "package": self.root + "/" + e.pkg,
        "wrapper": self.root + "/" + e.wrapper,
        "declaration": match e.declaration {
          String(p) => { "kind": "author", "path": self.root + "/" + p }
          _ =>
            {
              "kind": "compiler",
              "backend": e.target,
              "path": field(e.declaration, "path"),
            }
        },
      }),
    ),
    "entries": field(self.raw, "entries"),
    "assets": Json::array(self.assets),
    "checks": self.checks,
    "output": self.output,
    "tools": ["moon", "node", "npm", "tsc", "playwright", "unzip", "zip", "tar"],
    "operations": json_strings(operations("pack")),
  }
}

///|
async fn validate_source_tree(root : String, dir : String) -> Unit {
  for name in @fs.readdir(dir, include_hidden=true) {
    if ["_build", ".mooncakes", ".git", "node_modules"].contains(name) {
      continue
    }
    let path = dir + "/" + name
    match @fs.kind(path, follow_symlink=false) {
      SymLink => {
        let real = @fs.realpath(path)
        if !inside(root, real) {
          invalid("source symlink escapes module: " + path)
        }
        if @fs.kind(path) == Directory {
          invalid("source directory symlinks are unsupported")
        }
      }
      Directory => validate_source_tree(root, path)
      Regular => ()
      _ => invalid("non-regular source input: " + path)
    }
  }
}
