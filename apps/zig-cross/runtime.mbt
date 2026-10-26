///|
/// The view contains only current-version files. No global toolchain or cache is rewritten.
async fn runtime_view(env : Environment) -> String? {
  if env.runtime_mode != "sync" {
    return None
  }
  guard sync_eligible(env) else {
    fail(
      "sync runtime unavailable; run ZIG_CROSS_RUNTIME=sync zig-cross doctor --json",
    )
    return None
  }
  let source = env.toolchain_root.unwrap()
  let view = @fs.realpath(@fs.tmpdir(prefix="zig-cross-sync-"))
  errdefer @fs.rmdir(view, recursive=true)
  for name in ["bin", "include", "share"] {
    if @fs.exists(source + "/" + name) {
      @fs.symlink(target=source + "/" + name, view + "/" + name)
    }
  }
  @fs.mkdir(view + "/lib/runtime", recursive=true)
  for name in @fs.readdir(source + "/lib", include_hidden=true) {
    if name != "runtime" {
      @fs.symlink(target=source + "/lib/" + name, view + "/lib/" + name)
    }
  }
  for
    name in [
      "runtime.c", "env.c", "sync_io.c", "utf.c", "backtrace.c", "c_buffer.c",
    ] {
    @fs.write_file(
      view + "/lib/runtime/" + name,
      @fs.read_file(source + "/lib/runtime/" + name),
    )
  }
  Some(view)
}
