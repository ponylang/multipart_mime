use "buffered"

primitive _ParseContinue
primitive _ParseNeedMore
type _ParseResult is (_ParseContinue | _ParseNeedMore | MultipartParseError)

primitive _MaxTransportPadding
  """
  Maximum allowed transport padding (LWSP after a boundary, before
  the CRLF). RFC 2046 allows arbitrary padding but we cap it to
  prevent DoS via unbounded buffer growth.
  """
  fun apply(): USize => 256

interface ref _ParserState
  fun ref parse(p: _MultipartParserImpl ref): _ParseResult

primitive _BufferScan
  """
  Buffer scanning utilities for the parser state machine.
  """

  fun find_crlf(
    reader: Reader box,
    from: USize)
    : (USize | None)
  =>
    """
    Find the position of the next CRLF at or after `from`.
    Returns the index of the CR, or `None`.
    """
    var i = from
    let limit =
      if reader.size() >= 1 then reader.size() - 1
      else return None
      end
    while i < limit do
      try
        if (reader.peek_u8(i)? == '\r')
          and (reader.peek_u8(i + 1)? == '\n')
        then
          return i
        end
      else
        _Unreachable()
        return None
      end
      i = i + 1
    end
    None

  fun find_byte(
    reader: Reader box,
    byte: U8,
    from: USize,
    to: USize)
    : (USize | None)
  =>
    """
    Find the first occurrence of `byte` in `reader[from..to)`.
    """
    var i = from
    while i < to do
      try
        if reader.peek_u8(i)? == byte then return i end
      else
        _Unreachable()
        return None
      end
      i = i + 1
    end
    None

  fun is_lwsp(byte: U8): Bool =>
    """
    True if `byte` is linear white space (space or horizontal tab).
    """
    (byte == ' ') or (byte == '\t')

  fun extract_string(
    reader: Reader box,
    from: USize,
    to: USize)
    : String val
  =>
    """
    Extract bytes from `reader[from..to)` as a `String val`.
    """
    let len = to - from
    let s = recover iso String(len) end
    var i = from
    while i < to do
      try s.push(reader.peek_u8(i)?)
      else _Unreachable()
      end
      i = i + 1
    end
    consume s

