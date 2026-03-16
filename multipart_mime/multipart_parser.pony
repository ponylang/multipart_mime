class ref MultipartParser
  """
  A streaming multipart MIME parser (RFC 2046).

  Feed data via `parse()` and receive events through a `MultipartNotify`.
  Call `finish()` when the input stream ends. The parser is synchronous —
  the caller drives it from within its own actor.
  """
  embed _impl: _MultipartParserImpl ref

  new create(
    notify': MultipartNotify ref,
    boundary: String val,
    config': MultipartConfig = MultipartConfig)
  =>
    """
    Create a parser for the given `boundary` string.

    If the boundary is invalid (empty, >70 characters, ends with a
    space, or contains characters outside the RFC 2046 allowed set),
    the parser enters a failed state and will deliver
    `InvalidBoundary` on the first `parse()` or `finish()` call.
    """
    _impl = _MultipartParserImpl(notify', boundary, config')

  fun ref parse(data: Array[U8] val) =>
    """
    Feed a chunk of data to the parser. Events are delivered to the
    notify synchronously during this call.
    """
    _impl.parse(data)

  fun ref finish() =>
    """
    Signal that the input stream has ended.

    If the close delimiter hasn't been seen, the parser delivers
    `UnexpectedEnd`. Every `part_begin` is guaranteed a matching
    `part_end` even on truncation.
    """
    _impl.finish()

  fun ref stop() =>
    """
    Stop parsing immediately. No further events will be delivered,
    including `part_end()` for any in-progress part.

    Callers are responsible for their own resource cleanup when
    using `stop()`. Use `finish()` instead if you need balanced
    `part_begin`/`part_end` callbacks on truncation.
    """
    _impl.stop()
