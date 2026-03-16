class val PartHeaders
  """
  The headers of a single MIME part.

  Header names are stored lowercased for case-insensitive lookup.
  Lookup is a linear scan — MIME parts rarely have more than a few
  headers, so this is faster than a hash table.
  """
  let _headers: Array[(String val, String val)] val

  new val create(headers': Array[(String val, String val)] val) =>
    """
    Build a `PartHeaders` from an array of `(name, value)` pairs.

    Names must be lowercased by the caller — `get()` and `get_all()`
    compare against the lowercased lookup key. The parser lowercases
    names automatically; this constructor is useful for building
    fixtures in test code outside this package.
    """
    _headers = headers'

  fun get(name: String): (String | None) =>
    """
    Return the value of the first header matching `name`
    (case-insensitive), or `None` if not found.
    """
    let lower: String val = name.lower()
    for (k, v) in _headers.values() do
      if k == lower then return v end
    end

  fun get_all(name: String): Array[String val] val =>
    """
    Return all values for headers matching `name` (case-insensitive).
    """
    let lower: String val = name.lower()
    let result = recover iso Array[String val] end
    for (k, v) in _headers.values() do
      if k == lower then result.push(v) end
    end
    consume result

  fun values()
    : ArrayValues[
      (String val, String val),
      Array[(String val, String val)] val]^
  =>
    """
    Iterate over all `(name, value)` pairs. Names are lowercased.
    """
    _headers.values()

  fun size(): USize =>
    """
    The number of headers.
    """
    _headers.size()