class ref _ExpectPreamble is _ParserState
  """
  Initial state. Scans for `--boundary` at position 0 or after CRLF.
  Everything before it is preamble (discarded per RFC 2046).
  """
  let _delimiter: Array[U8] val
  var _pos0_rejected: Bool = false
  var _scan_offset: USize = 0

  new ref create(delimiter: Array[U8] val) =>
    _delimiter = delimiter

  fun ref parse(p: _MultipartParserImpl ref): _ParseResult =>
    // The delimiter stored on the parser is "\r\n--" + boundary.
    // In preamble we look for "--" + boundary which can appear at
    // position 0 or immediately after a CRLF.
    //
    // dash_boundary is the "--" + boundary portion (skip leading "\r\n").
    let dash_boundary_offset: USize = 2 // skip "\r\n" prefix of _delimiter
    let dash_boundary_len = _delimiter.size() - dash_boundary_offset

    // Try position 0 first (skip if previously rejected to avoid
    // infinite looping when position 0 matches the boundary but
    // the bytes after it are invalid)
    var search_from: USize = 0
    // When the boundary was found after a CRLF, track the CRLF
    // position so that "need more data" returns can set
    // _scan_offset back to the CRLF, allowing the scan to
    // re-find it on re-entry.
    var resume_pos: USize = 0
    var found = false

    if (not _pos0_rejected) and
      _matches_at(p.reader, 0, dash_boundary_offset)
    then
      search_from = 0
      resume_pos = 0
      found = true
    end

    if not found then
      // Scan for CRLF + dash_boundary
      var scan: USize = _scan_offset
      while true do
        match \exhaustive\ _BufferScan.find_crlf(p.reader, scan)
        | let crlf_pos: USize =>
          let after_crlf = crlf_pos + 2
          if (after_crlf + dash_boundary_len) > p.reader.size() then
            _scan_offset = crlf_pos
            if _scan_offset > p.config.max_preamble_size then
              return PreambleTooLarge
            end
            return _ParseNeedMore
          end
          if _matches_at(p.reader, after_crlf, dash_boundary_offset) then
            search_from = after_crlf
            resume_pos = crlf_pos
            found = true
            break
          end
          scan = crlf_pos + 1
        | None =>
          if p.reader.size() >= 1 then
            _scan_offset = p.reader.size() - 1
          end
          if _scan_offset > p.config.max_preamble_size then
            return PreambleTooLarge
          end
          return _ParseNeedMore
        end
      end
    end

    if not found then
      return _ParseNeedMore
    end

    let after_boundary = search_from + dash_boundary_len

    // Need at least 2 more bytes to check for "--" (close) or CRLF
    if (after_boundary + 2) > p.reader.size() then
      _scan_offset = resume_pos
      if _scan_offset > p.config.max_preamble_size then
        return PreambleTooLarge
      end
      return _ParseNeedMore
    end

    try
      // Check for close delimiter: "--boundary--"
      if (p.reader.peek_u8(after_boundary)? == '-')
        and (p.reader.peek_u8(after_boundary + 1)? == '-')
      then
        p.state = _Epilogue
        try p.reader.skip(after_boundary + 2)?
        else _Unreachable()
        end
        p.notify.finished()
        if p._is_stopped() then return _ParseNeedMore end
        return _ParseContinue
      end

      // Skip optional transport padding (LWSP) before CRLF,
      // capped to prevent DoS via unbounded padding
      var pad_pos = after_boundary
      while (pad_pos < p.reader.size()) and
        _BufferScan.is_lwsp(p.reader.peek_u8(pad_pos)?)
      do
        if (pad_pos - after_boundary) >=
          _MaxTransportPadding()
        then
          return MalformedBoundaryLine
        end
        pad_pos = pad_pos + 1
      end

      // Need CRLF after padding
      if (pad_pos + 2) > p.reader.size() then
        if (pad_pos - after_boundary) >=
          _MaxTransportPadding()
        then
          return MalformedBoundaryLine
        end
        _scan_offset = resume_pos
        if _scan_offset > p.config.max_preamble_size then
          return PreambleTooLarge
        end
        return _ParseNeedMore
      end

      if (p.reader.peek_u8(pad_pos)? == '\r')
        and (p.reader.peek_u8(pad_pos + 1)? == '\n')
      then
        try p.reader.skip(pad_pos + 2)?
        else _Unreachable()
        end
        p.state = _ExpectPartHeaders.create()
        return _ParseContinue
      end

      // Not a valid boundary line — keep scanning.
      // If we matched at position 0, record the rejection so we
      // don't re-check it on the next iteration (which would loop
      // forever since the buffer hasn't changed).
      if search_from == 0 then _pos0_rejected = true end
      _scan_offset = search_from + 1
      return _ParseContinue
    else
      _Unreachable()
      return _ParseNeedMore
    end

  fun _matches_at(
    reader: Reader box,
    buf_pos: USize,
    delim_offset: USize)
    : Bool
  =>
    """
    Check if the delimiter (starting at `delim_offset`) matches
    at `buf_pos` in the reader.
    """
    let delim_len = _delimiter.size() - delim_offset
    if (buf_pos + delim_len) > reader.size() then
      return false
    end
    var i: USize = 0
    while i < delim_len do
      try
        if reader.peek_u8(buf_pos + i)? !=
          _delimiter(delim_offset + i)?
        then
          return false
        end
      else
        _Unreachable()
        return false
      end
      i = i + 1
    end
    true

