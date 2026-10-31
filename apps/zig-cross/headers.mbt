///|
/// The MoonBit header fix. Since 0.10.17, moon compiles every runtime C file, and these files and
/// the moonbitlang/async C stubs do not compile with Zig's libc headers:
///
/// - `dir.c` uses `NAME_MAX` but does not include <limits.h>. glibc gets it through other headers;
///   Zig's musl headers do not. The wrapper adds `-DNAME_MAX=255` (the Linux value) on Linux. A
///   forced `-include limits.h` is wrong: it reads <features.h> before the first line of the source,
///   so a `#define _GNU_SOURCE` there (moonbitlang/async 0.22.7 `fs.c`) has no effect, and glibc
///   then does not declare `O_PATH`.
/// - `dir.c` and `fs.c` include <sys/vnode.h> for `enum vtype`. Zig's macOS headers do not have
///   that file, and on a Linux host there is no macOS SDK. The wrapper writes `vnode_shim` to
///   `<wrapper-dir>/include/sys/vnode.h` and adds `-idirafter <wrapper-dir>/include` on macOS.
///
/// Remove this fix when the MoonBit runtime and moonbitlang/async include <limits.h> and no longer
/// need <sys/vnode.h>, or when Zig ships the header. Check the files in `runtime_header_evidence`.
let runtime_header_evidence : Array[String] = [
  "https://github.com/moonbitlang/moonbit-native-runtime/blob/88e2a69ffff2f3faae07d2a94a9f7e54808cc2d1/dir.c#L27-L72",
  "https://github.com/moonbitlang/moonbit-native-runtime/blob/88e2a69ffff2f3faae07d2a94a9f7e54808cc2d1/fs.c#L61",
  "https://github.com/moonbitlang/async/blob/v0.22.5/src/fs/dir.c#L27-L72", "https://github.com/moonbitlang/async/blob/v0.22.5/src/internal/event_loop/fs.c#L57",
  "https://github.com/moonbitlang/async/blob/v0.22.7/src/internal/event_loop/fs.c#L17",
]

///|
/// The `case` patterns of the C sources that get the header fix: the runtime files of the MoonBit
/// toolchain and the moonbitlang/async C stubs. Other C sources compile without it.
let moonbit_source_patterns : String = "*/lib/runtime/*.c|*/moonbitlang/async/*.c"

///|
/// A minimal <sys/vnode.h> for macOS targets. The runtime uses only `enum vtype`. The values are
/// those of the macOS SDK and XNU (bsd/sys/vnode.h), the same on arm64 and x86_64:
/// https://github.com/apple-oss-distributions/xnu/blob/main/bsd/sys/vnode.h
let vnode_shim : String =
  #|/* sys/vnode.h shim from zig-cross. Zig's macOS headers do not have sys/vnode.h, and the
  #|   MoonBit runtime (dir.c, fs.c) and moonbitlang/async use only enum vtype from it.
  #|   The values are those of the macOS SDK. A real sys/vnode.h comes first on the include path. */
  #|#ifndef _SYS_VNODE_H_
  #|#define _SYS_VNODE_H_
  #|enum vtype {
  #|  VNON = 0,
  #|  VREG = 1,
  #|  VDIR = 2,
  #|  VBLK = 3,
  #|  VCHR = 4,
  #|  VLNK = 5,
  #|  VSOCK = 6,
  #|  VFIFO = 7,
  #|  VBAD = 8,
  #|  VSTR = 9,
  #|  VCPLX = 10
  #|};
  #|#endif
  #|

///|
/// The wrapper line that puts `flags` before the arguments when one argument is a MoonBit C source.
/// It is empty when there are no flags.
fn header_fix_line(flags : Array[String]) -> String {
  if flags.is_empty() {
    return ""
  }
  let quoted = flags.map(shell_quote).join(" ")
  "for a in \"$@\"; do case \"$a\" in \{moonbit_source_patterns}) set -- \{quoted} \"$@\"; break;; esac; done\n"
}
