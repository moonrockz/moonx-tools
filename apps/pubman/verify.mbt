///|
/// Bump when changing execution semantics. The focused task also checks the
/// embedded source identity, preventing same-version implementation reuse.
let implementation_id : String = "pubman-verifier-v1-20261024"

///|
let browser_harness : String =
  #|import { createServer } from 'node:http';
  #|import { readFile, realpath } from 'node:fs/promises';
  #|import { resolve, sep } from 'node:path';
  #|import { pathToFileURL } from 'node:url';
  #|const [root, playwrightPath, packageName, ...checks] = process.argv.slice(1);
  #|const { chromium } = await import(pathToFileURL(playwrightPath));
  #|const importmap = { imports: { [packageName]: `/node_modules/${packageName}/js/index.mjs`, [`${packageName}/wasm`]: `/node_modules/${packageName}/wasm/index.mjs` } };
  #|const server = createServer(async (req, res) => {
  #|  try {
  #|    if (req.url === '/') { res.setHeader('Content-Type', 'text/html'); res.end(`<script type="importmap">${JSON.stringify(importmap)}</script>`); return; }
  #|    const file = await realpath(resolve(root, '.' + decodeURIComponent(new URL(req.url, 'http://localhost').pathname)));
  #|    if (!file.startsWith(root + sep)) throw new Error('path escape');
  #|    res.setHeader('Content-Type', file.endsWith('.wasm') ? 'application/wasm' : 'text/javascript');
  #|    res.end(await readFile(file));
  #|  } catch { res.statusCode = 404; res.end('missing'); }
  #|});
  #|await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  #|let browser;
  #|try {
  #|  browser = await chromium.launch({headless:true});
  #|  const page = await browser.newPage();
  #|  page.on('console', msg => console.error(msg.text()));
  #|  await page.goto(`http://127.0.0.1:${server.address().port}/`);
  #|  for (const check of checks) await page.evaluate(async p => { await import('/' + p); }, check);
  #|} finally { await browser?.close(); await new Promise(resolve => server.close(resolve)); }

///|
async fn bundle_read(path : String) -> (String, Json) {
  let root = @fs.realpath(absolute(path))
  if !@fs.exists(root + "/.pubman-owned") ||
    @fs.read_file(root + "/.pubman-owned").text() != "pubman bundle v1\n" {
    invalid("not a pubman bundle")
  }
  let b = read_json(root + "/bundle.json")
  if field(b, "schemaVersion") != 1 {
    invalid("unsupported bundle schema")
  }
  if inventory(root + "/payload") != field(b, "files") {
    failed("BUNDLE_TAMPERED", "bundle bytes changed; pack and verify again")
  }
  let config = read_json(root + "/payload/config.json")
  if field(config, "schemaVersion") != 1 {
    invalid("unsupported captured configuration")
  }
  let name = string_field(b, "module")
  let npm = string_field(b, "npm")
  if !valid_name(name, false) ||
    !valid_name(npm, true) ||
    !semver(string_field(b, "version")) {
    invalid("invalid bundle identity")
  }
  (root, b)
}

///|
async fn find_playwright() -> String {
  for dir in @env.get_env_var("PATH").unwrap_or("").split(":") {
    let path = dir.to_owned() + "/playwright"
    if @fs.exists(path) {
      let binary = @fs.realpath(path)
      for
        module_path in [
          parent(binary) + "/index.mjs",
          parent(path) + "/../playwright/index.mjs",
        ] {
        if @fs.exists(module_path) {
          return @fs.realpath(module_path)
        }
      }
    }
  }
  failed(
    "MISSING_TOOL", "install playwright and its pinned Chromium browser before verify",
  )
}

///|
async fn evidence(root : String, b : Json, host : Host) -> Json {
  {
    "bundleDigest": file_digest(root + "/bundle.json"),
    "files": field(b, "files"),
    "tools": tool_identities(host),
    "browserModule": file_digest(find_playwright()),
  }
}

///|
async fn verification_valid(root : String, b : Json, host : Host) -> Bool {
  if !@fs.exists(root + "/verification.json") {
    return false
  }
  let receipt = read_json(root + "/verification.json")
  field(receipt, "ok") == true &&
  field(receipt, "evidence") == evidence(root, b, host)
}