class ref _ExpectPartHeaders is _ParserState
  """
  Reads header lines until an empty line (CRLF CRLF). Accumulates
  headers, enforces `max_header_size`, rejects obs-fold. On the
  empty line: freezes headers, checks `max_parts`, delivers
  `part_begin`, transitions to `_ExpectPartBody`.
  """
  var _header_bytes: USize = 0
  var _scan_offset: USize = 0
  embed _headers: Array[(String val, String val)] =
    Array[(String val, String val)]

  new ref create() =>
    None

  fun ref parse(p: _MultipartParserImpl ref): _ParseResult =>
    match \exhaustive\ _BufferScan.find_crlf(p.reader, _scan_offset)
    | let crlf_pos: USize =>
      let line_len = crlf_pos - _scan_offset
      _header_bytes = _header_bytes + line_len + 2

      if _header_bytes > p.config.max_header_size then
        return HeadersTooLarge
      end

      if line_len == 0 then
        // Empty line — end of headers
        try p.reader.skip(crlf_pos + 2)?
        else _Unreachable()
        end

        p.part_count = p.part_count + 1
        if p.part_count > p.config.max_parts then
          return TooManyParts
        end

        let headers = _freeze_headers()
        p.notify.part_begin(headers)
        if p._is_stopped() then return _ParseNeedMore end
        p.in_part = true
        p.part_body_delivered = 0
        p.state = _ExpectPartBody.create(p.delimiter)
        return _ParseContinue
      end

      // Reject obs-fold (line starting with LWSP)
      try
        if _BufferScan.is_lwsp(
          p.reader.peek_u8(_scan_offset)?)
        then
          return MalformedHeader
        end
      else
        _Unreachable()
        return MalformedHeader
      end

      // Find the colon
      match \exhaustive\
        _BufferScan.find_byte(
          p.reader, ':', _scan_offset, crlf_pos)
      | let colon: USize =>
        // Reject whitespace before colon (RFC 7230 §3.2.4)
        if colon > _scan_offset then
          try
            if _BufferScan.is_lwsp(
              p.reader.peek_u8(colon - 1)?)
            then
              return MalformedHeader
            end
          else
            _Unreachable()
            return MalformedHeader
          end
        end

        let name =
          _extract_header_name(
            p.reader, _scan_offset, colon)

        // Skip optional whitespace after colon
        var val_start = colon + 1
        try
          while (val_start < crlf_pos) and
                _BufferScan.is_lwsp(
                  p.reader.peek_u8(val_start)?)
          do
            val_start = val_start + 1
          end
        else
          _Unreachable()
        end

        // Trim trailing whitespace
        var val_end = crlf_pos
        try
          while (val_end > val_start) and
                _BufferScan.is_lwsp(
                  p.reader.peek_u8(val_end - 1)?)
          do
            val_end = val_end - 1
          end
        else
          _Unreachable()
        end

        let value =
          _BufferScan.extract_string(
            p.reader, val_start, val_end)
        _headers.push((name, value))
        _scan_offset = crlf_pos + 2
        _ParseContinue
      | None =>
        MalformedHeader
      end
    | None =>
      let pending = p.reader.size() - _scan_offset
      if (_header_bytes + pending) >
        p.config.max_header_size
      then
        return HeadersTooLarge
      end
      _ParseNeedMore
    end

  fun _freeze_headers(): PartHeaders val =>
    """
    Copy accumulated headers into a `val` array and create a
    `PartHeaders`.
    """
    let count = _headers.size()
    let arr =
      recover iso
        Array[(String val, String val)](count)
      end
    for (k, v) in _headers.values() do
      arr.push((k, v))
    end
    PartHeaders(consume arr)

  fun _extract_header_name(
    reader: Reader box,
    from: USize,
    to: USize)
    : String val
  =>
    """
    Extract and lowercase a header name from the reader.
    """
    let len = to - from
    let s = recover iso String(len) end
    var i = from
    while i < to do
      try
        var c = reader.peek_u8(i)?
        if (c >= 'A') and (c <= 'Z') then c = c + 32 end
        s.push(c)
      else
        _Unreachable()
      end
      i = i + 1
    end
    consume s

