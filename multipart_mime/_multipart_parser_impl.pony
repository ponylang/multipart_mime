use "buffered"

class ref _MultipartParserImpl
  """
  Internal implementation of the multipart parser.

  Fields are public because the state classes in `_parser_state.pony`
  access them directly during parsing. The public `MultipartParser`
  wrapper delegates to this class, keeping the mutable state
  inaccessible to library users.
  """
  var state: _ParserState
  let notify: MultipartNotify ref
  let config: MultipartConfig
  embed reader: Reader = Reader
  var _failed: Bool = false
  var part_count: USize = 0
  var in_part: Bool = false
  let delimiter: Array[U8] val
  var part_body_delivered: USize = 0

  new create(
    notify': MultipartNotify ref,
    boundary: String val,
    config': MultipartConfig = MultipartConfig)
  =>
    notify = notify'
    config = config'

    if _valid_boundary(boundary) then
      // Build delimiter: "\r\n--" + boundary
      let d = recover iso Array[U8](boundary.size() + 4) end
      d.push('\r')
      d.push('\n')
      d.push('-')
      d.push('-')
      for byte in boundary.values() do
        d.push(byte)
      end
      delimiter = consume d
      state = _ExpectPreamble.create(delimiter)
    else
      delimiter = recover val Array[U8] end
      state = _Failed(InvalidBoundary)
    end

  fun ref parse(data: Array[U8] val) =>
    if _failed then
      return
    end

    reader.append(data)

    // Drive the state machine until it needs more data or fails.
    // Re-check _failed after each iteration because a notify
    // callback may call stop() re-entrantly.
    var running = true
    while running and (not _failed) do
      match \exhaustive\ state.parse(this)
      | _ParseContinue => None
      | _ParseNeedMore => running = false
      | let err: MultipartParseError =>
        if in_part then
          in_part = false
          notify.part_end()
        end
        if not _failed then
          _failed = true
          notify.parse_error(err)
        end
        state = _Failed(err)
        running = false
      end
    end

  fun ref finish() =>
    if _failed then return end

    if in_part then
      // Flush any remaining body data, respecting body size limit
      let flush_size = reader.size()
      if flush_size > 0 then
        if (part_body_delivered + flush_size) >
          config.max_part_body_size
        then
          in_part = false
          notify.part_end()
          if _failed then return end
          notify.parse_error(PartBodyTooLarge)
          _failed = true
          state = _Failed(PartBodyTooLarge)
          return
        end
        let chunk: Array[U8] val =
          try reader.block(flush_size)?
          else _Unreachable(); recover val Array[U8] end
          end
        part_body_delivered = part_body_delivered + flush_size
        notify.body_chunk(chunk)
        if _failed then return end
      end
      in_part = false
      notify.part_end()
      if _failed then return end
      notify.parse_error(UnexpectedEnd)
      _failed = true
      state = _Failed(UnexpectedEnd)
    else
      match state
      | let _: _Epilogue => None
      | let f: _Failed =>
        notify.parse_error(f.stored_error())
        _failed = true
      else
        notify.parse_error(UnexpectedEnd)
        _failed = true
        state = _Failed(UnexpectedEnd)
      end
    end

  fun ref stop() =>
    if _failed then return end
    _failed = true
    state = _Failed(UnexpectedEnd)

  fun _is_stopped(): Bool =>
    _failed

  fun tag _valid_boundary(boundary: String val): Bool =>
    """
    Validate a boundary string per RFC 2046 section 5.1.1.

    Must be 1-70 characters from the set:
    `A-Z a-z 0-9 '()+_,-./:=? ` (space only allowed non-trailing).
    """
    let size = boundary.size()
    if (size == 0) or (size > 70) then
      return false
    end

    var i: USize = 0
    while i < size do
      let c = try boundary(i)? else return false end
      let valid =
        ((c >= 'A') and (c <= 'Z')) or
        ((c >= 'a') and (c <= 'z')) or
        ((c >= '0') and (c <= '9')) or
        (c == '\'') or (c == '(') or (c == ')') or
        (c == '+') or (c == '_') or (c == ',') or
        (c == '-') or (c == '.') or (c == '/') or
        (c == ':') or (c == '=') or (c == '?') or
        (c == ' ')
      if not valid then
        return false
      end
      i = i + 1
    end

    // Trailing space not allowed
    try boundary(size - 1)? != ' ' else false end
