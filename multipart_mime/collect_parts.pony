class val CollectedPart
  """
  A fully-buffered MIME part with its headers and complete body.
  """
  let headers: PartHeaders val
  let body: Array[U8] val

  new val _create(headers': PartHeaders val, body': Array[U8] val) =>
    headers = headers'
    body = body'

class ref CollectParts is MultipartNotify
  """
  A convenience `MultipartNotify` that accumulates complete parts in
  memory and delivers them as an array when parsing finishes.

  Suitable for small-to-moderate payloads where streaming is not
  required. For large uploads, implement `MultipartNotify` directly
  and handle `body_chunk` incrementally.
  """
  let _on_parts: {(Array[CollectedPart val] val)} val
  let _on_error: {(MultipartParseError)} val
  var _parts: Array[CollectedPart val] iso =
    recover iso Array[CollectedPart val] end
  var _current_headers: (PartHeaders val | None) = None
  var _current_body: Array[U8] iso = recover iso Array[U8] end

  new create(
    on_parts: {(Array[CollectedPart val] val)} val,
    on_error: {(MultipartParseError)} val)
  =>
    """
    Create a collector with callbacks for success and failure.

    `on_parts` receives all collected parts when the close delimiter
    is found. `on_error` receives the error when parsing fails.
    Only one of the two callbacks will fire.
    """
    _on_parts = on_parts
    _on_error = on_error

  fun ref part_begin(headers: PartHeaders val) =>
    _current_headers = headers
    _current_body = recover iso Array[U8] end

  fun ref body_chunk(data: Array[U8] val) =>
    _current_body.append(data)

  fun ref part_end() =>
    match _current_headers
    | let h: PartHeaders val =>
      let body = (_current_body = recover iso Array[U8] end)
      let part = CollectedPart._create(h, recover val consume body end)
      _parts.push(part)
    end
    _current_headers = None

  fun ref finished() =>
    let parts = (_parts = recover iso Array[CollectedPart val] end)
    _on_parts(recover val consume parts end)

  fun ref parse_error(err: MultipartParseError) =>
    _on_error(err)
