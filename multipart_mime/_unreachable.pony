use @pony_os_stderr[Pointer[None]]()
use @fprintf[I32](stream: Pointer[None], fmt: Pointer[U8] tag, ...)
use @exit[None](code: I32)

primitive _Unreachable
  """
  Crash with location info when code that should be unreachable executes.
  """
  fun apply(loc: SourceLoc = __loc): None =>
    @fprintf(
      @pony_os_stderr(),
      ("Unreachable code reached at %s:%zu\n"
        + "Please open an issue at "
        + "https://github.com/ponylang/"
        + "multipart_mime/issues\n").cstring(),
      loc.file().cstring(),
      loc.line())
    @exit(1)