class ref _ExpectPartBody is _ParserState
  """
  Scans for the boundary delimiter in body data. Uses a holdback
  strategy: bytes within `delimiter_len` of the scan position are
  held back to avoid delivering CRLF that belongs to the boundary.

  `_deliver_up_to` consumes bytes from the Reader, so all positions
  computed before delivery are invalid afterward. After delivery,
  the unconsumed data starts at offset 0 in the Reader.
  """
  let _delimiter: Array[U8] val

  new ref create(delimiter: Array[U8] val) =>
    _delimiter = delimiter

  fun ref parse(p: _MultipartParserImpl ref): _ParseResult =>
    let delim_len = _delimiter.size()

    // Scan for '\r' which starts our delimiter "\r\n--boundary"
    var scan_from: USize = 0
    while scan_from < p.reader.size() do
      match \exhaustive\
        _BufferScan.find_byte(
          p.reader, '\r', scan_from, p.reader.size())
      | let r_pos: USize =>
        // Check if we have enough data to test the full delimiter
        if (r_pos + delim_len) > p.reader.size() then
          match \exhaustive\ _deliver_up_to(p, r_pos)
          | _ParseContinue => None
          | let r: (_ParseNeedMore | MultipartParseError) =>
            return r
          end
          // After delivery, \r is at offset 0 in Reader
          return _ParseNeedMore
        end

        if _matches_delimiter(p.reader, r_pos) then
          // Found the boundary — deliver body up to it
          match \exhaustive\ _deliver_up_to(p, r_pos)
          | _ParseContinue => None
          | let r: (_ParseNeedMore | MultipartParseError) =>
            return r
          end
          // After delivery, delimiter starts at offset 0.
          // All positions are now relative to new Reader cursor.
          let after_boundary = delim_len

          // Need 2 more bytes to check for "--" or CRLF
          if (after_boundary + 2) > p.reader.size() then
            return _ParseNeedMore
          end

          try
            // Check for close delimiter
            if (p.reader.peek_u8(after_boundary)? == '-')
              and (p.reader.peek_u8(
                after_boundary + 1)? == '-')
            then
              p.in_part = false
              p.notify.part_end()
              if p._is_stopped() then
                return _ParseNeedMore
              end
              p.state = _Epilogue
              try p.reader.skip(after_boundary + 2)?
              else _Unreachable()
              end
              p.notify.finished()
              if p._is_stopped() then
                return _ParseNeedMore
              end
              return _ParseContinue
            end

            // Skip transport padding, capped to prevent DoS
            var pad_pos = after_boundary
            while (pad_pos < p.reader.size())
              and _BufferScan.is_lwsp(
                p.reader.peek_u8(pad_pos)?)
            do
              if (pad_pos - after_boundary) >=
                _MaxTransportPadding()
              then
                return MalformedBoundaryLine
              end
              pad_pos = pad_pos + 1
            end

            // Need CRLF
            if (pad_pos + 2) > p.reader.size() then
              if (pad_pos - after_boundary) >=
                _MaxTransportPadding()
              then
                return MalformedBoundaryLine
              end
              return _ParseNeedMore
            end

            if (p.reader.peek_u8(pad_pos)? == '\r')
              and (p.reader.peek_u8(pad_pos + 1)? == '\n')
            then
              p.in_part = false
              p.notify.part_end()
              if p._is_stopped() then
                return _ParseNeedMore
              end
              try p.reader.skip(pad_pos + 2)?
              else _Unreachable()
              end
              p.state = _ExpectPartHeaders.create()
              return _ParseContinue
            end
          else
            _Unreachable()
            return _ParseNeedMore
          end

          // False match — not a valid boundary line.
          // Delimiter is at offset 0; skip past the \r.
          scan_from = 1
        else
          scan_from = r_pos + 1
        end
      | None =>
        // No '\r' found — deliver everything except holdback
        let safe =
          if p.reader.size() > (delim_len - 1) then
            p.reader.size() - (delim_len - 1)
          else
            0
          end
        if safe > 0 then
          match \exhaustive\ _deliver_up_to(p, safe)
          | _ParseContinue => None
          | let r: (_ParseNeedMore | MultipartParseError) =>
            return r
          end
        end
        return _ParseNeedMore
      end
    end

    // Reached end of buffer
    let safe =
      if p.reader.size() > (delim_len - 1) then
        p.reader.size() - (delim_len - 1)
      else
        0
      end
    if safe > 0 then
      match \exhaustive\ _deliver_up_to(p, safe)
      | _ParseContinue => None
      | let r: (_ParseNeedMore | MultipartParseError) =>
        return r
      end
    end
    _ParseNeedMore

  fun ref _deliver_up_to(
    p: _MultipartParserImpl ref,
    to: USize)
    : _ParseResult
  =>
    """
    Deliver body bytes from offset 0 to `to` via `reader.block()`,
    which advances the Reader cursor. After this call, the Reader's
    cursor has moved forward by `to` bytes, so all prior position
    values are invalid. Returns `_ParseContinue` on success,
    `PartBodyTooLarge` if the body size limit is exceeded, or
    `_ParseNeedMore` if the parser was stopped re-entrantly.
    """
    if to > 0 then
      p.part_body_delivered = p.part_body_delivered + to
      if p.part_body_delivered > p.config.max_part_body_size then
        return PartBodyTooLarge
      end
      let chunk: Array[U8] val =
        try p.reader.block(to)?
        else _Unreachable(); recover val Array[U8] end
        end
      p.notify.body_chunk(chunk)
      if p._is_stopped() then return _ParseNeedMore end
    end
    _ParseContinue

  fun _matches_delimiter(
    reader: Reader box,
    pos: USize)
    : Bool
  =>
    var i: USize = 0
    while i < _delimiter.size() do
      try
        if reader.peek_u8(pos + i)? != _delimiter(i)? then
          return false
        end
      else
        _Unreachable()
        return false
      end
      i = i + 1
    end
    true

class ref _Epilogue is _ParserState
  """
  Terminal state after the close delimiter. All data is ignored.
  """
  fun ref parse(p: _MultipartParserImpl ref): _ParseResult =>
    p.reader.clear()
    _ParseNeedMore

class ref _Failed is _ParserState
  """
  Terminal error state. All data is ignored.
  """
  let _err: MultipartParseError

  new ref create(err: MultipartParseError) =>
    _err = err

  fun stored_error(): MultipartParseError =>
    _err

  fun ref parse(p: _MultipartParserImpl ref): _ParseResult =>
    _err
