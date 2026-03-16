use "../../multipart_mime"

actor Main
  new create(env: Env) =>
    let boundary = "boundary123"
    let out = env.out

    // Restrict body size to 32 bytes and allow at most 2 parts.
    let config =
      MultipartConfig(where
        max_part_body_size' = 32,
        max_parts' = 2)

    let notify = _LimitPrinter(out)
    let parser =
      MultipartParser(
        notify, boundary where config' = config)

    // First part: fits within the 32-byte body limit
    let msg =
      "--boundary123\r\n"
        + "Content-Disposition:"
        + " form-data; name=\"small\"\r\n"
        + "\r\n"
        + "fits fine\r\n"
        + "--boundary123\r\n"
        + "Content-Disposition:"
        + " form-data; name=\"big\"\r\n"
        + "\r\n"
        + "this body is longer than thirty-two bytes"
        + " and will be rejected\r\n"
        + "--boundary123--"

    parser
      .> parse(msg.array())
      .> finish()

class ref _LimitPrinter is MultipartNotify
  let _out: OutStream tag

  new ref create(out: OutStream tag) =>
    _out = out

  fun ref part_begin(headers: PartHeaders val) =>
    match FormData.field_name(headers)
    | let name: String =>
      _out.print("Part: " + name)
    end

  fun ref body_chunk(data: Array[U8] val) =>
    _out.print(
      "  body: " + data.size().string() + " bytes")

  fun ref part_end() =>
    _out.print("  (end)")

  fun ref finished() =>
    _out.print("Parse complete.")

  fun ref parse_error(err: MultipartParseError) =>
    _out.print("Error: " + err.string())
