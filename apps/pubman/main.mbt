///|
async fn main {
  let r = request(@env.args()[1:].to_owned()) catch {
    err => {
      @stdio.stderr.write(err.to_string() + "\n")
      @sys.exit(2)
      abort("exit")
    }
  }
  let mut data : Json = Json::empty_object()
  let mut error : Json = Json::null()
  let mut code = 0
  try {
    data = execute(r, real_host(r.preview))
  } catch {
    Partial(name, message, status, partial) => {
      code = status
      data = partial
      error = {
        "code": name,
        "message": redact(message),
        "details": { "input": redact(r.input), "dryRun": r.preview },
      }
    }
    Failure(name, message, status) => {
      code = status
      error = {
        "code": name,
        "message": redact(message),
        "details": { "input": redact(r.input), "dryRun": r.preview },
      }
    }
    err => {
      code = 1
      error = {
        "code": "IO_ERROR",
        "message": redact(err.to_string()),
        "details": { "input": redact(r.input), "dryRun": r.preview },
      }
    }
  }
  let report : Json = {
    "schemaVersion": 1,
    "command": r.command,
    "ok": code == 0,
    "data": data,
    "error": error,
  }
  if r.json {
    @stdio.stdout.write(report.stringify() + "\n")
  } else {
    @stdio.stdout.write(
      r.command +
      ": " +
      (if code == 0 { "ok" } else { "failed" }) +
      "\n" +
      data.stringify(indent=2) +
      "\n",
    )
    if error != Json::null() {
      @stdio.stderr.write(error.stringify(indent=2) + "\n")
    }
  }
  if code != 0 {
    @sys.exit(code)
  }
}
