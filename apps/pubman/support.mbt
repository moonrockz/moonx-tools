///|
suberror Failure {
  Failure(String, String, Int32)
}

///|
suberror Partial {
  Partial(String, String, Int32, Json)
}

///|
fn[T] invalid(message : String) -> T raise {
  raise Failure("INVALID_INPUT", message, 2)
}

///|
fn[T] failed(code : String, message : String) -> T raise {
  raise Failure(code, message, 1)
}

///|
fn field(j : Json, key : String) -> Json {
  match j {
    Object(m) => m.get(key).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn str(j : Json) -> String raise {
  match j {
    String(s) => s
    _ => invalid("expected a string, got " + j.stringify())
  }
}

///|
fn string_field(j : Json, key : String) -> String raise {
  str(field(j, key))
}

///|
fn array(j : Json) -> Array[Json] raise {
  match j {
    Array(a) => a
    _ => invalid("expected an array")
  }
}

///|
fn strings(j : Json) -> Array[String] raise {
  array(j).map(x => str(x))
}

///|
fn keys(j : Json, allowed : Array[String]) -> Unit raise {
  guard j is Object(m) else { invalid("expected an object") }
  for k, _ in m {
    if !allowed.contains(k) {
      invalid("unsupported field: " + k)
    }
  }
}

///|
fn opt_string(j : Json, key : String, default : String) -> String raise {
  if field(j, key) == Json::null() {
    default
  } else {
    string_field(j, key)
  }
}

///|
fn json_strings(xs : Array[String]) -> Json {
  Json::array(xs.map(x => Json::string(x)))
}

///|
fn parent(path : String) -> String {
  let parts = path.split("/").map(x => x.to_owned()).collect()
  ignore(parts.pop())
  if parts.is_empty() {
    "."
  } else if parts.length() == 1 && parts[0] == "" {
    "/"
  } else {
    parts.join("/")
  }
}

///|
fn basename(path : String) -> String {
  path.split("/").last().unwrap_or("").to_owned()
}

///|
fn absolute(path : String) -> String {
  if path.has_prefix("/") {
    path
  } else {
    @env.current_dir().unwrap_or(".") + "/" + path
  }
}

///|
fn safe_relative(path : String) -> Unit raise {
  if path.is_empty() ||
    path.has_prefix("/") ||
    path.contains("\\") ||
    path.contains(":") ||
    path.contains("\n") ||
    path.contains("\r") {
    invalid("unsafe relative path: " + path)
  }
  for part in path.split("/") {
    if part == ".." || part == "." || part.is_empty() {
      invalid("unsafe path component: " + path)
    }
  }
}

///|
fn inside(root : String, path : String) -> Bool {
  path.has_prefix(root + "/")
}

///|
async fn contained(root : String, relative : String) -> String {
  safe_relative(relative)
  let p = @fs.realpath(root + "/" + relative)
  if !inside(root, p) {
    invalid("symlink escapes module: " + relative)
  }
  p
}

///|
async fn future_path(path : String) -> String {
  if @fs.exists(path) {
    @fs.realpath(path)
  } else {
    future_path(parent(path)) + "/" + basename(path)
  }
}

///|
async fn read_json(path : String) -> Json {
  @json.parse(@fs.read_file(path).text())
}

///|
async fn write_json(host : Host, path : String, value : Json) -> Unit {
  host.write_file(
    path + ".new",
    value.stringify(indent=2) + "\n",
    create_mode=CreateNew,
  )
  host.rename(path + ".new", path)
}

///|
async fn copy_file(host : Host, src : String, dest : String) -> Unit {
  host.mkdir(parent(dest), recursive=true, allow_exist=true)
  host.write_file(dest, @fs.read_file(src), create_mode=CreateNew)
}

///|
fn digest(bytes : Bytes) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(bytes))
}

///|
async fn file_digest(path : String) -> String {
  digest(@fs.read_file(path).binary())
}

///|
async fn inventory(root : String, prefix~ : String = "") -> Json {
  let m : Map[String, Json] = Map([])
  for name in @fs.readdir(root, include_hidden=true, sort=true) {
    safe_relative(name)
    let path = root + "/" + name
    match @fs.kind(path, follow_symlink=false) {
      Regular => m[prefix + name] = Json::string(file_digest(path))
      Directory => {
        guard inventory(path, prefix=prefix + name + "/") is Object(child) else {
          abort("inventory")
        }
        for k, v in child {
          m[k] = v
        }
      }
      _ => invalid("non-regular snapshot input: " + path)
    }
  }
  Json::object(m)
}

