use "../../multipart_mime"

actor Main
  new create(env: Env) =>
    let boundary = "boundary456"
    let out = env.out

    // A message with several fields. We only care about "token".
    let msg =
      "--boundary456\r\n"
        + "Content-Disposition:"
        + " form-data; name=\"username\"\r\n"
        + "\r\n"
        + "alice\r\n"
        + "--boundary456\r\n"
        + "Content-Disposition:"
        + " form-data; name=\"token\"\r\n"
        + "\r\n"
        + "abc-secret-xyz\r\n"
        + "--boundary456\r\n"
        + "Content-Disposition:"
        + " form-data; name=\"bio\"\r\n"
        + "\r\n"
        + "This part is never reached.\r\n"
        + "--boundary456--"

    let notify = _TokenFinder(out)
    let parser =
      MultipartParser(notify, boundary)

    // Store the parser in the notify so it can call stop().
    notify.set_parser(parser)

    parser
      .> parse(msg.array())
      .> finish()

class ref _TokenFinder is MultipartNotify
  let _out: OutStream tag
  var _parser: (MultipartParser ref | None) = None
  var _is_token: Bool = false
  embed _body: String ref = String

  new ref create(out: OutStream tag) =>
    _out = out

  fun ref set_parser(parser: MultipartParser ref) =>
    _parser = parser

  fun ref part_begin(headers: PartHeaders val) =>
    _is_token =
      match FormData.field_name(headers)
      | "token" => true
      else
        false
      end
    _body.clear()

  fun ref body_chunk(data: Array[U8] val) =>
    if _is_token then _body.append(data) end

  fun ref part_end() =>
    if _is_token then
      let value: String val = _body.clone()
      _out.print("Found token: " + value)
      // We have what we need. Stop parsing.
      // Note: stop() suppresses all further callbacks,
      // including part_end for any in-progress part.
      // Callers own cleanup after stop().
      match _parser
      | let p: MultipartParser ref => p.stop()
      end
    end

  fun ref finished() =>
    _out.print("Parse complete (token not found).")

  fun ref parse_error(err: MultipartParseError) =>
    _out.print("Error: " + err.string())
