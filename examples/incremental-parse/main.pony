use "../../multipart_mime"

actor Main
  new create(env: Env) =>
    let boundary = "simpleboundary"
    let message =
      "--simpleboundary\r\n" +
      "Content-Type: text/plain\r\n" +
      "\r\n" +
      "Hello, world!\r\n" +
      "--simpleboundary\r\n" +
      "\r\n" +
      "Second part.\r\n" +
      "--simpleboundary--"

    let out = env.out
    let notify = _EventPrinter(out)
    let parser = MultipartParser(notify, boundary)

    // Feed the message in small chunks
    let chunk_size: USize = 10
    var offset: USize = 0
    while offset < message.size() do
      let end_pos =
        (offset + chunk_size).min(message.size())
      let chunk: String val =
        message.substring(
          offset.isize(), end_pos.isize())
      out.print(
        "[feed " + chunk.size().string()
          + " bytes]")
      parser.parse(chunk.array())
      offset = end_pos
    end

    parser.finish()

class ref _EventPrinter is MultipartNotify
  let _out: OutStream tag

  new ref create(out: OutStream tag) =>
    _out = out

  fun ref part_begin(headers: PartHeaders val) =>
    _out.print(
      ">> part_begin ("
        + headers.size().string()
        + " headers)")

  fun ref body_chunk(data: Array[U8] val) =>
    let s = String.from_array(data)
    _out.print(
      ">> body_chunk ("
        + data.size().string()
        + " bytes): " + s)

  fun ref part_end() =>
    _out.print(">> part_end")

  fun ref finished() =>
    _out.print(">> finished")

  fun ref parse_error(err: MultipartParseError) =>
    _out.print(">> error: " + err.string())
