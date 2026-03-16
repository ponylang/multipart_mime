primitive FormData
  """
  Stateless helpers for extracting multipart/form-data metadata from
  part headers.

  These functions parse the `Content-Disposition` header per RFC 7578.
  No filename sanitization is performed — callers are responsible for
  ensuring filenames are safe for their target platform.
  """

  fun field_name(headers: PartHeaders val): (String val | None) =>
    """
    Extract the `name` parameter from the Content-Disposition header.
    """
    _param(headers, "name")

  fun file_name(headers: PartHeaders val): (String val | None) =>
    """
    Extract the `filename` parameter from the Content-Disposition header.
    Returns `None` when there is no filename parameter. The value is
    returned as-is — no path sanitization is applied.
    """
    _param(headers, "filename")

  fun content_disposition(headers: PartHeaders val): (String val | None) =>
    """
    Return the raw Content-Disposition header value, or `None`.
    """
    headers.get("content-disposition")

  fun content_type(headers: PartHeaders val): (String val | None) =>
    """
    Return the Content-Type header value for this part, or `None`.
    """
    headers.get("content-type")

  fun _param(
    headers: PartHeaders val,
    param_name: String val)
    : (String val | None)
  =>
    """
    Extract a named parameter from the Content-Disposition header.
    Handles both quoted and unquoted parameter values, including
    backslash escaping in quoted strings.
    """
    let cd =
      match \exhaustive\ headers.get("content-disposition")
      | let s: String val => s
      | None => return None
      end

    // Search for param_name=
    let search: String val = param_name + "="
    var i: USize = 0

    while i < cd.size() do
      // Find the next semicolon-delimited parameter
      let semi =
        try _find_char(cd, ';', i)?
        else cd.size()
        end

      // Trim whitespace from this segment
      var seg_start = i
      var seg_end = semi
      try
        while (seg_start < seg_end) and
              _is_ws(cd(seg_start)?)
        do
          seg_start = seg_start + 1
        end
        while (seg_end > seg_start) and
              _is_ws(cd(seg_end - 1)?)
        do
          seg_end = seg_end - 1
        end
      else
        _Unreachable()
      end

      // Check if this segment starts with "param_name="
      let seg_len = seg_end - seg_start
      if seg_len > search.size() then
        if _matches_ci(cd, seg_start, search) then
          let val_start = seg_start + search.size()
          return _extract_value(cd, val_start, seg_end)
        end
      elseif seg_len == search.size() then
        // param_name= with empty value
        if _matches_ci(cd, seg_start, search) then
          return ""
        end
      end

      i = if semi < cd.size() then semi + 1 else cd.size() end
    end
    None

  fun _extract_value(
    s: String val,
    from: USize,
    to: USize)
    : String val
  =>
    """
    Extract a parameter value, handling quoted strings with backslash
    escaping.
    """
    try
      if (from < to) and (s(from)? == '"') then
        // Quoted string — find closing quote, handle escapes
        let result = recover iso String end
        var i = from + 1
        while i < to do
          let c = s(i)?
          if c == '"' then
            break
          elseif (c == '\\') and ((i + 1) < to) then
            result.push(s(i + 1)?)
            i = i + 2
          else
            result.push(c)
            i = i + 1
          end
        end
        consume result
      else
        // Unquoted token
        _substring(s, from, to)
      end
    else
      _Unreachable()
      ""
    end

  fun _find_char(s: String val, c: U8, from: USize): USize ? =>
    """
    Find the first occurrence of `c` in `s` at or after `from`,
    respecting quoted strings (skips over quoted regions).
    """
    var i = from
    var in_quotes = false
    while i < s.size() do
      let ch = s(i)?
      if in_quotes then
        if ch == '"' then
          in_quotes = false
        elseif (ch == '\\')
          and ((i + 1) < s.size())
        then
          i = i + 1 // skip escaped char
        end
      else
        if ch == c then
          return i
        end
        if ch == '"' then
          in_quotes = true
        end
      end
      i = i + 1
    end
    error

  fun _matches_ci(s: String val, pos: USize, target: String val): Bool =>
    """
    Case-insensitive match of `target` at position `pos` in `s`.
    """
    if (pos + target.size()) > s.size() then return false end
    var i: USize = 0
    while i < target.size() do
      try
        let a = _lower(s(pos + i)?)
        let b = _lower(target(i)?)
        if a != b then return false end
      else
        _Unreachable()
        return false
      end
      i = i + 1
    end
    true

  fun _lower(c: U8): U8 =>
    if (c >= 'A') and (c <= 'Z') then c + 32 else c end

  fun _is_ws(c: U8): Bool =>
    (c == ' ') or (c == '\t')

  fun _substring(s: String val, from: USize, to: USize): String val =>
    let len = to - from
    let result = recover iso String(len) end
    var i = from
    while i < to do
      try result.push(s(i)?) else _Unreachable() end
      i = i + 1
    end
    consume result