///|
/// One process boundary. Tests inject this function, never production environment switches.
struct Host {
  run : async (String, Array[String], String) -> (Int32, String, String)
  preview : Bool
  mutation : (String) -> Unit raise
}

///|
fn real_host(preview : Bool) -> Host {
  {
    preview,
    mutation: fn(action) raise {
      if preview {
        failed("PREVIEW_MUTATION", "preview attempted " + action)
      }
    },
    run: async fn(cmd, args, cwd) {
      let (code, out, err) = @process.collect_output(cmd, args[:], cwd=cwd[:])
      (code, out.text(), err.text())
    },
  }
}

///|
async fn Host::call(
  self : Host,
  cmd : String,
  args : Array[String],
  cwd : String,
) -> (Int32, String, String) {
  if self.preview {
    failed("PREVIEW_MUTATION", "preview attempted a process")
  }
  (self.run)(cmd, args, cwd)
}

///|
async fn Host::checked(
  self : Host,
  cmd : String,
  args : Array[String],
  cwd : String,
) -> String {
  let (code, out, err) = self.call(cmd, args, cwd)
  if !out.is_empty() {
    eprintln(redact(out).trim_end())
  }
  if !err.is_empty() {
    eprintln(redact(err).trim_end())
  }
  if code != 0 {
    failed("SUBPROCESS_FAILED", "\{cmd} exited \{code}: " + redact(err))
  }
  out
}

///|
fn redact(text : String) -> String {
  let mut value = text
  for
    key in [
      "NPM_TOKEN", "NODE_AUTH_TOKEN", "MOONCAKES_USER_TOKEN", "NPM_ID_TOKEN", "ACTIONS_ID_TOKEN_REQUEST_TOKEN",
    ] {
    if @env.get_env_var(key) is Some(token) && token.length() > 3 {
      value = value.replace(old=token, new="[REDACTED]")
    }
  }
  let tokens = value.split(" ").map(x => x.to_owned()).collect()
  for token in tokens {
    if token.contains("npm_") ||
      token.contains("_authToken=") ||
      token.contains("token=") {
      value = value.replace(old=token, new="[REDACTED]")
    }
  }
  if value.contains("Bearer ") {
    let parts = value.split("Bearer ").map(x => x.to_owned()).collect()
    for p in parts[1:] {
      let token = p.split(" ").next().unwrap_or("").trim().to_owned()
      if !token.is_empty() {
        value = value.replace(old=token, new="[REDACTED]")
      }
    }
  }
  value
}

///|
async fn Host::mkdir(
  self : Host,
  path : String,
  recursive~ : Bool = false,
  allow_exist~ : Bool = false,
) -> Unit {
  (self.mutation)("mkdir " + path)
  @fs.mkdir(path, recursive~, allow_exist~)
}

///|
async fn Host::write_file(
  self : Host,
  path : String,
  data : &@io.Data,
  create_mode~ : @fs.CreateMode = CreateOrTruncate,
) -> Unit {
  (self.mutation)("write " + path)
  @fs.write_file(path, data, create_mode~)
}

///|
async fn Host::create(
  self : Host,
  path : String,
  allow_existing~ : Bool = false,
) -> @fs.File {
  (self.mutation)("lock " + path)
  @fs.create(path, allow_existing~)
}

///|
async fn Host::rename(
  self : Host,
  from : String,
  to : String,
  replace~ : Bool = true,
) -> Unit {
  (self.mutation)("rename " + from + " to " + to)
  @fs.rename(from, to, replace~)
}

///|
async fn Host::remove(self : Host, path : String) -> Unit {
  (self.mutation)("remove " + path)
  @fs.remove(path)
}

///|
async fn Host::rmdir(
  self : Host,
  path : String,
  recursive~ : Bool = false,
) -> Unit {
  (self.mutation)("rmdir " + path)
  @fs.rmdir(path, recursive~)
}

///|
async fn Host::tmpdir(self : Host, prefix~ : String) -> String {
  (self.mutation)("tmpdir " + prefix)
  @fs.realpath(@fs.tmpdir(prefix~))
}