///|
async fn verify_bundle(root : String, b : Json, host : Host) -> Json {
  // Exclusivity also prevents verify racing with publish or another verify.
  let lock = host.create(root + "/.operation-lock", allow_existing=false)
  defer lock.close()
  defer host.remove(root + "/.operation-lock")
  if @fs.exists(root + "/verification.json") {
    host.remove(root + "/verification.json")
  }
  let before = evidence(root, b, host)
  let work = host.tmpdir(prefix="pubman-consumer-")
  defer host.rmdir(work, recursive=true)
  write_json(host, work + "/package.json", { "private": true, "type": "module" })
  host.write_file(work + "/global.npmrc", "")
  ignore(
    host.checked(
      "npm",
      npm_args(
        [
          "install",
          "--ignore-scripts",
          "--no-audit",
          "--no-fund",
          "--userconfig=/dev/null",
          "--globalconfig=" + work + "/global.npmrc",
          "--registry=https://registry.npmjs.org",
          root + "/payload/package.tgz",
        ],
        string_field(b, "npm"),
      ),
      work,
    ),
  )
  let installed = work + "/node_modules/" + string_field(b, "npm")
  if inventory(installed) != read_json(root + "/payload/npm-inventory.json") {
    failed(
      "INSTALLED_INVENTORY", "installed package differs from packed inventory",
    )
  }
  let config = read_json(root + "/payload/config.json")
  let checks = field(config, "checks")
  let check_results : Array[Json] = []
  try {
    let copied : Array[String] = []
    for kind in ["node", "browser", "types"] {
      for p in strings(field(checks, kind)) {
        safe_relative(p)
        if !copied.contains(p) {
          copy_file(host, root + "/payload/inputs/" + p, work + "/" + p)
          copied.push(p)
        }
      }
    }
    for p in strings(field(checks, "node")) {
      run_check(host, "node", [work + "/" + p], work, check_results, "node", p)
    }
    for resolution in ["NodeNext", "Bundler"] {
      let tsconfig : Json = {
        "compilerOptions": {
          "strict": true,
          "noEmit": true,
          "skipLibCheck": false,
          "target": "ES2022",
          "module": if resolution == "NodeNext" {
            "NodeNext"
          } else {
            "ESNext"
          },
          "moduleResolution": resolution,
          "types": [],
        },
        "files": field(checks, "types"),
      }
      write_json(host, work + "/tsconfig.json", tsconfig)
      run_check(
        host,
        "tsc",
        ["--project", work + "/tsconfig.json"],
        work,
        check_results,
        "types",
        resolution,
      )
      host.remove(work + "/tsconfig.json")
    }
    let args = [
      "--input-type=module",
      "-e",
      browser_harness,
      work,
      find_playwright(),
      string_field(b, "npm"),
    ]
    args.append(strings(field(checks, "browser")))
    run_check(host, "node", args, work, check_results, "browser", "Chromium")
    let (_, after_bundle) = bundle_read(root)
    if evidence(root, after_bundle, host) != before {
      failed("STALE_EVIDENCE", "inputs or tools changed during verification")
    }
  } catch {
    err => {
      let receipt : Json = {
        "schemaVersion": 1,
        "ok": false,
        "evidence": before,
        "checks": Json::array(check_results),
      }
      write_json(host, root + "/verification.json", receipt)
      raise Partial("VERIFICATION_FAILED", redact(err.to_string()), 1, {
        "dryRun": false,
        "bundle": root,
        "verification": receipt,
      })
    }
  }
  let receipt : Json = {
    "schemaVersion": 1,
    "ok": true,
    "evidence": before,
    "checks": Json::array(check_results),
  }
  write_json(host, root + "/verification.json", receipt)
  { "dryRun": false, "bundle": root, "verification": receipt }
}

///|
async fn run_check(
  host : Host,
  cmd : String,
  args : Array[String],
  cwd : String,
  results : Array[Json],
  kind : String,
  name : String,
) -> Unit {
  errdefer results.push({ "kind": kind, "name": name, "status": "failed" })
  ignore(host.checked(cmd, args, cwd))
  results.push({ "kind": kind, "name": name, "status": "passed" })
}
