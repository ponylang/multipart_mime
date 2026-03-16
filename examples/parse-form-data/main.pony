use "../../multipart_mime"

actor Main
  new create(env: Env) =>
    let boundary =
      "----WebKitFormBoundary7MA4YWxkTrZu0gW"

    // Build a sample multipart/form-data message
    let msg =
      "------WebKitFormBoundary7MA4YWxkTrZu0gW\r\n"
        + "Content-Disposition:"
        + " form-data; name=\"username\"\r\n"
        + "\r\n"
        + "jane_doe\r\n"
        + "------WebKitFormBoundary7MA4YWxkTrZu0gW"
        + "\r\n"
        + "Content-Disposition:"
        + " form-data; name=\"avatar\""
        + "; filename=\"photo.png\"\r\n"
        + "Content-Type: image/png\r\n"
        + "\r\n"
        + "<binary image data>\r\n"
        + "------WebKitFormBoundary7MA4YWxkTrZu0gW"
        + "--"
    let out = env.out
    let notify = _FormDataPrinter(out)
    let parser =
      MultipartParser(notify, boundary)
    parser
      .> parse(msg.array())
      .> finish()

class ref _FormDataPrinter is MultipartNotify
  let _out: OutStream tag
  var _part_num: USize = 0

  new ref create(out: OutStream tag) =>
    _out = out

  fun ref part_begin(headers: PartHeaders val) =>
    _part_num = _part_num + 1
    _out.print(
      "--- Part " + _part_num.string() + " ---")
    match FormData.field_name(headers)
    | let name: String =>
      _out.print("  Field: " + name)
    end
    match FormData.file_name(headers)
    | let name: String =>
      _out.print("  File: " + name)
    end
    match FormData.content_type(headers)
    | let ct: String =>
      _out.print("  Content-Type: " + ct)
    end

  fun ref body_chunk(data: Array[U8] val) =>
    let s = String.from_array(data)
    _out.print(
      "  Body (" + data.size().string()
        + " bytes): " + s)

  fun ref finished() =>
    _out.print("Parse complete.")

  fun ref parse_error(err: MultipartParseError) =>
    _out.print("Error: " + err.string())
