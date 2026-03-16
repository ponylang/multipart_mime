trait ref MultipartNotify
  """
  Callback interface for multipart parse events.

  All methods have default (no-op) implementations so callers only
  override what they need. `finished()` and `parse_error()` are
  mutually exclusive terminal events — at most one will fire over
  the lifetime of a parse. When `stop()` is called, no further events
  fire, including `part_end()` for any in-progress part.

  Calling `stop()` from within any callback is supported. Calling
  `parse()` or `finish()` from within a callback is not supported
  and will corrupt parser state.
  """

  fun ref part_begin(headers: PartHeaders val) =>
    """
    A new part has started. `headers` contains the complete set of
    headers for this part. Called once per part, before any
    `body_chunk` calls for that part.
    """
    None

  fun ref body_chunk(data: Array[U8] val) =>
    """
    A chunk of body data for the current part. May be called zero or
    more times between `part_begin` and `part_end`. Each chunk is
    non-empty. The chunk boundaries are arbitrary and do not correspond
    to any structure in the message.
    """
    None

  fun ref part_end() =>
    """
    The current part has ended. Always paired with a preceding
    `part_begin` when parsing ends via `finish()`. When `stop()`
    is called, `part_end` is NOT delivered for any in-progress
    part — callers are responsible for their own cleanup.
    """
    None

  fun ref finished() =>
    """
    The close delimiter was found. Parsing completed successfully.
    No more callbacks will fire.
    """
    None

  fun ref parse_error(err: MultipartParseError) =>
    """
    A parse error occurred. No more callbacks will fire after this.
    """
    None
